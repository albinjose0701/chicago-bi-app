-- ============================================================================
-- Create Silver Data Dataset
-- Clean, analysis-ready data with business rules and spatial enrichment
-- ============================================================================

-- Create silver_data dataset
CREATE SCHEMA IF NOT EXISTS `chicago-bi-app-msds-432-476520.silver_data`
OPTIONS(
  description="Silver layer - Clean, enriched data with business rules and spatial joins",
  location="us-central1"
);

-- Verify creation
SELECT
  schema_name,
  location,
  TIMESTAMP_MILLIS(creation_time) as created_at
FROM `chicago-bi-app-msds-432-476520.INFORMATION_SCHEMA.SCHEMATA`
WHERE schema_name = 'silver_data';
