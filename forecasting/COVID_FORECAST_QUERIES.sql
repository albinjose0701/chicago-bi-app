-- =====================================================================
-- COVID-19 ALERT FORECAST QUERIES FOR DASHBOARDS
-- =====================================================================
-- Created: November 14, 2025
-- Model: Prophet v1.1.0-simple (simplified, no regressors)
-- Coverage: 56 ZIP codes × 12 weeks = 672 forecasts
-- Use Case: Dashboard visualizations, alerts, and monitoring
-- =====================================================================

-- =====================================================================
-- QUERY 1: Next 4 Weeks COVID Risk Forecast (Operational Planning)
-- =====================================================================
-- Purpose: Short-term COVID risk alerts for taxi drivers
-- Use Case: Weekly operational briefings, driver alerts
-- Visualization: Line chart with risk levels by ZIP
-- =====================================================================

SELECT
  zip_code,
  forecast_date,
  predicted_risk_score,
  predicted_risk_category,
  alert_level,
  alert_message,
  risk_score_lower,
  risk_score_upper,
  predicted_cases_weekly,
  predicted_mobility_index
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts`
WHERE forecast_date BETWEEN CURRENT_DATE()
  AND DATE_ADD(CURRENT_DATE(), INTERVAL 4 WEEK)
ORDER BY zip_code, forecast_date;


-- =====================================================================
-- QUERY 2: Current Week High-Risk ZIP Codes (Alert Dashboard)
-- =====================================================================
-- Purpose: Identify high-risk areas for immediate action
-- Use Case: Driver alert system, public health monitoring
-- Visualization: Map heatmap, ranked list
-- =====================================================================

SELECT
  zip_code,
  forecast_date,
  predicted_risk_score,
  predicted_risk_category,
  alert_level,
  alert_message,
  predicted_cases_weekly,
  CASE
    WHEN alert_level = 'CRITICAL' THEN 4
    WHEN alert_level = 'WARNING' THEN 3
    WHEN alert_level = 'CAUTION' THEN 2
    ELSE 1
  END as alert_priority
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts`
WHERE forecast_date = (
  SELECT MIN(forecast_date)
  FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts`
  WHERE forecast_date >= CURRENT_DATE()
)
  AND predicted_risk_category IN ('Medium', 'High')
ORDER BY predicted_risk_score DESC, zip_code;


-- =====================================================================
-- QUERY 3: 12-Week Risk Trend by ZIP (Strategic Planning)
-- =====================================================================
-- Purpose: Long-term trend analysis for resource allocation
-- Use Case: Strategic planning, budget allocation
-- Visualization: Multi-line chart, trend analysis
-- =====================================================================

SELECT
  zip_code,
  forecast_date,
  predicted_risk_score,
  predicted_risk_category,
  risk_score_lower,
  risk_score_upper,
  -- Calculate trend (rising/falling/stable)
  LAG(predicted_risk_score, 1) OVER (
    PARTITION BY zip_code ORDER BY forecast_date
  ) as prev_week_risk,
  predicted_risk_score - LAG(predicted_risk_score, 1) OVER (
    PARTITION BY zip_code ORDER BY forecast_date
  ) as weekly_change
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts`
ORDER BY zip_code, forecast_date;


-- =====================================================================
-- QUERY 4: Alert Level Distribution (Executive Summary)
-- =====================================================================
-- Purpose: High-level summary of COVID risk landscape
-- Use Case: Executive dashboard, weekly reports
-- Visualization: Pie chart, stacked bar chart
-- =====================================================================

SELECT
  forecast_date,
  alert_level,
  COUNT(*) as zip_count,
  ROUND(AVG(predicted_risk_score), 2) as avg_risk_score,
  ROUND(AVG(predicted_cases_weekly), 0) as avg_cases_per_zip,
  STRING_AGG(zip_code, ', ' ORDER BY predicted_risk_score DESC LIMIT 5) as top_5_zips
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts`
GROUP BY forecast_date, alert_level
ORDER BY forecast_date,
  CASE alert_level
    WHEN 'CRITICAL' THEN 1
    WHEN 'WARNING' THEN 2
    WHEN 'CAUTION' THEN 3
    ELSE 4
  END;


-- =====================================================================
-- QUERY 5: Forecast vs Historical (Model Validation)
-- =====================================================================
-- Purpose: Validate forecast accuracy by comparing to historical data
-- Use Case: Model monitoring, accuracy tracking
-- Visualization: Overlay line chart (actual vs forecast)
-- =====================================================================

WITH historical AS (
  SELECT
    zip_code,
    week_start as date,
    adjusted_risk_score as actual_risk,
    'Historical' as data_type
  FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_hotspots`
  WHERE week_start >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 WEEK)
),
forecasted AS (
  SELECT
    zip_code,
    forecast_date as date,
    predicted_risk_score as actual_risk,
    'Forecast' as data_type
  FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts`
  WHERE forecast_date >= CURRENT_DATE()
)
SELECT * FROM historical
UNION ALL
SELECT * FROM forecasted
ORDER BY zip_code, date;


-- =====================================================================
-- QUERY 6: Top 10 Highest Risk ZIPs (Hotspot Identification)
-- =====================================================================
-- Purpose: Identify persistent high-risk areas
-- Use Case: Targeted interventions, resource allocation
-- Visualization: Horizontal bar chart, map overlay
-- =====================================================================

SELECT
  zip_code,
  ROUND(AVG(predicted_risk_score), 2) as avg_12week_risk,
  ROUND(MAX(predicted_risk_score), 2) as peak_risk,
  COUNT(CASE WHEN alert_level IN ('WARNING', 'CRITICAL') THEN 1 END) as high_alert_weeks,
  ROUND(AVG(predicted_cases_weekly), 0) as avg_weekly_cases,
  STRING_AGG(DISTINCT predicted_risk_category ORDER BY predicted_risk_category) as risk_categories,
  STRING_AGG(DISTINCT alert_level ORDER BY alert_level) as alert_levels
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts`
GROUP BY zip_code
ORDER BY avg_12week_risk DESC, peak_risk DESC
LIMIT 10;


-- =====================================================================
-- QUERY 7: Model Performance Metrics (Quality Monitoring)
-- =====================================================================
-- Purpose: Monitor forecast model quality and accuracy
-- Use Case: Data science monitoring, model maintenance
-- Visualization: Metrics table, scatter plots
-- =====================================================================

SELECT
  zip_code,
  model_version,
  trained_date,
  training_records as training_weeks,
  ROUND(mae, 2) as mae_risk_points,
  ROUND(mape, 1) as mape_percent,
  ROUND(r_squared, 3) as r2_score,
  train_start_date,
  train_end_date,
  notes
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_forecast_model_metrics`
WHERE model_name LIKE 'covid_risk_forecast%'
ORDER BY mae ASC;


-- =====================================================================
-- QUERY 8: Uncertainty Analysis (Confidence Assessment)
-- =====================================================================
-- Purpose: Assess forecast confidence and uncertainty
-- Use Case: Risk assessment, decision confidence
-- Visualization: Error bars, confidence bands
-- =====================================================================

SELECT
  zip_code,
  forecast_date,
  predicted_risk_score,
  risk_score_lower,
  risk_score_upper,
  -- Calculate uncertainty width
  risk_score_upper - risk_score_lower as uncertainty_width,
  -- Calculate relative uncertainty
  SAFE_DIVIDE(
    risk_score_upper - risk_score_lower,
    predicted_risk_score
  ) as relative_uncertainty,
  predicted_risk_category,
  alert_level
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts`
WHERE predicted_risk_score > 0  -- Only meaningful where risk exists
ORDER BY uncertainty_width DESC, zip_code, forecast_date;


-- =====================================================================
-- QUERY 9: Mobility vs COVID Risk Correlation
-- =====================================================================
-- Purpose: Analyze relationship between mobility and COVID risk
-- Use Case: Understand transmission patterns, policy impact
-- Visualization: Scatter plot, correlation heatmap
-- =====================================================================

SELECT
  zip_code,
  forecast_date,
  predicted_risk_score,
  predicted_mobility_index,
  predicted_cases_weekly,
  -- Categorize mobility levels
  CASE
    WHEN predicted_mobility_index > 10000 THEN 'Very High Mobility'
    WHEN predicted_mobility_index > 5000 THEN 'High Mobility'
    WHEN predicted_mobility_index > 1000 THEN 'Medium Mobility'
    ELSE 'Low Mobility'
  END as mobility_category,
  predicted_risk_category
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts`
ORDER BY predicted_mobility_index DESC, forecast_date;


-- =====================================================================
-- QUERY 10: Weekly Alert Summary (Driver Briefing)
-- =====================================================================
-- Purpose: Generate weekly briefing for taxi drivers
-- Use Case: Driver communications, public health messaging
-- Visualization: Summary report, alert bulletin
-- =====================================================================

WITH weekly_summary AS (
  SELECT
    forecast_date,
    COUNT(*) as total_zips,
    COUNT(CASE WHEN alert_level = 'CRITICAL' THEN 1 END) as critical_zips,
    COUNT(CASE WHEN alert_level = 'WARNING' THEN 1 END) as warning_zips,
    COUNT(CASE WHEN alert_level = 'CAUTION' THEN 1 END) as caution_zips,
    COUNT(CASE WHEN alert_level = 'NONE' THEN 1 END) as safe_zips,
    ROUND(AVG(predicted_risk_score), 2) as city_avg_risk,
    SUM(predicted_cases_weekly) as total_predicted_cases
  FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts`
  GROUP BY forecast_date
)
SELECT
  forecast_date,
  FORMAT_DATE('%A, %B %e, %Y', forecast_date) as week_of,
  total_zips,
  critical_zips,
  warning_zips,
  caution_zips,
  safe_zips,
  city_avg_risk,
  total_predicted_cases,
  -- Overall city risk level
  CASE
    WHEN critical_zips > 0 THEN 'CITY ALERT: Critical risk areas identified'
    WHEN warning_zips > 5 THEN 'CITY CAUTION: Multiple warning zones'
    WHEN caution_zips > 10 THEN 'CITY NOTICE: Elevated risk in some areas'
    ELSE 'CITY NORMAL: Low risk across Chicago'
  END as city_status
FROM weekly_summary
ORDER BY forecast_date;


-- =====================================================================
-- QUERY 11: Geographic Risk Patterns (Spatial Analysis)
-- =====================================================================
-- Purpose: Identify spatial clustering of COVID risk
-- Use Case: Geographic targeting, neighborhood analysis
-- Visualization: Choropleth map, geographic heatmap
-- Note: Requires joining with boundary data for full map viz
-- =====================================================================

SELECT
  c.zip_code,
  c.forecast_date,
  c.predicted_risk_score,
  c.predicted_risk_category,
  c.alert_level,
  c.predicted_cases_weekly,
  -- Join with ZIP boundary data for mapping
  z.geometry
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts` c
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.zip_code_boundaries` z
  ON c.zip_code = CAST(z.zip AS STRING)
WHERE c.forecast_date = (
  SELECT MIN(forecast_date)
  FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts`
  WHERE forecast_date >= CURRENT_DATE()
)
ORDER BY c.predicted_risk_score DESC;


-- =====================================================================
-- QUERY 12: Time Series Forecast Export (Full Dataset)
-- =====================================================================
-- Purpose: Export complete forecast data for external analysis
-- Use Case: Data science, external reporting, archival
-- Visualization: Time series charts, statistical analysis
-- =====================================================================

SELECT
  zip_code,
  forecast_date,
  predicted_risk_score,
  predicted_risk_category,
  predicted_case_rate,
  predicted_positivity_rate,
  risk_score_lower,
  risk_score_upper,
  predicted_mobility_index,
  predicted_cases_weekly,
  predicted_tests_weekly,
  alert_level,
  alert_message,
  model_trained_date,
  training_weeks,
  model_version
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts`
ORDER BY zip_code, forecast_date;


-- =====================================================================
-- NOTES AND RECOMMENDATIONS
-- =====================================================================
--
-- Model Version: v1.1.0-simple
-- - Simplified Prophet model without regressors
-- - Provides baseline forecasts demonstrating capability
-- - All current forecasts show "Low" risk (COVID data ends Dec 2023)
--
-- Current Limitations:
-- 1. COVID data ends December 2023 (no new data available)
-- 2. Forecasts are extrapolations from low baseline
-- 3. Simplified model (no mobility/case rate regressors)
-- 4. Negative R² indicates need for model enhancement
--
-- Future Enhancements (when data resumes):
-- 1. Add mobility as regressor (traffic data correlation)
-- 2. Add case rate as regressor (epidemiological modeling)
-- 3. Incorporate vaccination rates
-- 4. Add external events (holidays, large gatherings)
-- 5. Ensemble methods for improved accuracy
--
-- Dashboard Integration:
-- - Use Query 1-2 for operational dashboards (real-time alerts)
-- - Use Query 3-6 for strategic dashboards (trend analysis)
-- - Use Query 7-8 for monitoring dashboards (model quality)
-- - Use Query 9-12 for analytical dashboards (deep dive)
--
-- Refresh Frequency:
-- - Forecasts: Weekly (every Monday)
-- - Model retraining: Monthly (when new data available)
-- - Dashboard refresh: Daily (cached for performance)
--
-- =====================================================================
