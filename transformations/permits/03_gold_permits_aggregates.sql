-- ============================================================================
-- GOLD LAYER: Building Permits Aggregates - FULL REFRESH
-- ============================================================================
-- Purpose: Rebuild gold layer aggregates from silver data
-- Strategy: DELETE + INSERT (small tables, full refresh is fast)
-- Tables: gold_permits_roi, gold_loan_targets
-- Note: Gold aggregates are lightweight, full refresh preferred over incremental
-- ============================================================================

-- ============================================================================
-- TABLE 1: gold_permits_roi
-- Purpose: Aggregate permit metrics by ZIP for ROI analysis
-- ============================================================================

-- Delete existing data
DELETE FROM `chicago-bi-app-msds-432-476520.gold_data.gold_permits_roi` WHERE TRUE;

-- Insert fresh aggregates
INSERT INTO `chicago-bi-app-msds-432-476520.gold_data.gold_permits_roi` (
  zip_code,
  total_permits,
  total_permit_value,
  avg_permit_value,
  created_at
)
SELECT
  -- Primary key
  zip_code,

  -- Aggregated metrics
  COUNT(*) as total_permits,
  ROUND(SUM(reported_cost), 2) as total_permit_value,
  ROUND(AVG(reported_cost), 2) as avg_permit_value,

  -- Audit timestamp
  CURRENT_TIMESTAMP() as created_at

FROM `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched`

WHERE
  zip_code IS NOT NULL
  AND reported_cost IS NOT NULL
  AND reported_cost > 0  -- Exclude zero or negative values

GROUP BY zip_code;

-- ============================================================================
-- TABLE 2: gold_loan_targets
-- Purpose: Calculate loan eligibility for Small Business Emergency Loan Fund
-- Criteria: Low income + low NEW CONSTRUCTION permit activity
-- ============================================================================

-- Delete existing data
DELETE FROM `chicago-bi-app-msds-432-476520.gold_data.gold_loan_targets` WHERE TRUE;

-- Insert fresh calculations
INSERT INTO `chicago-bi-app-msds-432-476520.gold_data.gold_loan_targets` (
  zip_code,
  population,
  per_capita_income,
  inverted_income_index,
  total_permits_new_construction,
  inverted_new_construction_index,
  total_permits_construction,
  inverted_permits_index,
  median_permit_value,
  permit_value_index,
  eligibility_index,
  is_loan_eligible,
  created_at
)
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

-- Step 6: Combine all data and calculate indices
combined_data AS (
  SELECT
    COALESCE(zp.zip_code, zi.zip_code, pa.zip_code) as zip_code,
    COALESCE(zp.population, 0) as population,
    COALESCE(zi.per_capita_income, 0) as per_capita_income,
    COALESCE(pa.total_permits_new_construction, 0) as total_permits_new_construction,
    COALESCE(pa.total_permits_construction, 0) as total_permits_construction,
    COALESCE(pa.median_permit_value, 0) as median_permit_value,

    -- Inverted income index (low income = high index, 0-1 scale)
    ROUND(
      1 - (
        (COALESCE(zi.per_capita_income, 0) - nb.min_income) /
        NULLIF(nb.max_income - nb.min_income, 0)
      ),
      2
    ) as inverted_income_index,

    -- Inverted new construction index (low construction = high index)
    ROUND(
      1 - (
        (COALESCE(pa.total_permits_new_construction, 0) - nb.min_new_construction) /
        NULLIF(nb.max_new_construction - nb.min_new_construction, 0)
      ),
      2
    ) as inverted_new_construction_index,

    -- Inverted total permits index
    ROUND(
      1 - (
        (COALESCE(pa.total_permits_construction, 0) - nb.min_permits) /
        NULLIF(nb.max_permits - nb.min_permits, 0)
      ),
      2
    ) as inverted_permits_index,

    -- Permit value index (higher value = higher index, for loan sizing)
    ROUND(
      (COALESCE(pa.median_permit_value, 0) - nb.min_permit_value) /
      NULLIF(nb.max_permit_value - nb.min_permit_value, 0),
      2
    ) as permit_value_index

  FROM zip_population zp
  FULL OUTER JOIN zip_income zi ON zp.zip_code = zi.zip_code
  FULL OUTER JOIN permit_aggregates pa ON COALESCE(zp.zip_code, zi.zip_code) = pa.zip_code
  CROSS JOIN normalization_bounds nb

  WHERE COALESCE(zp.zip_code, zi.zip_code, pa.zip_code) IS NOT NULL
)

-- Step 7: Final eligibility calculation
SELECT
  zip_code,
  population,
  per_capita_income,
  inverted_income_index,
  total_permits_new_construction,
  inverted_new_construction_index,
  total_permits_construction,
  inverted_permits_index,
  median_permit_value,
  permit_value_index,

  -- Overall eligibility index (weighted average of key indices)
  ROUND(
    (inverted_income_index * 0.4 +
     inverted_new_construction_index * 0.4 +
     inverted_permits_index * 0.2),
    2
  ) as eligibility_index,

  -- Binary eligibility flag (high need areas)
  (inverted_income_index >= 0.3 AND inverted_new_construction_index >= 0.3) as is_loan_eligible,

  -- Audit timestamp
  CURRENT_TIMESTAMP() as created_at

FROM combined_data
WHERE zip_code != 'Unknown';

-- ============================================================================
-- Verification Queries (for logging)
-- ============================================================================

-- Permits ROI summary
SELECT
  'gold_permits_roi' as table_name,
  COUNT(*) as total_zip_codes,
  SUM(total_permits) as overall_permits,
  ROUND(SUM(total_permit_value), 2) as overall_permit_value,
  ROUND(AVG(avg_permit_value), 2) as avg_of_avg_permit_value
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_permits_roi`;

-- Loan targets summary
SELECT
  'gold_loan_targets' as table_name,
  COUNT(*) as total_zip_codes,
  SUM(CAST(is_loan_eligible AS INT64)) as eligible_zips,
  ROUND(AVG(eligibility_index), 2) as avg_eligibility_index,
  ROUND(AVG(per_capita_income), 0) as avg_income
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_loan_targets`;
