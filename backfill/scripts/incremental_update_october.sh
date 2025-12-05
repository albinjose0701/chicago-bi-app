#!/bin/bash
#
# Incremental Update for October 2025 - All Layers
# Uses MERGE/DELETE+INSERT for fast updates
#

set -e

PROJECT="chicago-bi-app-msds-432-476520"

echo "================================================"
echo "INCREMENTAL OCTOBER 2025 UPDATE"
echo "================================================"
echo ""

# Step 1: Update Bronze Layer (Taxi Trips only)
echo "[1/4] Updating Bronze Layer - Taxi Trips..."
bq query --location=us-central1 --use_legacy_sql=false "
-- Delete October 2025 data if exists
DELETE FROM \`${PROJECT}.bronze_data.bronze_taxi_trips\`
WHERE DATE(trip_start_timestamp) >= '2025-10-01'
  AND DATE(trip_start_timestamp) <= '2025-10-31';

-- Insert fresh October 2025 data with quality filters
INSERT INTO \`${PROJECT}.bronze_data.bronze_taxi_trips\`
SELECT
  trip_id,
  trip_start_timestamp,
  trip_end_timestamp,
  trip_seconds,
  ROUND(trip_miles, 2) as trip_miles,
  SAFE_CAST(NULLIF(pickup_community_area, '') AS INT64) as pickup_community_area,
  SAFE_CAST(NULLIF(dropoff_community_area, '') AS INT64) as dropoff_community_area,
  ROUND(fare, 2) as fare,
  CAST(NULL AS BOOLEAN) as shared_trip_authorized,
  0 as trips_pooled,
  ROUND(pickup_centroid_latitude, 6) as pickup_centroid_latitude,
  ROUND(pickup_centroid_longitude, 6) as pickup_centroid_longitude,
  ROUND(dropoff_centroid_latitude, 6) as dropoff_centroid_latitude,
  ROUND(dropoff_centroid_longitude, 6) as dropoff_centroid_longitude,
  CURRENT_TIMESTAMP() as extracted_at
FROM \`${PROJECT}.raw_data.raw_taxi_trips\`
WHERE DATE(trip_start_timestamp) >= '2025-10-01'
  AND DATE(trip_start_timestamp) <= '2025-10-31'
  AND pickup_centroid_latitude IS NOT NULL
  AND pickup_centroid_longitude IS NOT NULL
  AND dropoff_centroid_latitude IS NOT NULL
  AND dropoff_centroid_longitude IS NOT NULL
  AND pickup_centroid_latitude BETWEEN 41.6 AND 42.1
  AND pickup_centroid_longitude BETWEEN -87.95 AND -87.5
  AND dropoff_centroid_latitude BETWEEN 41.6 AND 42.1
  AND dropoff_centroid_longitude BETWEEN -87.95 AND -87.5
  AND trip_miles <= 500
  AND trip_seconds <= 100000
  AND fare <= 1000;
"
echo "✅ Bronze layer updated"
echo ""

# Step 2: Update Silver Layer (Trips Enriched)
echo "[2/4] Updating Silver Layer - Trips Enriched..."
bq query --location=us-central1 --use_legacy_sql=false --max_rows=0 "
-- Delete October 2025 taxi trips
DELETE FROM \`${PROJECT}.silver_data.silver_trips_enriched\`
WHERE DATE(trip_start_timestamp) >= '2025-10-01'
  AND DATE(trip_start_timestamp) <= '2025-10-31'
  AND source_dataset = 'taxi';

-- Insert enriched October 2025 taxi trips
INSERT INTO \`${PROJECT}.silver_data.silver_trips_enriched\`
SELECT
  t.trip_id,
  DATE(t.trip_start_timestamp) as trip_date,
  EXTRACT(HOUR FROM t.trip_start_timestamp) as trip_hour,
  t.trip_start_timestamp,
  t.trip_end_timestamp,
  t.trip_seconds,
  t.trip_miles,
  t.pickup_community_area,
  t.dropoff_community_area,
  t.pickup_centroid_latitude,
  t.pickup_centroid_longitude,
  t.dropoff_centroid_latitude,
  t.dropoff_centroid_longitude,
  CAST(pz.zip AS STRING) as pickup_zip,
  CAST(dz.zip AS STRING) as dropoff_zip,
  pn.pri_neigh as pickup_neighborhood,
  dn.pri_neigh as dropoff_neighborhood,
  t.fare,
  t.shared_trip_authorized,
  t.trips_pooled,
  CASE
    WHEN CAST(pz.zip AS STRING) IN ('60666', '60018')
      OR CAST(dz.zip AS STRING) IN ('60666', '60018')
    THEN TRUE
    ELSE FALSE
  END as is_airport_trip,
  'taxi' as source_dataset,
  CURRENT_TIMESTAMP() as enriched_at
FROM \`${PROJECT}.bronze_data.bronze_taxi_trips\` t
LEFT JOIN \`${PROJECT}.reference_data.zip_code_boundaries\` pz
  ON ST_CONTAINS(pz.geometry, ST_GEOGPOINT(t.pickup_centroid_longitude, t.pickup_centroid_latitude))
LEFT JOIN \`${PROJECT}.reference_data.zip_code_boundaries\` dz
  ON ST_CONTAINS(dz.geometry, ST_GEOGPOINT(t.dropoff_centroid_longitude, t.dropoff_centroid_latitude))
LEFT JOIN \`${PROJECT}.reference_data.neighborhood_boundaries\` pn
  ON ST_CONTAINS(pn.geometry, ST_GEOGPOINT(t.pickup_centroid_longitude, t.pickup_centroid_latitude))
LEFT JOIN \`${PROJECT}.reference_data.neighborhood_boundaries\` dn
  ON ST_CONTAINS(dn.geometry, ST_GEOGPOINT(t.dropoff_centroid_longitude, t.dropoff_centroid_latitude))
WHERE DATE(t.trip_start_timestamp) >= '2025-10-01'
  AND DATE(t.trip_start_timestamp) <= '2025-10-31';
"
echo "✅ Silver layer updated"
echo ""

# Step 3: Update Gold Layer - Hourly Aggregations
echo "[3/4] Updating Gold Layer - Hourly Aggregations..."
bq query --location=us-central1 --use_legacy_sql=false --max_rows=0 "
-- Delete October 2025 hourly data
DELETE FROM \`${PROJECT}.gold_data.gold_taxi_hourly_by_zip\`
WHERE trip_date >= '2025-10-01' AND trip_date <= '2025-10-31';

-- Insert fresh October 2025 hourly aggregations
INSERT INTO \`${PROJECT}.gold_data.gold_taxi_hourly_by_zip\`
SELECT
  pickup_zip,
  dropoff_zip,
  trip_date,
  trip_hour,
  COUNT(*) as trip_count,
  ROUND(AVG(trip_miles), 2) as avg_miles,
  ROUND(AVG(fare), 2) as avg_fare,
  CURRENT_TIMESTAMP() as created_at
FROM \`${PROJECT}.silver_data.silver_trips_enriched\`
WHERE trip_date >= '2025-10-01'
  AND trip_date <= '2025-10-31'
  AND source_dataset = 'taxi'
GROUP BY pickup_zip, dropoff_zip, trip_date, trip_hour;
"
echo "✅ Gold hourly aggregations updated"
echo ""

# Step 4: Update Gold Layer - Daily Aggregations
echo "[4/4] Updating Gold Layer - Daily Aggregations..."
bq query --location=us-central1 --use_legacy_sql=false --max_rows=0 "
-- Delete October 2025 daily data
DELETE FROM \`${PROJECT}.gold_data.gold_taxi_daily_by_zip\`
WHERE trip_date >= '2025-10-01' AND trip_date <= '2025-10-31';

-- Insert fresh October 2025 daily aggregations
INSERT INTO \`${PROJECT}.gold_data.gold_taxi_daily_by_zip\`
SELECT
  pickup_zip,
  dropoff_zip,
  trip_date,
  COUNT(*) as trip_count,
  ROUND(AVG(trip_miles), 2) as avg_miles,
  ROUND(AVG(fare), 2) as avg_fare,
  CURRENT_TIMESTAMP() as created_at
FROM \`${PROJECT}.silver_data.silver_trips_enriched\`
WHERE trip_date >= '2025-10-01'
  AND trip_date <= '2025-10-31'
  AND source_dataset = 'taxi'
GROUP BY pickup_zip, dropoff_zip, trip_date;
"
echo "✅ Gold daily aggregations updated"
echo ""

echo "================================================"
echo "INCREMENTAL UPDATE COMPLETE!"
echo "================================================"
echo ""
echo "Summary:"
echo "  ✅ Bronze layer: October 2025 taxi trips filtered"
echo "  ✅ Silver layer: October 2025 trips enriched with ZIP/neighborhood"
echo "  ✅ Gold hourly: October 2025 aggregations updated"
echo "  ✅ Gold daily: October 2025 aggregations updated"
echo ""
echo "Note: Route pairs and forecasts tables not updated (require full refresh)"
