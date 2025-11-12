-- =====================================================
-- Gold Layer: Small Business Loan Eligibility Targets
-- =====================================================
-- Purpose: Calculate loan eligibility for Illinois Small Business Emergency Loan Fund Delta
-- Criteria: PER_CAPITA_INCOME < $30,000 AND lowest NEW CONSTRUCTION permit counts
-- Source: Multiple (permits, public health, COVID, CCVI via spatial crosswalks)
-- Granularity: zip_code
-- Created: 2025-11-13
-- =====================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.gold_data.gold_loan_targets`
AS
WITH
-- Step 1: Get ZIP-level population from COVID data (most recent week)
zip_population AS (
  SELECT DISTINCT
    zip_code,
    FIRST_VALUE(population) OVER (PARTITION BY zip_code ORDER BY week_start DESC) as population
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_covid_weekly_historical`
),

-- Step 2: Calculate weighted per_capita_income by ZIP using spatial crosswalk
zip_income AS (
  SELECT
    cw.zip_code,
    -- Weighted average: SUM(income * pct_of_zip) / SUM(pct_of_zip)
    ROUND(
      SUM(ph.per_capita_income * cw.pct_of_zip) / NULLIF(SUM(cw.pct_of_zip), 0),
      0
    ) as per_capita_income
  FROM `chicago-bi-app-msds-432-476520.reference_data.crosswalk_community_zip` cw
  INNER JOIN `chicago-bi-app-msds-432-476520.bronze_data.bronze_public_health` ph
    ON cw.community_area_number = ph.community_area
  WHERE ph.per_capita_income IS NOT NULL
  GROUP BY cw.zip_code
),

-- Step 3: Count permits by ZIP (total and new construction)
permit_counts AS (
  SELECT
    zip_code,
    COUNT(*) as total_permits_construction,
    COUNTIF(
      UPPER(permit_type) LIKE '%NEW CONSTRUCTION%' OR
      UPPER(work_type) LIKE '%NEW CONSTRUCTION%'
    ) as total_permits_new_construction,
    -- Median permit value
    PERCENTILE_CONT(reported_cost, 0.5) OVER (PARTITION BY zip_code) as median_permit_value_window
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched`
  WHERE zip_code IS NOT NULL
    AND reported_cost IS NOT NULL
    AND reported_cost > 0
  GROUP BY zip_code, reported_cost
),

-- Step 4: Get one row per ZIP with median permit value
permit_aggregates AS (
  SELECT DISTINCT
    zip_code,
    MAX(total_permits_construction) OVER (PARTITION BY zip_code) as total_permits_construction,
    MAX(total_permits_new_construction) OVER (PARTITION BY zip_code) as total_permits_new_construction,
    FIRST_VALUE(median_permit_value_window) OVER (PARTITION BY zip_code ORDER BY median_permit_value_window) as median_permit_value
  FROM permit_counts
),

-- Step 5: Calculate normalization bounds
normalization_bounds AS (
  SELECT
    -- Income bounds
    MIN(zi.per_capita_income) as min_income,
    MAX(zi.per_capita_income) as max_income,

    -- New construction permits bounds
    MIN(pa.total_permits_new_construction) as min_new_construction,
    MAX(pa.total_permits_new_construction) as max_new_construction,

    -- Total permits bounds
    MIN(pa.total_permits_construction) as min_permits,
    MAX(pa.total_permits_construction) as max_permits,

    -- Permit value bounds
    MIN(pa.median_permit_value) as min_permit_value,
    MAX(pa.median_permit_value) as max_permit_value

  FROM zip_income zi
  CROSS JOIN permit_aggregates pa
),

-- Step 6: Combine all metrics and calculate indices
combined_metrics AS (
  SELECT
    COALESCE(zi.zip_code, pa.zip_code, zp.zip_code) as zip_code,
    COALESCE(zp.population, 0) as population,
    COALESCE(zi.per_capita_income, 0) as per_capita_income,
    COALESCE(pa.total_permits_new_construction, 0) as total_permits_new_construction,
    COALESCE(pa.total_permits_construction, 0) as total_permits_construction,
    COALESCE(pa.median_permit_value, 0) as median_permit_value,

    -- Inverted income index (0.5 weight)
    -- Higher score = Lower income (inverted)
    0.5 * CASE
      WHEN nb.max_income = nb.min_income THEN 0
      ELSE (nb.max_income - COALESCE(zi.per_capita_income, nb.max_income)) /
           (nb.max_income - nb.min_income)
    END as inverted_income_index,

    -- Inverted new construction index (0.4 weight)
    -- Higher score = Fewer new construction permits (inverted)
    0.4 * CASE
      WHEN nb.max_new_construction = nb.min_new_construction THEN 0
      ELSE (nb.max_new_construction - COALESCE(pa.total_permits_new_construction, nb.max_new_construction)) /
           (nb.max_new_construction - nb.min_new_construction)
    END as inverted_new_construction_index,

    -- Inverted permits index (0.1 weight)
    -- Higher score = Fewer total permits (inverted)
    0.1 * CASE
      WHEN nb.max_permits = nb.min_permits THEN 0
      ELSE (nb.max_permits - COALESCE(pa.total_permits_construction, nb.max_permits)) /
           (nb.max_permits - nb.min_permits)
    END as inverted_permits_index,

    -- Permit value index (0.03 weight)
    -- Higher score = Higher median permit value (NOT inverted, will be subtracted)
    0.03 * CASE
      WHEN nb.max_permit_value = nb.min_permit_value THEN 0
      ELSE (COALESCE(pa.median_permit_value, nb.min_permit_value) - nb.min_permit_value) /
           (nb.max_permit_value - nb.min_permit_value)
    END as permit_value_index

  FROM zip_income zi
  FULL OUTER JOIN permit_aggregates pa ON zi.zip_code = pa.zip_code
  FULL OUTER JOIN zip_population zp ON COALESCE(zi.zip_code, pa.zip_code) = zp.zip_code
  CROSS JOIN normalization_bounds nb
)

-- Step 7: Final output with eligibility calculation
SELECT
  zip_code,
  population,
  per_capita_income,

  -- Index components
  ROUND(inverted_income_index, 2) as inverted_income_index,
  total_permits_new_construction,
  ROUND(inverted_new_construction_index, 2) as inverted_new_construction_index,
  total_permits_construction,
  ROUND(inverted_permits_index, 2) as inverted_permits_index,
  ROUND(median_permit_value, 2) as median_permit_value,
  ROUND(permit_value_index, 2) as permit_value_index,

  -- Composite eligibility index
  ROUND(
    inverted_income_index +
    inverted_new_construction_index +
    inverted_permits_index -
    permit_value_index,
    2
  ) as eligibility_index,

  -- Eligibility flag (per requirement: per_capita_income < $30,000)
  CASE
    WHEN per_capita_income < 30000 THEN TRUE
    ELSE FALSE
  END as is_loan_eligible,

  -- Audit timestamp
  CURRENT_TIMESTAMP() as created_at

FROM combined_metrics;

-- =====================================================
-- Verification Query
-- =====================================================
-- SELECT
--   COUNT(*) as total_zip_codes,
--   COUNTIF(is_loan_eligible) as eligible_zip_codes,
--   ROUND(AVG(per_capita_income), 0) as avg_per_capita_income,
--   ROUND(AVG(eligibility_index), 2) as avg_eligibility_index,
--   MIN(per_capita_income) as min_income,
--   MAX(per_capita_income) as max_income,
--   ROUND(AVG(total_permits_new_construction), 0) as avg_new_construction_permits
-- FROM `chicago-bi-app-msds-432-476520.gold_data.gold_loan_targets`
-- WHERE is_loan_eligible = TRUE;
