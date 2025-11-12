-- ============================================================================
-- Create Bronze Dataset
-- This dataset stores cleaned raw data with quality filters applied
-- ============================================================================

-- Create bronze_data dataset
CREATE SCHEMA IF NOT EXISTS `chicago-bi-app-msds-432-476520.bronze_data`
OPTIONS (
  location = 'us-central1',
  description = 'Bronze layer - Cleaned raw data with quality filters'
);

-- Verification
SELECT
  schema_name,
  location,
  creation_time as created_at
FROM `chicago-bi-app-msds-432-476520`.INFORMATION_SCHEMA.SCHEMATA
WHERE schema_name = 'bronze_data';
