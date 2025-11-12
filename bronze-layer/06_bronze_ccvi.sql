-- ============================================================================
-- Bronze Layer: CCVI (COVID-19 Community Vulnerability Index)
-- No quality filters specified for CCVI data
-- ============================================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.bronze_data.bronze_ccvi`
AS
SELECT
  -- Geography identifiers
  `Geography Type` as geography_type,
  CAST(`Community Area or ZIP Code` AS STRING) as community_area_or_zip,

  -- CCVI metrics
  ROUND(`CCVI Score`, 3) as ccvi_score,
  `CCVI Category` as ccvi_category,

  -- Location (WKT string format, e.g., "POINT (-87.64 41.89)")
  -- Note: This is stored as STRING in raw table, not GEOGRAPHY type
  `Location` as location,

  -- Metadata
  CURRENT_TIMESTAMP() as extracted_at

FROM `chicago-bi-app-msds-432-476520.raw_data.raw_ccvi`

WHERE 1=1
  -- Basic data quality filters
  AND `Geography Type` IS NOT NULL
  AND `Community Area or ZIP Code` IS NOT NULL
  AND `CCVI Score` IS NOT NULL;
