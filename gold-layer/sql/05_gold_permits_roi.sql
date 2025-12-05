-- =====================================================
-- Gold Layer: Building Permits ROI by ZIP Code
-- =====================================================
-- Purpose: Aggregate permit metrics by ZIP for ROI analysis
-- Source: silver_data.silver_permits_enriched
-- Granularity: zip_code
-- Created: 2025-11-13
-- =====================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.gold_data.gold_permits_roi`
AS
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

-- =====================================================
-- Verification Query
-- =====================================================
-- SELECT
--   COUNT(*) as total_zip_codes,
--   SUM(total_permits) as overall_permits,
--   ROUND(SUM(total_permit_value), 2) as overall_permit_value,
--   ROUND(AVG(avg_permit_value), 2) as avg_of_avg_permit_value,
--   MIN(total_permits) as min_permits_per_zip,
--   MAX(total_permits) as max_permits_per_zip
-- FROM `chicago-bi-app-msds-432-476520.gold_data.gold_permits_roi`;
