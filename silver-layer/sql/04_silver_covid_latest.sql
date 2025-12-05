-- ============================================================================
-- Silver Layer: COVID-19 Latest Week by ZIP Code
-- Most recent week data with risk categorization
-- ============================================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.silver_data.silver_covid_latest`
AS
WITH latest_week AS (
  SELECT
    zip_code,
    MAX(week_end) as latest_week_end
  FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_covid_cases`
  GROUP BY zip_code
),
covid_latest_week AS (
  SELECT
    c.zip_code,
    c.week_end as latest_week_end,
    c.cases_weekly,
    ROUND(c.case_rate_weekly, 2) as case_rate_weekly,
    c.tests_weekly,
    c.deaths_weekly,
    c.population
  FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_covid_cases` c
  INNER JOIN latest_week lw
    ON c.zip_code = lw.zip_code
    AND c.week_end = lw.latest_week_end
)
SELECT
  -- Primary key
  zip_code,

  -- Latest week data
  latest_week_end,
  cases_weekly,
  case_rate_weekly,
  tests_weekly,
  deaths_weekly,
  population,

  -- Risk categorization based on case rate per 100,000
  CASE
    WHEN case_rate_weekly >= 400 THEN 'High'
    WHEN case_rate_weekly >= 200 THEN 'Medium'
    ELSE 'Low'
  END as risk_category,

  -- Audit timestamp
  CURRENT_TIMESTAMP() as created_at

FROM covid_latest_week;
