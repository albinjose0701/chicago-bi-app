-- ============================================================================
-- Silver Layer: Taxi Trips - Clean & Enriched
-- Applies business rules, removes outliers, adds quality flags
-- ============================================================================

CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.silver_data.taxi_clean` AS
WITH taxi_with_flags AS (
  SELECT
    *,
    -- Data quality flags
    CASE
      WHEN trip_id IS NULL THEN 'missing_trip_id'
      WHEN trip_start_timestamp IS NULL THEN 'missing_start_timestamp'
      WHEN trip_end_timestamp IS NULL THEN 'missing_end_timestamp'
      WHEN trip_end_timestamp <= trip_start_timestamp THEN 'invalid_timestamps'
      WHEN trip_seconds < 60 THEN 'too_short'  -- Less than 1 minute
      WHEN trip_seconds > 36000 THEN 'too_long'  -- More than 10 hours
      WHEN trip_miles < 0 THEN 'negative_miles'
      WHEN trip_miles > 500 THEN 'extreme_miles'
      WHEN trip_total < 0 THEN 'negative_fare'
      WHEN trip_total > 1000 THEN 'extreme_fare'
      WHEN fare < 0 THEN 'negative_base_fare'
      WHEN pickup_latitude IS NULL OR pickup_longitude IS NULL THEN 'missing_pickup_coords'
      WHEN pickup_latitude NOT BETWEEN 41.6 AND 42.1 THEN 'invalid_pickup_lat'
      WHEN pickup_longitude NOT BETWEEN -87.95 AND -87.5 THEN 'invalid_pickup_lon'
      WHEN dropoff_latitude IS NOT NULL AND dropoff_latitude NOT BETWEEN 41.6 AND 42.1 THEN 'invalid_dropoff_lat'
      WHEN dropoff_longitude IS NOT NULL AND dropoff_longitude NOT BETWEEN -87.95 AND -87.5 THEN 'invalid_dropoff_lon'
      ELSE 'valid'
    END as data_quality_flag,

    -- Derived fields
    DATE(trip_start_timestamp) as trip_date,
    EXTRACT(YEAR FROM trip_start_timestamp) as trip_year,
    EXTRACT(MONTH FROM trip_start_timestamp) as trip_month,
    EXTRACT(DAY FROM trip_start_timestamp) as trip_day,
    EXTRACT(HOUR FROM trip_start_timestamp) as trip_hour,
    EXTRACT(DAYOFWEEK FROM trip_start_timestamp) as trip_day_of_week,
    FORMAT_DATE('%A', DATE(trip_start_timestamp)) as trip_day_name,

    -- Time categories
    CASE
      WHEN EXTRACT(HOUR FROM trip_start_timestamp) BETWEEN 6 AND 9 THEN 'Morning Rush (6-9am)'
      WHEN EXTRACT(HOUR FROM trip_start_timestamp) BETWEEN 10 AND 15 THEN 'Midday (10am-3pm)'
      WHEN EXTRACT(HOUR FROM trip_start_timestamp) BETWEEN 16 AND 19 THEN 'Evening Rush (4-7pm)'
      WHEN EXTRACT(HOUR FROM trip_start_timestamp) BETWEEN 20 AND 23 THEN 'Evening (8-11pm)'
      ELSE 'Late Night (12-5am)'
    END as time_category,

    -- Weekend flag
    CASE
      WHEN EXTRACT(DAYOFWEEK FROM trip_start_timestamp) IN (1, 7) THEN TRUE
      ELSE FALSE
    END as is_weekend,

    -- Speed calculation (mph)
    CASE
      WHEN trip_seconds > 0 AND trip_miles > 0
      THEN ROUND(trip_miles / (trip_seconds / 3600.0), 2)
      ELSE NULL
    END as avg_speed_mph,

    -- Fare per mile
    CASE
      WHEN trip_miles > 0 THEN ROUND(trip_total / trip_miles, 2)
      ELSE NULL
    END as fare_per_mile,

    -- Trip distance categories
    CASE
      WHEN trip_miles <= 1 THEN '0-1 miles'
      WHEN trip_miles <= 3 THEN '1-3 miles'
      WHEN trip_miles <= 5 THEN '3-5 miles'
      WHEN trip_miles <= 10 THEN '5-10 miles'
      WHEN trip_miles <= 20 THEN '10-20 miles'
      ELSE '20+ miles'
    END as distance_category,

    -- Fare categories
    CASE
      WHEN trip_total <= 10 THEN '$0-10'
      WHEN trip_total <= 20 THEN '$10-20'
      WHEN trip_total <= 30 THEN '$20-30'
      WHEN trip_total <= 50 THEN '$30-50'
      ELSE '$50+'
    END as fare_category

  FROM `chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips`
)
SELECT
  -- Core identifiers
  trip_id,
  taxi_id,

  -- Timestamps
  trip_start_timestamp,
  trip_end_timestamp,
  trip_date,
  trip_year,
  trip_month,
  trip_day,
  trip_hour,
  trip_day_of_week,
  trip_day_name,
  time_category,
  is_weekend,

  -- Trip metrics
  trip_seconds,
  trip_miles,
  avg_speed_mph,
  distance_category,

  -- Location
  pickup_census_tract,
  dropoff_census_tract,
  pickup_community_area,
  dropoff_community_area,
  pickup_centroid_latitude,
  pickup_centroid_longitude,
  dropoff_centroid_latitude,
  dropoff_centroid_longitude,
  pickup_latitude,
  pickup_longitude,
  dropoff_latitude,
  dropoff_longitude,

  -- Fares
  fare,
  tips,
  tolls,
  extras,
  trip_total,
  fare_per_mile,
  fare_category,

  -- Payment
  payment_type,
  company,

  -- Data quality
  data_quality_flag

FROM taxi_with_flags
WHERE 1=1
  -- Critical filters
  AND trip_id IS NOT NULL
  AND trip_start_timestamp IS NOT NULL
  AND trip_end_timestamp IS NOT NULL
  AND trip_end_timestamp > trip_start_timestamp
  AND DATE(trip_start_timestamp) >= '2020-01-01'
  AND DATE(trip_start_timestamp) <= CURRENT_DATE()

  -- Outlier filters
  AND trip_seconds BETWEEN 60 AND 36000  -- 1 min to 10 hours
  AND trip_miles >= 0 AND trip_miles <= 500
  AND trip_total >= 0 AND trip_total <= 1000
  AND fare >= 0

  -- Coordinate filters
  AND (
    pickup_latitude IS NULL
    OR (pickup_latitude BETWEEN 41.6 AND 42.1 AND pickup_longitude BETWEEN -87.95 AND -87.5)
  );

-- Note: Due to size, we'll create sample materialized views
-- Full materialization would require ~32M rows

-- Create a recent month materialized table for fast queries
CREATE OR REPLACE TABLE `chicago-bi-app-msds-432-476520.silver_data.taxi_clean_recent_month`
PARTITION BY trip_date
CLUSTER BY pickup_community_area, time_category
AS
SELECT *
FROM `chicago-bi-app-msds-432-476520.silver_data.taxi_clean`
WHERE trip_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);

-- Verification query
SELECT
  'Total Records (Last 30 Days)' as metric,
  FORMAT('%,.0f', COUNT(*)) as value
FROM `chicago-bi-app-msds-432-476520.silver_data.taxi_clean_recent_month`

UNION ALL

SELECT
  'Average Trip Miles',
  FORMAT('%.2f', AVG(trip_miles))
FROM `chicago-bi-app-msds-432-476520.silver_data.taxi_clean_recent_month`

UNION ALL

SELECT
  'Average Fare',
  FORMAT('$%.2f', AVG(trip_total))
FROM `chicago-bi-app-msds-432-476520.silver_data.taxi_clean_recent_month`

UNION ALL

SELECT
  'Valid Data %',
  FORMAT('%.1f%%', COUNTIF(data_quality_flag = 'valid') / COUNT(*) * 100)
FROM `chicago-bi-app-msds-432-476520.silver_data.taxi_clean_recent_month`;
