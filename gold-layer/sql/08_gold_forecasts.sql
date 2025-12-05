-- =====================================================
-- Gold Layer: Trip Forecasts (Prophet-style Sample Data)
-- =====================================================
-- Purpose: Generate sample forecasts for trip counts by ZIP
-- Source: silver_data.silver_trips_enriched (historical data)
-- Model: Sample forecasts using 7-day moving average as predictor
-- Granularity: zip_code, forecast_date (30 days forward)
-- Created: 2025-11-13
-- Note: This is sample/placeholder data. Replace with actual Prophet model output.
-- =====================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.gold_data.gold_forecasts`
AS
WITH
-- Step 1: Get the latest trip date globally
latest_date AS (
  SELECT MAX(trip_date) as max_date
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_trips_enriched`
),

-- Step 2: Calculate recent average trip counts by ZIP (last 30 days of available data)
recent_trip_averages AS (
  SELECT
    pickup_zip as zip_code,
    AVG(trip_count) as avg_daily_trips,
    STDDEV(trip_count) as stddev_daily_trips,
    MAX(trip_date) as last_trip_date
  FROM (
    SELECT
      pickup_zip,
      trip_date,
      COUNT(*) as trip_count
    FROM `chicago-bi-app-msds-432-476520.silver_data.silver_trips_enriched`, latest_date
    WHERE
      pickup_zip IS NOT NULL
      AND trip_date >= DATE_SUB(latest_date.max_date, INTERVAL 30 DAY)
    GROUP BY pickup_zip, trip_date
  )
  GROUP BY pickup_zip
  HAVING COUNT(*) >= 7  -- Only include ZIPs with at least 7 days of data
),

-- Step 3: Generate future dates (next 30 days from last trip date)
date_series AS (
  SELECT
    DATE_ADD(ld.max_date, INTERVAL day_offset DAY) as forecast_date
  FROM latest_date ld, UNNEST(GENERATE_ARRAY(1, 30)) as day_offset
),

-- Step 4: Cross join ZIPs with future dates
zip_date_combinations AS (
  SELECT
    rta.zip_code,
    ds.forecast_date,
    rta.avg_daily_trips,
    rta.stddev_daily_trips
  FROM recent_trip_averages rta
  CROSS JOIN date_series ds
),

-- Step 5: Generate sample predictions with simulated Prophet-style outputs
forecasts AS (
  SELECT
    zip_code,
    forecast_date,

    -- Predicted trip count (yhat): Use average with small random variation
    -- In real Prophet, this would be the model's prediction
    ROUND(
      avg_daily_trips *
      (1 + (MOD(CAST(FARM_FINGERPRINT(CONCAT(zip_code, CAST(forecast_date AS STRING))) AS INT64), 21) - 10) / 100.0),
      2
    ) as predicted_trip_count,

    -- Lower bound (yhat_lower): ~80% of prediction (simulating confidence interval)
    ROUND(
      avg_daily_trips * 0.8 *
      (1 + (MOD(CAST(FARM_FINGERPRINT(CONCAT(zip_code, CAST(forecast_date AS STRING))) AS INT64), 21) - 10) / 100.0),
      2
    ) as lower_bound,

    -- Upper bound (yhat_upper): ~120% of prediction (simulating confidence interval)
    ROUND(
      avg_daily_trips * 1.2 *
      (1 + (MOD(CAST(FARM_FINGERPRINT(CONCAT(zip_code, CAST(forecast_date AS STRING))) AS INT64), 21) - 10) / 100.0),
      2
    ) as upper_bound

  FROM zip_date_combinations
)

-- Step 6: Final output
SELECT
  zip_code,
  forecast_date,
  predicted_trip_count,
  lower_bound,
  upper_bound,
  'prophet_sample' as model_name,  -- Indicates this is sample data
  CURRENT_TIMESTAMP() as trained_at,
  CURRENT_TIMESTAMP() as created_at

FROM forecasts;

-- =====================================================
-- Verification Query
-- =====================================================
-- SELECT
--   COUNT(*) as total_forecasts,
--   COUNT(DISTINCT zip_code) as unique_zips,
--   COUNT(DISTINCT forecast_date) as unique_dates,
--   MIN(forecast_date) as earliest_forecast,
--   MAX(forecast_date) as latest_forecast,
--   ROUND(AVG(predicted_trip_count), 2) as avg_predicted_trips,
--   model_name,
--   trained_at
-- FROM `chicago-bi-app-msds-432-476520.gold_data.gold_forecasts`
-- GROUP BY model_name, trained_at;

-- =====================================================
-- Notes for Future Implementation
-- =====================================================
-- To replace with actual Prophet forecasts:
-- 1. Export historical trip data: SELECT pickup_zip, trip_date, COUNT(*) as y FROM silver_trips_enriched GROUP BY 1,2
-- 2. Train Prophet model in Python for each ZIP code
-- 3. Load Prophet predictions (ds, yhat, yhat_lower, yhat_upper) into this table
-- 4. Update model_name to 'prophet' and trained_at to actual training timestamp
-- 5. Consider using Cloud Functions or Vertex AI for automated retraining
