-- ============================================================================
-- Bronze Layer: Taxi Trips
-- Filters: Valid coordinates, trip_miles <= 500, trip_seconds <= 100000, fare <= 1000
-- ============================================================================

CREATE OR REPLACE TABLE `chicago-bi-app-msds-432-476520.bronze_data.bronze_taxi_trips`
PARTITION BY DATE(trip_start_timestamp)
CLUSTER BY pickup_community_area, dropoff_community_area
AS
SELECT
  -- Primary key
  trip_id,

  -- Timestamps
  trip_start_timestamp,
  trip_end_timestamp,

  -- Trip metrics
  trip_seconds,
  ROUND(trip_miles, 2) as trip_miles,

  -- Community areas (convert from STRING to INTEGER, handle blank strings)
  SAFE_CAST(NULLIF(pickup_community_area, '') AS INT64) as pickup_community_area,
  SAFE_CAST(NULLIF(dropoff_community_area, '') AS INT64) as dropoff_community_area,

  -- Fare
  ROUND(fare, 2) as fare,

  -- Shared trip info (taxi trips don't have these fields, set to NULL/0)
  CAST(NULL AS BOOLEAN) as shared_trip_authorized,
  0 as trips_pooled,

  -- Coordinates (centroid)
  ROUND(pickup_centroid_latitude, 6) as pickup_centroid_latitude,
  ROUND(pickup_centroid_longitude, 6) as pickup_centroid_longitude,
  ROUND(dropoff_centroid_latitude, 6) as dropoff_centroid_latitude,
  ROUND(dropoff_centroid_longitude, 6) as dropoff_centroid_longitude,

  -- Metadata
  CURRENT_TIMESTAMP() as extracted_at

FROM `chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips`

WHERE 1=1
  -- Partition filter (required for partitioned tables)
  AND DATE(trip_start_timestamp) >= '2020-01-01'
  AND DATE(trip_start_timestamp) <= CURRENT_DATE()

  -- Coordinate quality filters (not null)
  AND pickup_centroid_latitude IS NOT NULL
  AND pickup_centroid_longitude IS NOT NULL
  AND dropoff_centroid_latitude IS NOT NULL
  AND dropoff_centroid_longitude IS NOT NULL

  -- Chicago bounds validation (same as building permits)
  AND pickup_centroid_latitude BETWEEN 41.6 AND 42.1
  AND pickup_centroid_longitude BETWEEN -87.95 AND -87.5
  AND dropoff_centroid_latitude BETWEEN 41.6 AND 42.1
  AND dropoff_centroid_longitude BETWEEN -87.95 AND -87.5

  -- Trip quality filters
  AND trip_miles IS NOT NULL
  AND trip_miles <= 500
  AND trip_miles >= 0

  AND trip_seconds IS NOT NULL
  AND trip_seconds <= 100000
  AND trip_seconds > 0

  AND fare IS NOT NULL
  AND fare <= 1000
  AND fare >= 0;
