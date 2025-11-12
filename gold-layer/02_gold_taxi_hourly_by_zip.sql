-- =====================================================
-- Gold Layer: Taxi Hourly Aggregations by ZIP Code
-- =====================================================
-- Purpose: Hourly trip aggregations by pickup/dropoff ZIP
-- Source: silver_data.silver_trips_enriched
-- Granularity: pickup_zip, dropoff_zip, trip_date, trip_hour
-- Created: 2025-11-13
-- =====================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.gold_data.gold_taxi_hourly_by_zip`
PARTITION BY trip_date
CLUSTER BY pickup_zip, dropoff_zip, trip_hour
AS
SELECT
  -- Grouping dimensions
  pickup_zip,
  dropoff_zip,
  trip_date,
  trip_hour,

  -- Aggregated metrics
  COUNT(*) as trip_count,
  ROUND(AVG(trip_miles), 2) as avg_miles,
  ROUND(AVG(fare), 2) as avg_fare,

  -- Audit timestamp
  CURRENT_TIMESTAMP() as created_at

FROM `chicago-bi-app-msds-432-476520.silver_data.silver_trips_enriched`

WHERE
  -- Only include records with valid ZIP codes
  pickup_zip IS NOT NULL
  AND dropoff_zip IS NOT NULL

GROUP BY
  pickup_zip,
  dropoff_zip,
  trip_date,
  trip_hour;

-- =====================================================
-- Verification Query
-- =====================================================
-- SELECT
--   COUNT(*) as total_records,
--   COUNT(DISTINCT pickup_zip) as unique_pickup_zips,
--   COUNT(DISTINCT dropoff_zip) as unique_dropoff_zips,
--   COUNT(DISTINCT trip_date) as unique_dates,
--   MIN(trip_date) as earliest_date,
--   MAX(trip_date) as latest_date,
--   SUM(trip_count) as total_trips,
--   ROUND(AVG(avg_miles), 2) as overall_avg_miles,
--   ROUND(AVG(avg_fare), 2) as overall_avg_fare
-- FROM `chicago-bi-app-msds-432-476520.gold_data.gold_taxi_hourly_by_zip`;
