-- Dashboard 5: Economic Development & Investment - View Creation
-- Created: November 21, 2025
-- Purpose: Create views for all 6 Dashboard 5 visualizations

-- ==================================================================
-- VIEW 1: v_economic_dashboard
-- Main view combining investment targets, loan eligibility, and permits
-- ==================================================================

CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.gold_data.v_economic_dashboard` AS
SELECT
  -- Identifiers
  zip_code,

  -- Demographics
  population,
  per_capita_income,

  -- Permit Activity
  total_permits_new_construction,
  total_permits_construction,
  median_permit_value,

  -- Indices (0-1 scale, higher = more need)
  inverted_income_index,           -- Low income = high index
  inverted_new_construction_index, -- Low construction = high index
  inverted_permits_index,          -- Low permits = high index
  permit_value_index,

  -- Eligibility
  eligibility_index,               -- Overall eligibility score (0-1)
  is_loan_eligible,                -- TRUE/FALSE flag

  -- Categorize eligibility
  CASE
    WHEN eligibility_index >= 0.8 THEN 'High Priority'
    WHEN eligibility_index >= 0.5 THEN 'Medium Priority'
    WHEN eligibility_index >= 0.3 THEN 'Low Priority'
    ELSE 'Not Eligible'
  END AS priority_category,

  -- Investment need score (composite)
  ROUND((inverted_income_index + inverted_new_construction_index) / 2, 3) AS investment_need_score,

  -- Metadata
  created_at
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_loan_targets`
WHERE zip_code != 'Unknown' AND population > 0;

-- Verify
SELECT
  'v_economic_dashboard' as view_name,
  COUNT(*) as total_zips,
  COUNT(DISTINCT priority_category) as priority_levels,
  SUM(CAST(is_loan_eligible AS INT64)) as eligible_zips,
  ROUND(AVG(per_capita_income), 0) as avg_income,
  SUM(total_permits_new_construction) as total_new_construction
FROM `chicago-bi-app-msds-432-476520.gold_data.v_economic_dashboard`;

-- ==================================================================
-- VIEW 2: v_permits_timeline
-- Time series of permit activity for Viz 2 and Viz 6
-- ==================================================================

CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.gold_data.v_permits_timeline` AS
SELECT
  -- Permit ID for counting
  id AS permit_id,

  -- Date dimensions
  issue_date,
  permit_year,
  permit_month,
  DATE_TRUNC(issue_date, MONTH) AS month_start,
  DATE_TRUNC(issue_date, QUARTER) AS quarter_start,
  FORMAT_DATE('%Y-Q%Q', issue_date) AS year_quarter,

  -- Location
  zip_code,
  community_area,
  neighborhood,

  -- Permit details
  permit_type,
  permit_status,
  work_type,

  -- Financial metrics
  total_fee,
  reported_cost,

  -- Processing
  processing_time,

  -- Calculate fee as % of cost
  CASE
    WHEN reported_cost > 0 THEN ROUND((total_fee / reported_cost) * 100, 2)
    ELSE NULL
  END AS fee_pct_of_cost,

  -- Categorize by cost
  CASE
    WHEN reported_cost >= 1000000 THEN 'Large ($1M+)'
    WHEN reported_cost >= 500000 THEN 'Medium ($500K-$1M)'
    WHEN reported_cost >= 100000 THEN 'Small ($100K-$500K)'
    WHEN reported_cost > 0 THEN 'Minimal (<$100K)'
    ELSE 'Unknown'
  END AS project_size,

  -- Metadata
  enriched_at
FROM `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched`
WHERE permit_type = 'PERMIT - NEW CONSTRUCTION'
  AND issue_date IS NOT NULL
  AND issue_date >= '2020-01-01';

-- Verify
SELECT
  'v_permits_timeline' as view_name,
  COUNT(*) as total_permits,
  MIN(issue_date) as first_date,
  MAX(issue_date) as last_date,
  COUNT(DISTINCT zip_code) as zip_count,
  COUNT(DISTINCT year_quarter) as quarters,
  ROUND(SUM(reported_cost), 0) as total_reported_cost,
  ROUND(SUM(total_fee), 0) as total_fees
FROM `chicago-bi-app-msds-432-476520.gold_data.v_permits_timeline`;

-- ==================================================================
-- VIEW 3: v_permits_by_area
-- Aggregated permit metrics by ZIP for scatter plots and maps
-- ==================================================================

CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.gold_data.v_permits_by_area` AS
WITH permit_agg AS (
  SELECT
    zip_code,
    COUNT(*) as permit_count,
    SUM(reported_cost) as total_cost,
    AVG(reported_cost) as avg_cost,
    SUM(total_fee) as total_fees,
    AVG(total_fee) as avg_fee,
    MIN(issue_date) as first_permit_date,
    MAX(issue_date) as last_permit_date,
    AVG(processing_time) as avg_processing_days
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched`
  WHERE permit_type = 'PERMIT - NEW CONSTRUCTION'
    AND issue_date IS NOT NULL
    AND zip_code IS NOT NULL
    AND zip_code != 'Unknown'
  GROUP BY zip_code
),
socio AS (
  SELECT
    zip_code,
    population,
    per_capita_income,
    eligibility_index,
    is_loan_eligible,
    inverted_income_index,
    total_permits_new_construction
  FROM `chicago-bi-app-msds-432-476520.gold_data.gold_loan_targets`
  WHERE zip_code != 'Unknown'
)
SELECT
  COALESCE(p.zip_code, s.zip_code) as zip_code,

  -- Permit metrics
  COALESCE(p.permit_count, 0) as permit_count,
  COALESCE(p.total_cost, 0) as total_cost,
  COALESCE(p.avg_cost, 0) as avg_cost,
  COALESCE(p.total_fees, 0) as total_fees,
  COALESCE(p.avg_fee, 0) as avg_fee,
  COALESCE(p.avg_processing_days, 0) as avg_processing_days,
  p.first_permit_date,
  p.last_permit_date,

  -- Socioeconomic
  COALESCE(s.population, 0) as population,
  COALESCE(s.per_capita_income, 0) as per_capita_income,
  COALESCE(s.eligibility_index, 0) as eligibility_index,
  COALESCE(s.is_loan_eligible, FALSE) as is_loan_eligible,
  COALESCE(s.inverted_income_index, 0) as inverted_income_index,

  -- Calculated metrics
  CASE
    WHEN s.population > 0 THEN ROUND(p.permit_count / s.population * 1000, 2)
    ELSE 0
  END AS permits_per_1000_residents,

  CASE
    WHEN s.per_capita_income > 0 THEN ROUND(p.avg_cost / s.per_capita_income, 2)
    ELSE 0
  END AS cost_to_income_ratio

FROM permit_agg p
FULL OUTER JOIN socio s ON p.zip_code = s.zip_code;

-- Verify
SELECT
  'v_permits_by_area' as view_name,
  COUNT(*) as total_zips,
  SUM(permit_count) as total_permits,
  ROUND(AVG(per_capita_income), 0) as avg_income,
  SUM(CAST(is_loan_eligible AS INT64)) as eligible_zips,
  ROUND(SUM(total_cost), 0) as total_project_cost,
  ROUND(AVG(permits_per_1000_residents), 2) as avg_permits_per_1k
FROM `chicago-bi-app-msds-432-476520.gold_data.v_permits_by_area`
WHERE permit_count > 0;

-- ==================================================================
-- VIEW 4: v_monthly_permit_summary
-- Monthly aggregations for trend visualization (Viz 6)
-- ==================================================================

CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.gold_data.v_monthly_permit_summary` AS
SELECT
  month_start,
  permit_year,
  permit_month,
  year_quarter,

  -- Aggregated metrics
  COUNT(*) as permit_count,
  COUNT(DISTINCT zip_code) as active_zips,
  SUM(reported_cost) as total_reported_cost,
  AVG(reported_cost) as avg_reported_cost,
  SUM(total_fee) as total_fees,
  AVG(total_fee) as avg_fee,
  AVG(processing_time) as avg_processing_days,

  -- Breakdown by project size
  SUM(CASE WHEN reported_cost >= 1000000 THEN 1 ELSE 0 END) as large_projects,
  SUM(CASE WHEN reported_cost >= 500000 AND reported_cost < 1000000 THEN 1 ELSE 0 END) as medium_projects,
  SUM(CASE WHEN reported_cost >= 100000 AND reported_cost < 500000 THEN 1 ELSE 0 END) as small_projects,
  SUM(CASE WHEN reported_cost < 100000 AND reported_cost > 0 THEN 1 ELSE 0 END) as minimal_projects

FROM `chicago-bi-app-msds-432-476520.gold_data.v_permits_timeline`
GROUP BY month_start, permit_year, permit_month, year_quarter
ORDER BY month_start;

-- Verify
SELECT
  'v_monthly_permit_summary' as view_name,
  COUNT(*) as total_months,
  SUM(permit_count) as total_permits,
  MIN(month_start) as first_month,
  MAX(month_start) as last_month,
  ROUND(AVG(permit_count), 1) as avg_permits_per_month,
  MAX(permit_count) as peak_month_permits
FROM `chicago-bi-app-msds-432-476520.gold_data.v_monthly_permit_summary`;

-- ==================================================================
-- VIEW 5: v_fee_analysis
-- Fee distribution and analysis for Viz 5
-- ==================================================================

CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.gold_data.v_fee_analysis` AS
SELECT
  zip_code,

  -- Count metrics
  COUNT(*) as permit_count,

  -- Fee metrics
  SUM(total_fee) as total_fees_collected,
  AVG(total_fee) as avg_fee,
  MIN(total_fee) as min_fee,
  MAX(total_fee) as max_fee,

  -- Cost metrics
  SUM(reported_cost) as total_project_value,
  AVG(reported_cost) as avg_project_value,

  -- Fee as % of cost
  CASE
    WHEN SUM(reported_cost) > 0 THEN ROUND((SUM(total_fee) / SUM(reported_cost)) * 100, 2)
    ELSE 0
  END AS effective_fee_rate_pct,

  -- Processing time
  AVG(processing_time) as avg_processing_days,

  -- Year breakdown
  SUM(CASE WHEN permit_year = 2025 THEN 1 ELSE 0 END) as permits_2025,
  SUM(CASE WHEN permit_year = 2024 THEN 1 ELSE 0 END) as permits_2024,
  SUM(CASE WHEN permit_year = 2023 THEN 1 ELSE 0 END) as permits_2023,
  SUM(CASE WHEN permit_year = 2022 THEN 1 ELSE 0 END) as permits_2022,
  SUM(CASE WHEN permit_year = 2021 THEN 1 ELSE 0 END) as permits_2021,
  SUM(CASE WHEN permit_year = 2020 THEN 1 ELSE 0 END) as permits_2020

FROM `chicago-bi-app-msds-432-476520.gold_data.v_permits_timeline`
WHERE zip_code IS NOT NULL AND zip_code != 'Unknown'
GROUP BY zip_code;

-- Verify
SELECT
  'v_fee_analysis' as view_name,
  COUNT(*) as total_zips,
  SUM(permit_count) as total_permits,
  ROUND(SUM(total_fees_collected), 0) as total_fees,
  ROUND(AVG(avg_fee), 0) as overall_avg_fee,
  ROUND(AVG(effective_fee_rate_pct), 2) as avg_fee_rate_pct
FROM `chicago-bi-app-msds-432-476520.gold_data.v_fee_analysis`;

-- ==================================================================
-- SUMMARY STATISTICS
-- ==================================================================

SELECT 'DASHBOARD 5 VIEWS SUMMARY' as summary;

SELECT
  'Total ZIPs with data' as metric,
  COUNT(DISTINCT zip_code) as value
FROM `chicago-bi-app-msds-432-476520.gold_data.v_economic_dashboard`
UNION ALL
SELECT
  'Loan eligible ZIPs' as metric,
  COUNT(DISTINCT zip_code) as value
FROM `chicago-bi-app-msds-432-476520.gold_data.v_economic_dashboard`
WHERE is_loan_eligible = TRUE
UNION ALL
SELECT
  'Total NEW CONSTRUCTION permits' as metric,
  COUNT(*) as value
FROM `chicago-bi-app-msds-432-476520.gold_data.v_permits_timeline`
UNION ALL
SELECT
  'Date range (months)' as metric,
  DATE_DIFF(MAX(month_start), MIN(month_start), MONTH) as value
FROM `chicago-bi-app-msds-432-476520.gold_data.v_monthly_permit_summary`
UNION ALL
SELECT
  'Average permits per month' as metric,
  CAST(ROUND(AVG(permit_count), 0) AS INT64) as value
FROM `chicago-bi-app-msds-432-476520.gold_data.v_monthly_permit_summary`;
