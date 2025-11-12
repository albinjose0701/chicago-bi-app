-- ============================================================================
-- Bronze Layer: TNP Trips (Recreate from existing bronze with geo bounds)
-- Add Chicago geographic bounds filter to existing bronze data
-- ============================================================================

CREATE OR REPLACE TABLE `chicago-bi-app-msds-432-476520.bronze_data.bronze_tnp_trips`
PARTITION BY DATE(trip_start_timestamp)
CLUSTER BY pickup_community_area, dropoff_community_area
AS
SELECT *
FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_tnp_trips`
WHERE 1=1
  -- Chicago bounds validation for pickup
  AND pickup_centroid_latitude BETWEEN 41.6 AND 42.1
  AND pickup_centroid_longitude BETWEEN -87.95 AND -87.5

  -- Chicago bounds validation for dropoff
  AND dropoff_centroid_latitude BETWEEN 41.6 AND 42.1
  AND dropoff_centroid_longitude BETWEEN -87.95 AND -87.5;
