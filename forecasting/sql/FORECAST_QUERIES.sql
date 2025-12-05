-- ==============================================================================
-- TRAFFIC VOLUME FORECAST QUERIES FOR DASHBOARDS
-- Chicago BI App - Prophet Forecasting v1.1.0
-- Requirements: 4 & 9 (Daily/Weekly/Monthly Traffic Patterns)
-- ==============================================================================

-- Query 1: Next 7 Days Forecast by ZIP Code
-- Use: Short-term traffic predictions for operational planning
SELECT
  zip_code,
  forecast_date,
  ROUND(yhat, 0) as predicted_trips,
  ROUND(yhat_lower, 0) as lower_bound,
  ROUND(yhat_upper, 0) as upper_bound,
  ROUND(trend, 0) as trend_component
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_traffic_forecasts_by_zip`
WHERE forecast_date BETWEEN CURRENT_DATE() AND DATE_ADD(CURRENT_DATE(), INTERVAL 7 DAY)
ORDER BY zip_code, forecast_date;

-- Query 2: Weekly Aggregated Forecast (Next 12 Weeks)
-- Use: Medium-term planning and resource allocation
SELECT
  zip_code,
  DATE_TRUNC(forecast_date, WEEK(MONDAY)) as week_start,
  ROUND(SUM(yhat), 0) as weekly_predicted_trips,
  ROUND(SUM(yhat_lower), 0) as weekly_lower_bound,
  ROUND(SUM(yhat_upper), 0) as weekly_upper_bound,
  ROUND(AVG(trend), 0) as avg_weekly_trend
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_traffic_forecasts_by_zip`
WHERE forecast_date BETWEEN CURRENT_DATE() AND DATE_ADD(CURRENT_DATE(), INTERVAL 12 WEEK)
GROUP BY zip_code, week_start
ORDER BY zip_code, week_start;

-- Query 3: Monthly Forecast Summary
-- Use: Long-term strategic planning
SELECT
  zip_code,
  DATE_TRUNC(forecast_date, MONTH) as forecast_month,
  ROUND(SUM(yhat), 0) as monthly_predicted_trips,
  ROUND(AVG(yhat), 0) as avg_daily_trips,
  ROUND(SUM(yhat_lower), 0) as monthly_lower_bound,
  ROUND(SUM(yhat_upper), 0) as monthly_upper_bound
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_traffic_forecasts_by_zip`
GROUP BY zip_code, forecast_month
ORDER BY zip_code, forecast_month;

-- Query 4: Top 10 High-Traffic ZIPs (Next 30 Days)
-- Use: Identify hotspots for targeted interventions
SELECT
  zip_code,
  ROUND(SUM(yhat), 0) as total_predicted_trips_30d,
  ROUND(AVG(yhat), 0) as avg_daily_trips,
  ROUND(AVG(trend), 0) as trend_direction
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_traffic_forecasts_by_zip`
WHERE forecast_date BETWEEN CURRENT_DATE() AND DATE_ADD(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY zip_code
ORDER BY total_predicted_trips_30d DESC
LIMIT 10;

-- Query 5: Compare Forecast vs Actual (When Historical Data Available)
-- Use: Model validation and forecast accuracy monitoring
WITH actual_data AS (
  SELECT
    pickup_zip as zip_code,
    trip_date,
    SUM(trip_count) as actual_trips
  FROM `chicago-bi-app-msds-432-476520.gold_data.gold_taxi_daily_by_zip`
  WHERE trip_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  GROUP BY pickup_zip, trip_date
),
forecast_data AS (
  SELECT
    zip_code,
    forecast_date,
    yhat as predicted_trips
  FROM `chicago-bi-app-msds-432-476520.gold_data.gold_traffic_forecasts_by_zip`
)
SELECT
  a.zip_code,
  a.trip_date,
  a.actual_trips,
  f.predicted_trips,
  ROUND(f.predicted_trips - a.actual_trips, 0) as forecast_error,
  ROUND(ABS(f.predicted_trips - a.actual_trips) / NULLIF(a.actual_trips, 0) * 100, 1) as mape_pct
FROM actual_data a
LEFT JOIN forecast_data f
  ON a.zip_code = f.zip_code
  AND a.trip_date = f.forecast_date
WHERE f.predicted_trips IS NOT NULL
ORDER BY a.zip_code, a.trip_date;

-- Query 6: Seasonality Breakdown (Next 7 Days)
-- Use: Understand forecast components (trend, yearly, weekly patterns)
SELECT
  zip_code,
  forecast_date,
  ROUND(yhat, 0) as total_predicted,
  ROUND(trend, 0) as trend_component,
  ROUND(yearly, 0) as yearly_seasonality,
  ROUND(weekly, 0) as weekly_seasonality,
  model_version
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_traffic_forecasts_by_zip`
WHERE forecast_date BETWEEN CURRENT_DATE() AND DATE_ADD(CURRENT_DATE(), INTERVAL 7 DAY)
  AND zip_code IN ('60601', '60611', '60616')  -- Downtown ZIPs
ORDER BY zip_code, forecast_date;

-- Query 7: Model Performance Metrics
-- Use: Dashboard KPIs for model monitoring
SELECT
  model_name,
  model_version,
  trained_date,
  COUNT(*) as zip_codes_modeled,
  ROUND(AVG(mae), 1) as avg_mae,
  ROUND(AVG(mape), 1) as avg_mape_pct,
  ROUND(AVG(r_squared), 3) as avg_r2,
  ROUND(AVG(training_records), 0) as avg_training_days
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_forecast_model_metrics`
WHERE model_name LIKE 'traffic_forecast%'
GROUP BY model_name, model_version, trained_date
ORDER BY trained_date DESC;

-- Query 8: Forecast Uncertainty Analysis
-- Use: Identify ZIPs with high forecast uncertainty
SELECT
  zip_code,
  ROUND(AVG(yhat), 0) as avg_prediction,
  ROUND(AVG(yhat_upper - yhat_lower), 0) as avg_uncertainty_range,
  ROUND(AVG((yhat_upper - yhat_lower) / NULLIF(yhat, 0) * 100), 1) as uncertainty_pct
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_traffic_forecasts_by_zip`
WHERE forecast_date BETWEEN CURRENT_DATE() AND DATE_ADD(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY zip_code
HAVING avg_prediction > 0
ORDER BY uncertainty_pct DESC
LIMIT 20;

-- Query 9: Day-of-Week Forecast Pattern (Next 4 Weeks)
-- Use: Identify weekly patterns for resource scheduling
SELECT
  zip_code,
  EXTRACT(DAYOFWEEK FROM forecast_date) as day_of_week,
  FORMAT_DATE('%A', forecast_date) as day_name,
  ROUND(AVG(yhat), 0) as avg_predicted_trips,
  COUNT(*) as forecast_days
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_traffic_forecasts_by_zip`
WHERE forecast_date BETWEEN CURRENT_DATE() AND DATE_ADD(CURRENT_DATE(), INTERVAL 28 DAY)
  AND zip_code = '60601'  -- Adjust for specific ZIP
GROUP BY zip_code, day_of_week, day_name
ORDER BY day_of_week;

-- Query 10: Growth Rate Forecast (Month-over-Month)
-- Use: Identify growing/declining areas
WITH monthly_forecasts AS (
  SELECT
    zip_code,
    DATE_TRUNC(forecast_date, MONTH) as forecast_month,
    SUM(yhat) as monthly_trips
  FROM `chicago-bi-app-msds-432-476520.gold_data.gold_traffic_forecasts_by_zip`
  GROUP BY zip_code, forecast_month
)
SELECT
  cur.zip_code,
  cur.forecast_month,
  ROUND(cur.monthly_trips, 0) as current_month_trips,
  ROUND(prev.monthly_trips, 0) as previous_month_trips,
  ROUND((cur.monthly_trips - prev.monthly_trips) / NULLIF(prev.monthly_trips, 0) * 100, 1) as mom_growth_pct
FROM monthly_forecasts cur
LEFT JOIN monthly_forecasts prev
  ON cur.zip_code = prev.zip_code
  AND prev.forecast_month = DATE_SUB(cur.forecast_month, INTERVAL 1 MONTH)
WHERE prev.monthly_trips IS NOT NULL
ORDER BY mom_growth_pct DESC;

-- ==============================================================================
-- NOTES:
-- 1. All forecasts are ZIP-specific and start from each ZIP's last data date
-- 2. Forecast horizon: 90 days from last available data per ZIP
-- 3. Model trained on full historical data (2020-2025) per ZIP
-- 4. Negative R² values indicate poor fit for low-volume ZIPs (consider thresholds)
-- 5. Update queries to use appropriate date filters based on dashboard refresh schedule
-- ==============================================================================
