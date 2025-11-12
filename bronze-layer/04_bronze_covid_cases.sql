-- ============================================================================
-- Bronze Layer: COVID-19 Cases by ZIP Code
-- No quality filters specified for COVID data
-- ============================================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.bronze_data.bronze_covid_cases`
PARTITION BY week_start
CLUSTER BY zip_code
AS
SELECT
  -- ZIP code identifier
  zip_code,

  -- Week identifiers
  week_number,
  DATE(week_start) as week_start,
  DATE(week_end) as week_end,

  -- Weekly metrics
  cases_weekly,
  tests_weekly,
  deaths_weekly,

  -- Population
  population,

  -- Rates
  ROUND(case_rate_weekly, 2) as case_rate_weekly,

  -- Row identifier
  row_id,

  -- Note: zip_code_location (GEOGRAPHY/POINT) field does not exist in raw table
  -- Can be added later by joining with ZIP boundary reference data

  -- Metadata
  CURRENT_TIMESTAMP() as extracted_at

FROM `chicago-bi-app-msds-432-476520.raw_data.raw_covid19_cases_by_zip`

WHERE 1=1
  -- Partition filter (required for partitioned tables)
  AND DATE(week_start) >= '2020-01-01'
  AND DATE(week_start) <= CURRENT_DATE()

  -- Basic data quality filters
  AND zip_code IS NOT NULL
  AND week_start IS NOT NULL
  AND week_end IS NOT NULL
  AND row_id IS NOT NULL;
