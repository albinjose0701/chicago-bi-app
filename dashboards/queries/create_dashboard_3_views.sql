-- ============================================================================
-- Dashboard 3: Vulnerable Communities (CCVI) - BigQuery Views
-- Created: November 22, 2025
-- Purpose: Support Dashboard 3 visualizations for CCVI high-risk tracking
-- ============================================================================

-- ============================================================================
-- VIEW 1: v_ccvi_map
-- Purpose: CCVI vulnerability map showing all high-risk areas
-- Visualization: Filled map with CCVI scores by geography
-- ============================================================================
CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.gold_data.v_ccvi_map` AS
WITH ccvi_with_names AS (
  SELECT
    ccvi.geography_type,
    ccvi.geography_id,
    ccvi.ccvi_score,
    ccvi.ccvi_category,
    CASE
      WHEN ccvi.geography_type = 'CA' THEN cab.community
      ELSE ccvi.geography_id
    END AS area_name,
    -- For mapping, get centroid coordinates
    CASE
      WHEN ccvi.geography_type = 'CA' THEN ST_Y(ST_CENTROID(cab.geometry))
      ELSE ST_Y(ST_CENTROID(zb.geometry))
    END AS latitude,
    CASE
      WHEN ccvi.geography_type = 'CA' THEN ST_X(ST_CENTROID(cab.geometry))
      ELSE ST_X(ST_CENTROID(zb.geometry))
    END AS longitude
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_ccvi_high_risk` ccvi
  LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.community_area_boundaries` cab
    ON ccvi.geography_type = 'CA' AND CAST(ccvi.geography_id AS INT64) = cab.area_numbe
  LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.zip_code_boundaries` zb
    ON ccvi.geography_type = 'ZIP' AND CAST(ccvi.geography_id AS INT64) = zb.zip
)
SELECT
  geography_type,
  geography_id,
  area_name,
  ccvi_score,
  ccvi_category,
  latitude,
  longitude,
  -- Score category for color coding
  CASE
    WHEN ccvi_score >= 60 THEN 'Very High'
    WHEN ccvi_score >= 55 THEN 'High'
    WHEN ccvi_score >= 50 THEN 'Moderate-High'
    ELSE 'High (Threshold)'
  END AS vulnerability_level,
  -- Numeric score for gradient coloring (similar to Dashboard 5)
  CASE
    WHEN ccvi_score >= 60 THEN 4
    WHEN ccvi_score >= 55 THEN 3
    WHEN ccvi_score >= 50 THEN 2
    ELSE 1
  END AS vulnerability_score
FROM ccvi_with_names
WHERE latitude IS NOT NULL;

-- ============================================================================
-- VIEW 2: v_ccvi_trip_activity
-- Purpose: Taxi trip volumes from/to CCVI high-risk areas
-- Visualization: Bar chart or table showing trip activity by area
-- ============================================================================
CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.gold_data.v_ccvi_trip_activity` AS
WITH high_risk_cas AS (
  SELECT CAST(geography_id AS INT64) as community_area, ccvi_score
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_ccvi_high_risk`
  WHERE geography_type = 'CA'
),
high_risk_zips AS (
  SELECT geography_id as zip_code, ccvi_score
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_ccvi_high_risk`
  WHERE geography_type = 'ZIP'
),
trips_from_high_risk AS (
  SELECT
    t.pickup_community_area as community_area,
    ca.ccvi_score,
    COUNT(*) as trips_from_area,
    SUM(CASE WHEN t.trips_pooled > 1 THEN 1 ELSE 0 END) as pooled_trips_from,
    AVG(t.fare) as avg_fare_from,
    AVG(t.trip_miles) as avg_miles_from
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_trips_enriched` t
  INNER JOIN high_risk_cas ca ON t.pickup_community_area = ca.community_area
  GROUP BY t.pickup_community_area, ca.ccvi_score
),
trips_to_high_risk AS (
  SELECT
    t.dropoff_community_area as community_area,
    ca.ccvi_score,
    COUNT(*) as trips_to_area,
    SUM(CASE WHEN t.trips_pooled > 1 THEN 1 ELSE 0 END) as pooled_trips_to,
    AVG(t.fare) as avg_fare_to,
    AVG(t.trip_miles) as avg_miles_to
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_trips_enriched` t
  INNER JOIN high_risk_cas ca ON t.dropoff_community_area = ca.community_area
  GROUP BY t.dropoff_community_area, ca.ccvi_score
),
combined AS (
  SELECT
    COALESCE(f.community_area, t.community_area) as community_area,
    COALESCE(f.ccvi_score, t.ccvi_score) as ccvi_score,
    COALESCE(f.trips_from_area, 0) as trips_from_area,
    COALESCE(t.trips_to_area, 0) as trips_to_area,
    COALESCE(f.pooled_trips_from, 0) as pooled_trips_from,
    COALESCE(t.pooled_trips_to, 0) as pooled_trips_to,
    f.avg_fare_from,
    t.avg_fare_to,
    f.avg_miles_from,
    t.avg_miles_to
  FROM trips_from_high_risk f
  FULL OUTER JOIN trips_to_high_risk t
    ON f.community_area = t.community_area
)
SELECT
  c.community_area,
  cab.community as area_name,
  c.ccvi_score,
  c.trips_from_area,
  c.trips_to_area,
  c.trips_from_area + c.trips_to_area as total_trips,
  c.pooled_trips_from,
  c.pooled_trips_to,
  c.pooled_trips_from + c.pooled_trips_to as total_pooled_trips,
  ROUND(c.avg_fare_from, 2) as avg_fare_from,
  ROUND(c.avg_fare_to, 2) as avg_fare_to,
  ROUND(c.avg_miles_from, 2) as avg_miles_from,
  ROUND(c.avg_miles_to, 2) as avg_miles_to,
  -- Pooled trip percentage
  SAFE_DIVIDE(c.pooled_trips_from + c.pooled_trips_to, c.trips_from_area + c.trips_to_area) * 100 as pooled_pct
FROM combined c
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.community_area_boundaries` cab
  ON c.community_area = cab.area_numbe
ORDER BY c.ccvi_score DESC;

-- ============================================================================
-- VIEW 3: v_ccvi_double_burden
-- Purpose: Areas with BOTH High CCVI AND High COVID risk
-- Visualization: Scatter plot or dual-axis chart
-- ============================================================================
CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.gold_data.v_ccvi_double_burden` AS
WITH high_risk_zips AS (
  SELECT geography_id as zip_code, ccvi_score
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_ccvi_high_risk`
  WHERE geography_type = 'ZIP'
),
covid_summary AS (
  SELECT
    zip_code,
    AVG(case_rate_weekly) as avg_case_rate,
    SUM(cases_weekly) as total_cases,
    SUM(deaths_weekly) as total_deaths,
    AVG(adjusted_risk_score) as avg_risk_score,
    MAX(CASE WHEN risk_category = 'High' THEN 1 ELSE 0 END) as had_high_risk_period,
    SUM(CASE WHEN risk_category = 'High' THEN 1 ELSE 0 END) as weeks_high_risk,
    SUM(total_trips_from_zip) as total_trips_from,
    SUM(total_trips_to_zip) as total_trips_to,
    population
  FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_hotspots`
  GROUP BY zip_code, population
)
SELECT
  hz.zip_code,
  hz.ccvi_score,
  cs.avg_case_rate,
  cs.total_cases,
  cs.total_deaths,
  cs.avg_risk_score,
  cs.weeks_high_risk,
  cs.total_trips_from,
  cs.total_trips_to,
  cs.population,
  -- Double burden score (combination of CCVI and COVID risk)
  (hz.ccvi_score / 100.0) * (cs.avg_risk_score / 100.0) * 100 as double_burden_score,
  -- Categorize burden level
  CASE
    WHEN hz.ccvi_score >= 55 AND cs.avg_risk_score >= 50 THEN 'Critical'
    WHEN hz.ccvi_score >= 50 AND cs.avg_risk_score >= 40 THEN 'Severe'
    WHEN hz.ccvi_score >= 47.9 AND cs.avg_risk_score >= 30 THEN 'High'
    ELSE 'Elevated'
  END AS burden_category
FROM high_risk_zips hz
LEFT JOIN covid_summary cs ON hz.zip_code = cs.zip_code
WHERE cs.zip_code IS NOT NULL
ORDER BY double_burden_score DESC;

-- ============================================================================
-- VIEW 4: v_ccvi_trip_trends
-- Purpose: Time series of trips to/from vulnerable areas
-- Visualization: Line chart showing trends over time
-- ============================================================================
CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.gold_data.v_ccvi_trip_trends` AS
WITH high_risk_cas AS (
  SELECT CAST(geography_id AS INT64) as community_area, ccvi_score
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_ccvi_high_risk`
  WHERE geography_type = 'CA'
)
SELECT
  DATE_TRUNC(t.trip_date, WEEK) as week_start,
  DATE_TRUNC(t.trip_date, MONTH) as month_start,
  EXTRACT(YEAR FROM t.trip_date) as year,
  EXTRACT(MONTH FROM t.trip_date) as month,

  -- Trips FROM high-risk areas
  COUNT(CASE WHEN ca_from.community_area IS NOT NULL THEN 1 END) as trips_from_high_ccvi,

  -- Trips TO high-risk areas
  COUNT(CASE WHEN ca_to.community_area IS NOT NULL THEN 1 END) as trips_to_high_ccvi,

  -- Total trips involving high-risk areas (either origin or destination)
  COUNT(CASE WHEN ca_from.community_area IS NOT NULL OR ca_to.community_area IS NOT NULL THEN 1 END) as trips_involving_high_ccvi,

  -- Pooled trips
  SUM(CASE WHEN (ca_from.community_area IS NOT NULL OR ca_to.community_area IS NOT NULL) AND t.trips_pooled > 1 THEN 1 ELSE 0 END) as pooled_trips_high_ccvi,

  -- All trips for comparison
  COUNT(*) as total_trips,

  -- Percentage of trips involving high-CCVI areas
  SAFE_DIVIDE(
    COUNT(CASE WHEN ca_from.community_area IS NOT NULL OR ca_to.community_area IS NOT NULL THEN 1 END),
    COUNT(*)
  ) * 100 as pct_trips_high_ccvi

FROM `chicago-bi-app-msds-432-476520.silver_data.silver_trips_enriched` t
LEFT JOIN high_risk_cas ca_from ON t.pickup_community_area = ca_from.community_area
LEFT JOIN high_risk_cas ca_to ON t.dropoff_community_area = ca_to.community_area
GROUP BY
  DATE_TRUNC(t.trip_date, WEEK),
  DATE_TRUNC(t.trip_date, MONTH),
  EXTRACT(YEAR FROM t.trip_date),
  EXTRACT(MONTH FROM t.trip_date)
ORDER BY week_start;

-- ============================================================================
-- VIEW 5: v_ccvi_pooled_rides
-- Purpose: Pooled/shared ride analysis in high-CCVI neighborhoods
-- Visualization: Bar chart comparing pooled vs solo rides
-- ============================================================================
CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.gold_data.v_ccvi_pooled_rides` AS
WITH high_risk_cas AS (
  SELECT CAST(geography_id AS INT64) as community_area, ccvi_score
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_ccvi_high_risk`
  WHERE geography_type = 'CA'
)
SELECT
  ca.community_area,
  cab.community as area_name,
  ca.ccvi_score,

  -- Trip counts
  COUNT(*) as total_trips,
  SUM(CASE WHEN t.trips_pooled > 1 THEN 1 ELSE 0 END) as pooled_trips,
  SUM(CASE WHEN t.trips_pooled = 1 OR t.trips_pooled IS NULL THEN 1 ELSE 0 END) as solo_trips,

  -- Pooled percentage
  SAFE_DIVIDE(SUM(CASE WHEN t.trips_pooled > 1 THEN 1 ELSE 0 END), COUNT(*)) * 100 as pooled_pct,

  -- By source (Taxi vs TNP)
  SUM(CASE WHEN t.source_dataset = 'taxi' THEN 1 ELSE 0 END) as taxi_trips,
  SUM(CASE WHEN t.source_dataset = 'tnp' THEN 1 ELSE 0 END) as tnp_trips,

  -- Shared authorization rate
  SUM(CASE WHEN t.shared_trip_authorized = TRUE THEN 1 ELSE 0 END) as shared_authorized,
  SAFE_DIVIDE(SUM(CASE WHEN t.shared_trip_authorized = TRUE THEN 1 ELSE 0 END), COUNT(*)) * 100 as shared_auth_pct,

  -- Fare metrics
  ROUND(AVG(t.fare), 2) as avg_fare,
  ROUND(AVG(CASE WHEN t.trips_pooled > 1 THEN t.fare END), 2) as avg_fare_pooled,
  ROUND(AVG(CASE WHEN t.trips_pooled = 1 OR t.trips_pooled IS NULL THEN t.fare END), 2) as avg_fare_solo,

  -- Distance metrics
  ROUND(AVG(t.trip_miles), 2) as avg_miles

FROM `chicago-bi-app-msds-432-476520.silver_data.silver_trips_enriched` t
INNER JOIN high_risk_cas ca
  ON t.pickup_community_area = ca.community_area
  OR t.dropoff_community_area = ca.community_area
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.community_area_boundaries` cab
  ON ca.community_area = cab.area_numbe
GROUP BY ca.community_area, cab.community, ca.ccvi_score
ORDER BY ca.ccvi_score DESC;

-- ============================================================================
-- VIEW 6: v_ccvi_dashboard_summary
-- Purpose: Executive summary for Dashboard 3 KPIs
-- Visualization: Scorecards and summary metrics
-- ============================================================================
CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.gold_data.v_ccvi_dashboard_summary` AS
WITH ccvi_stats AS (
  SELECT
    COUNT(*) as total_high_risk_areas,
    SUM(CASE WHEN geography_type = 'CA' THEN 1 ELSE 0 END) as high_risk_cas,
    SUM(CASE WHEN geography_type = 'ZIP' THEN 1 ELSE 0 END) as high_risk_zips,
    MIN(ccvi_score) as min_ccvi_score,
    MAX(ccvi_score) as max_ccvi_score,
    AVG(ccvi_score) as avg_ccvi_score
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_ccvi_high_risk`
),
trip_stats AS (
  SELECT
    COUNT(*) as total_trips_high_ccvi_areas
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_trips_enriched` t
  WHERE t.pickup_community_area IN (
    SELECT CAST(geography_id AS INT64)
    FROM `chicago-bi-app-msds-432-476520.silver_data.silver_ccvi_high_risk`
    WHERE geography_type = 'CA'
  )
  OR t.dropoff_community_area IN (
    SELECT CAST(geography_id AS INT64)
    FROM `chicago-bi-app-msds-432-476520.silver_data.silver_ccvi_high_risk`
    WHERE geography_type = 'CA'
  )
),
covid_stats AS (
  SELECT
    COUNT(DISTINCT zip_code) as zips_with_covid_data,
    SUM(cases_weekly) as total_covid_cases,
    SUM(deaths_weekly) as total_covid_deaths
  FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_hotspots`
  WHERE zip_code IN (
    SELECT geography_id
    FROM `chicago-bi-app-msds-432-476520.silver_data.silver_ccvi_high_risk`
    WHERE geography_type = 'ZIP'
  )
)
SELECT
  cs.total_high_risk_areas,
  cs.high_risk_cas,
  cs.high_risk_zips,
  cs.min_ccvi_score,
  cs.max_ccvi_score,
  ROUND(cs.avg_ccvi_score, 1) as avg_ccvi_score,
  ts.total_trips_high_ccvi_areas,
  cvs.zips_with_covid_data,
  cvs.total_covid_cases,
  cvs.total_covid_deaths
FROM ccvi_stats cs
CROSS JOIN trip_stats ts
CROSS JOIN covid_stats cvs;
