-- ============================================================================
-- Silver Layer: COVID-19 Cases - Clean & Enriched
-- Applies business rules, handles privacy suppression, adds quality flags
-- ============================================================================

CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.silver_data.covid_clean` AS
WITH covid_with_flags AS (
  SELECT
    *,
    -- Data quality flags
    CASE
      WHEN zip_code IS NULL THEN 'missing_zip_code'
      WHEN week_start IS NULL THEN 'missing_week_start'
      WHEN week_start > CURRENT_DATE() THEN 'future_week_start'
      WHEN week_start < '2020-01-01' THEN 'invalid_week_start'
      WHEN population IS NULL OR population = 0 THEN 'missing_population'
      WHEN cases_weekly < 0 THEN 'negative_cases'
      WHEN deaths_weekly < 0 THEN 'negative_deaths'
      WHEN tests_weekly < 0 THEN 'negative_tests'
      ELSE 'valid'
    END as data_quality_flag,

    -- Privacy suppression flags
    CASE
      WHEN cases_weekly IS NULL AND week_start >= '2020-03-01' THEN 'suppressed_low_count'
      ELSE 'not_suppressed'
    END as privacy_flag,

    -- Derived fields
    DATE(week_start) as week_start_date,
    DATE(week_end) as week_end_date,
    EXTRACT(YEAR FROM week_start) as year,
    EXTRACT(MONTH FROM week_start) as month,
    EXTRACT(WEEK FROM week_start) as week_number_in_year,

    -- Rates per 100K population
    CASE
      WHEN population > 0 THEN ROUND(cases_weekly / population * 100000, 2)
      ELSE NULL
    END as cases_per_100k,

    CASE
      WHEN population > 0 THEN ROUND(deaths_weekly / population * 100000, 2)
      ELSE NULL
    END as deaths_per_100k,

    CASE
      WHEN population > 0 THEN ROUND(tests_weekly / population * 100000, 2)
      ELSE NULL
    END as tests_per_100k,

    -- Case fatality rate (deaths / cases)
    CASE
      WHEN cases_weekly > 0 THEN ROUND(deaths_weekly / cases_weekly * 100, 2)
      ELSE NULL
    END as case_fatality_rate_pct,

    -- Test positivity rate
    CASE
      WHEN tests_weekly > 0 AND cases_weekly IS NOT NULL
      THEN ROUND(cases_weekly / tests_weekly * 100, 2)
      ELSE percent_tested_positive_weekly
    END as test_positivity_rate_calculated

  FROM `chicago-bi-app-msds-432-476520.raw_data.raw_covid19_cases_by_zip`
)
SELECT
  -- Core identifiers
  row_id,
  zip_code,
  community_area,

  -- Dates
  week_start,
  week_end,
  week_start_date,
  week_end_date,
  year,
  month,
  week_number,
  week_number_in_year,

  -- Weekly counts (NULL = suppressed due to privacy, <5 cases)
  cases_weekly,
  deaths_weekly,
  tests_weekly,

  -- Cumulative counts
  cases_cumulative,
  deaths_cumulative,
  tests_cumulative,

  -- Rates (raw)
  case_rate_weekly,
  case_rate_cumulative,
  death_rate_weekly,
  death_rate_cumulative,
  test_rate_weekly,
  test_rate_cumulative,

  -- Rates (per 100K population)
  cases_per_100k,
  deaths_per_100k,
  tests_per_100k,

  -- Test positivity
  percent_tested_positive_weekly,
  percent_tested_positive_cumulative,
  test_positivity_rate_calculated,

  -- Case fatality rate
  case_fatality_rate_pct,

  -- Population
  population,

  -- Flags
  data_quality_flag,
  privacy_flag

FROM covid_with_flags
WHERE 1=1
  -- Critical filters
  AND zip_code IS NOT NULL
  AND week_start IS NOT NULL
  AND week_start >= '2020-03-01'
  AND week_start <= CURRENT_DATE()

  -- Soft filters - allow nulls for privacy suppression
  AND (
    cases_weekly IS NULL  -- Privacy suppressed
    OR cases_weekly >= 0  -- Valid count
  )
  AND (
    deaths_weekly IS NULL
    OR deaths_weekly >= 0
  )
  AND (
    tests_weekly IS NULL
    OR tests_weekly >= 0
  );

-- Create materialized version (optional)
CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.silver_data.covid_clean_materialized`
PARTITION BY week_start_date
CLUSTER BY zip_code, community_area
AS
SELECT * FROM `chicago-bi-app-msds-432-476520.silver_data.covid_clean`;

-- Verification query
SELECT
  'Total Records' as metric,
  CAST(COUNT(*) AS STRING) as value
FROM `chicago-bi-app-msds-432-476520.silver_data.covid_clean`

UNION ALL

SELECT
  'Unique ZIP Codes',
  CAST(COUNT(DISTINCT zip_code) AS STRING)
FROM `chicago-bi-app-msds-432-476520.silver_data.covid_clean`

UNION ALL

SELECT
  'Unique Weeks',
  CAST(COUNT(DISTINCT week_start_date) AS STRING)
FROM `chicago-bi-app-msds-432-476520.silver_data.covid_clean`

UNION ALL

SELECT
  'Records with Privacy Suppression',
  CAST(COUNTIF(privacy_flag = 'suppressed_low_count') AS STRING)
FROM `chicago-bi-app-msds-432-476520.silver_data.covid_clean`

UNION ALL

SELECT
  'Total Cases (non-suppressed)',
  FORMAT('%,.0f', SUM(cases_weekly))
FROM `chicago-bi-app-msds-432-476520.silver_data.covid_clean`
WHERE cases_weekly IS NOT NULL;
