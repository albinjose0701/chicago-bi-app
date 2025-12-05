-- =====================================================
-- Gold Layer: COVID Hotspots with Mobility Risk Scoring
-- =====================================================
-- Purpose: Combine COVID data with mobility patterns and vulnerability
-- Source: silver_data.silver_covid_weekly_historical + silver_trips_enriched + silver_ccvi_high_risk
-- Granularity: zip_code, week_start (time series - 219 weeks × ~60 ZIPs)
-- Created: 2025-11-13
-- =====================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.gold_data.gold_covid_hotspots`
PARTITION BY week_start
CLUSTER BY zip_code, risk_category
AS
WITH
-- Step 1: Get trip counts by ZIP and week
trip_counts_by_week AS (
  SELECT
    DATE_TRUNC(trip_date, WEEK) as week_start,
    pickup_zip,
    dropoff_zip,
    COUNT(*) as trip_count,
    COUNTIF(trips_pooled > 0) as pooled_trip_count
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_trips_enriched`
  WHERE pickup_zip IS NOT NULL AND dropoff_zip IS NOT NULL
  GROUP BY week_start, pickup_zip, dropoff_zip
),

-- Step 2: Aggregate trips FROM and TO each ZIP by week
mobility_by_zip_week AS (
  SELECT
    week_start,
    pickup_zip as zip_code,
    SUM(trip_count) as total_trips_from_zip,
    0 as total_trips_to_zip,
    0 as total_pooled_trips_to_zip
  FROM trip_counts_by_week
  GROUP BY week_start, zip_code

  UNION ALL

  SELECT
    week_start,
    dropoff_zip as zip_code,
    0 as total_trips_from_zip,
    SUM(trip_count) as total_trips_to_zip,
    SUM(pooled_trip_count) as total_pooled_trips_to_zip
  FROM trip_counts_by_week
  GROUP BY week_start, zip_code
),

-- Step 3: Consolidate mobility metrics by ZIP and week
mobility_consolidated AS (
  SELECT
    week_start,
    zip_code,
    SUM(total_trips_from_zip) as total_trips_from_zip,
    SUM(total_trips_to_zip) as total_trips_to_zip,
    SUM(total_pooled_trips_to_zip) as total_pooled_trips_to_zip
  FROM mobility_by_zip_week
  GROUP BY week_start, zip_code
),

-- Step 4: Join COVID data with mobility data
covid_mobility AS (
  SELECT
    c.zip_code,
    c.week_start,
    c.week_end,
    c.week_number,
    c.case_rate_weekly,
    c.cases_weekly,
    c.deaths_weekly,
    c.tests_weekly,
    c.population,
    c.risk_category,
    COALESCE(m.total_trips_from_zip, 0) as total_trips_from_zip,
    COALESCE(m.total_trips_to_zip, 0) as total_trips_to_zip,
    COALESCE(m.total_pooled_trips_to_zip, 0) as total_pooled_trips_to_zip
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_covid_weekly_historical` c
  LEFT JOIN mobility_consolidated m
    ON c.zip_code = m.zip_code AND c.week_start = m.week_start
),

-- Step 5: Calculate min/max for normalization (global across all weeks)
normalization_bounds AS (
  SELECT
    -- Mobility bounds
    MIN(total_trips_from_zip) as min_trips_from,
    MAX(total_trips_from_zip) as max_trips_from,
    MIN(total_trips_to_zip) as min_trips_to,
    MAX(total_trips_to_zip) as max_trips_to,
    MIN(total_pooled_trips_to_zip) as min_pooled_to,
    MAX(total_pooled_trips_to_zip) as max_pooled_to,

    -- Epidemiological bounds (using case_rate_weekly which is already per 100K)
    MIN(case_rate_weekly) as min_case_rate,
    MAX(case_rate_weekly) as max_case_rate,
    MIN(tests_weekly) as min_tests,
    MAX(tests_weekly) as max_tests
  FROM covid_mobility
),

-- Step 6: Get CCVI scores (only ZIP-level CCVI, normalized 0-1)
ccvi_scores AS (
  SELECT
    geography_id as zip_code,
    ccvi_score,
    -- Normalize CCVI to 0-1 scale (from session context: range is 4.0-63.7)
    (ccvi_score - 4.0) / (63.7 - 4.0) as norm_ccvi_score
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_ccvi_high_risk`
  WHERE geography_type = 'ZIP'
),

-- Step 7: Calculate normalized metrics and risk scores
risk_calculations AS (
  SELECT
    cm.*,

    -- Normalized mobility metrics (0-1 scale)
    CASE
      WHEN nb.max_trips_from = nb.min_trips_from THEN 0
      ELSE (cm.total_trips_from_zip - nb.min_trips_from) / (nb.max_trips_from - nb.min_trips_from)
    END as norm_trips_from,

    CASE
      WHEN nb.max_trips_to = nb.min_trips_to THEN 0
      ELSE (cm.total_trips_to_zip - nb.min_trips_to) / (nb.max_trips_to - nb.min_trips_to)
    END as norm_trips_to,

    CASE
      WHEN nb.max_pooled_to = nb.min_pooled_to THEN 0
      ELSE (cm.total_pooled_trips_to_zip - nb.min_pooled_to) / (nb.max_pooled_to - nb.min_pooled_to)
    END as norm_pooled_to,

    -- Normalized epidemiological metrics (0-1 scale)
    CASE
      WHEN nb.max_case_rate = nb.min_case_rate THEN 0
      ELSE (cm.case_rate_weekly - nb.min_case_rate) / (nb.max_case_rate - nb.min_case_rate)
    END as norm_cases,

    CASE
      WHEN nb.max_tests = nb.min_tests THEN 0
      ELSE (cm.tests_weekly - nb.min_tests) / (nb.max_tests - nb.min_tests)
    END as norm_tests,

    -- CCVI adjustment factor
    COALESCE(ccvi.norm_ccvi_score, 0) as norm_ccvi,
    1 + (0.5 * COALESCE(ccvi.norm_ccvi_score, 0)) as ccvi_adjustment

  FROM covid_mobility cm
  CROSS JOIN normalization_bounds nb
  LEFT JOIN ccvi_scores ccvi ON cm.zip_code = ccvi.zip_code
)

-- Step 8: Final output with all risk scores
SELECT
  -- Primary dimensions
  zip_code,
  week_start,

  -- COVID metrics (from silver layer)
  case_rate_weekly,
  cases_weekly,
  deaths_weekly,
  tests_weekly,
  risk_category,

  -- Mobility metrics
  total_trips_from_zip,
  total_trips_to_zip,
  total_pooled_trips_to_zip,
  population,

  -- Calculated risk scores
  ROUND(
    (0.7 * norm_trips_from) +
    (1.0 * norm_trips_to) +
    (1.5 * norm_pooled_to),
    2
  ) as mobility_risk_rate,

  ROUND(
    (0.7 * norm_cases) +
    (0.3 * norm_tests),
    2
  ) as epi_risk,

  ROUND(ccvi_adjustment, 3) as ccvi_adjustment,

  ROUND(
    ((0.7 * norm_trips_from) + (1.0 * norm_trips_to) + (1.5 * norm_pooled_to) +
     (0.7 * norm_cases) + (0.3 * norm_tests)) * ccvi_adjustment,
    2
  ) as adjusted_risk_score,

  -- Audit timestamp
  CURRENT_TIMESTAMP() as created_at

FROM risk_calculations;

-- =====================================================
-- Verification Query
-- =====================================================
-- SELECT
--   COUNT(*) as total_records,
--   COUNT(DISTINCT zip_code) as unique_zips,
--   COUNT(DISTINCT week_start) as unique_weeks,
--   MIN(week_start) as earliest_week,
--   MAX(week_start) as latest_week,
--   ROUND(AVG(mobility_risk_rate), 2) as avg_mobility_risk,
--   ROUND(AVG(epi_risk), 2) as avg_epi_risk,
--   ROUND(AVG(adjusted_risk_score), 2) as avg_adjusted_risk,
--   COUNTIF(risk_category = 'High') as high_risk_weeks,
--   COUNTIF(risk_category = 'Medium') as medium_risk_weeks,
--   COUNTIF(risk_category = 'Low') as low_risk_weeks
-- FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_hotspots`;
