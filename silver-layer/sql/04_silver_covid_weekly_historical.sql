-- ============================================================================
-- Silver Layer: COVID-19 Weekly Historical Data
-- All weeks from 2020-2024 with risk categorization for pandemic analysis
-- ============================================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.silver_data.silver_covid_weekly_historical`
PARTITION BY week_start
CLUSTER BY zip_code, risk_category
AS
SELECT
  -- Primary key
  zip_code,

  -- Time fields
  week_start,
  week_end,
  week_number,

  -- Metrics
  cases_weekly,
  ROUND(case_rate_weekly, 2) as case_rate_weekly,
  tests_weekly,
  deaths_weekly,
  population,

  -- Risk categorization based on CDC guidelines
  -- High: ≥400 cases per 100K (community high transmission)
  -- Medium: ≥200 cases per 100K (substantial transmission)
  -- Low: <200 cases per 100K (moderate/low transmission)
  CASE
    WHEN case_rate_weekly >= 400 THEN 'High'
    WHEN case_rate_weekly >= 200 THEN 'Medium'
    ELSE 'Low'
  END as risk_category,

  -- Derived metrics
  EXTRACT(YEAR FROM week_start) as year,
  EXTRACT(MONTH FROM week_start) as month,

  -- Testing positivity rate (if available)
  CASE
    WHEN tests_weekly > 0 THEN ROUND((cases_weekly / tests_weekly) * 100, 2)
    ELSE NULL
  END as test_positivity_pct,

  -- Case fatality rate for the week
  CASE
    WHEN cases_weekly > 0 THEN ROUND((deaths_weekly / cases_weekly) * 100, 2)
    ELSE NULL
  END as case_fatality_pct,

  -- Audit timestamp
  CURRENT_TIMESTAMP() as created_at

FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_covid_cases`
WHERE week_start >= '2020-01-01'
  AND week_start <= CURRENT_DATE()
  AND zip_code IS NOT NULL;
