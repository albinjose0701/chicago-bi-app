-- ============================================================================
-- Bronze Layer: Public Health Statistics
-- Filters: Must have per_capita_income (not null, not blank)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.bronze_data.bronze_public_health`
AS
SELECT
  -- Community area identifiers
  `Community Area` as community_area,
  `Community Area Name` as community_area_name,

  -- Socioeconomic indicator
  `Per Capita Income` as per_capita_income,

  -- Metadata
  CURRENT_TIMESTAMP() as extracted_at

FROM `chicago-bi-app-msds-432-476520.raw_data.raw_public_health_stats`

WHERE 1=1
  -- Must have valid per capita income
  AND `Per Capita Income` IS NOT NULL
  AND `Community Area` IS NOT NULL;
