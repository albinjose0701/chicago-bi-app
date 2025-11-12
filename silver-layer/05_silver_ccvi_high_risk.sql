-- ============================================================================
-- Silver Layer: CCVI High Risk Areas
-- Filter for high vulnerability areas only (CCVI category = 'High')
-- ============================================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.silver_data.silver_ccvi_high_risk`
AS
SELECT
  -- Geography identification
  geography_type,
  community_area_or_zip as geography_id,

  -- CCVI metrics
  ROUND(ccvi_score, 3) as ccvi_score,
  ccvi_category,

  -- Audit timestamp
  CURRENT_TIMESTAMP() as created_at

FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_ccvi`
WHERE ccvi_category = 'HIGH';
