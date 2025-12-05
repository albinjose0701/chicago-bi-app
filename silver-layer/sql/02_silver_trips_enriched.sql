-- ============================================================================
-- Silver Layer: Trips Enriched (Taxi + TNP Combined)
-- Combines taxi and TNP trips with spatial enrichment
-- ============================================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.silver_data.silver_trips_enriched`
PARTITION BY trip_date
CLUSTER BY source_dataset, pickup_community_area, dropoff_community_area
AS
WITH combined_trips AS (
  -- Taxi trips
  SELECT
    trip_id,
    trip_start_timestamp,
    trip_end_timestamp,
    trip_seconds,
    trip_miles,
    pickup_community_area,
    dropoff_community_area,
    pickup_centroid_latitude,
    pickup_centroid_longitude,
    dropoff_centroid_latitude,
    dropoff_centroid_longitude,
    fare,
    FALSE as shared_trip_authorized,  -- All taxi trips are not shared
    1 as trips_pooled,                -- All taxi trips count as 1
    'taxi' as source_dataset
  FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_taxi_trips`
  WHERE DATE(trip_start_timestamp) >= '2020-01-01'
    AND DATE(trip_start_timestamp) <= CURRENT_DATE()

  UNION ALL

  -- TNP (rideshare) trips
  SELECT
    trip_id,
    trip_start_timestamp,
    trip_end_timestamp,
    trip_seconds,
    trip_miles,
    pickup_community_area,
    dropoff_community_area,
    pickup_centroid_latitude,
    pickup_centroid_longitude,
    dropoff_centroid_latitude,
    dropoff_centroid_longitude,
    fare,
    shared_trip_authorized,
    trips_pooled,
    'tnp' as source_dataset
  FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_tnp_trips`
  WHERE DATE(trip_start_timestamp) >= '2020-01-01'
    AND DATE(trip_start_timestamp) <= CURRENT_DATE()
),
trips_with_geography AS (
  SELECT
    t.*,
    -- Create geography points for spatial joins
    ST_GEOGPOINT(t.pickup_centroid_longitude, t.pickup_centroid_latitude) as pickup_point,
    ST_GEOGPOINT(t.dropoff_centroid_longitude, t.dropoff_centroid_latitude) as dropoff_point
  FROM combined_trips t
),
trips_with_zip AS (
  SELECT
    t.*,
    -- Pickup ZIP code via spatial join (convert INTEGER to STRING)
    CAST(pz.zip AS STRING) as pickup_zip,
    -- Dropoff ZIP code via spatial join (convert INTEGER to STRING)
    CAST(dz.zip AS STRING) as dropoff_zip
  FROM trips_with_geography t
  LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.zip_code_boundaries` pz
    ON ST_CONTAINS(pz.geometry, t.pickup_point)
  LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.zip_code_boundaries` dz
    ON ST_CONTAINS(dz.geometry, t.dropoff_point)
),
trips_with_neighborhood AS (
  SELECT
    t.*,
    -- Pickup neighborhood via spatial join
    pn.pri_neigh as pickup_neighborhood,
    -- Dropoff neighborhood via spatial join
    dn.pri_neigh as dropoff_neighborhood
  FROM trips_with_zip t
  LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.neighborhood_boundaries` pn
    ON ST_CONTAINS(pn.geometry, t.pickup_point)
  LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.neighborhood_boundaries` dn
    ON ST_CONTAINS(dn.geometry, t.dropoff_point)
)
SELECT
  -- Primary key
  trip_id,

  -- Derived date/time fields
  DATE(trip_start_timestamp) as trip_date,
  EXTRACT(HOUR FROM trip_start_timestamp) as trip_hour,

  -- Timestamps
  trip_start_timestamp,
  trip_end_timestamp,

  -- Trip metrics
  trip_seconds,
  ROUND(trip_miles, 2) as trip_miles,

  -- Original location fields
  pickup_community_area,
  dropoff_community_area,
  ROUND(pickup_centroid_latitude, 6) as pickup_centroid_latitude,
  ROUND(pickup_centroid_longitude, 6) as pickup_centroid_longitude,
  ROUND(dropoff_centroid_latitude, 6) as dropoff_centroid_latitude,
  ROUND(dropoff_centroid_longitude, 6) as dropoff_centroid_longitude,

  -- Enriched geography fields (from spatial joins)
  pickup_zip,
  dropoff_zip,
  pickup_neighborhood,
  dropoff_neighborhood,

  -- Fare
  ROUND(fare, 2) as fare,

  -- Trip characteristics
  shared_trip_authorized,
  trips_pooled,

  -- Airport trip flag (O'Hare: 60666, Midway: 60018)
  CASE
    WHEN pickup_zip IN ('60666', '60018')
      OR dropoff_zip IN ('60666', '60018')
    THEN TRUE
    ELSE FALSE
  END as is_airport_trip,

  -- Source dataset (lineage)
  source_dataset,

  -- Audit timestamp
  CURRENT_TIMESTAMP() as enriched_at

FROM trips_with_neighborhood;
