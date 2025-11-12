#!/bin/bash

# ============================================================================
# Recreate Taxi & TNP Trip Tables with Chicago Geographic Bounds Filter
# Adds coordinate validation: 41.6-42.1°N, -87.95 to -87.5°W
# ============================================================================

set -e  # Exit on error

PROJECT_ID="chicago-bi-app-msds-432-476520"
LOCATION="us-central1"

echo "========================================"
echo "Recreating Trip Tables with Geographic Bounds"
echo "Project: $PROJECT_ID"
echo "Location: $LOCATION"
echo "Started: $(date)"
echo "========================================"
echo ""
echo "⚠️  WARNING: This will DROP and RECREATE the following tables:"
echo "   - bronze_taxi_trips (currently 28.5M rows)"
echo "   - bronze_tnp_trips (currently 142.5M rows)"
echo ""
echo "New filter: Chicago bounds (41.6-42.1°N, -87.95 to -87.5°W)"
echo "Strategy: Filter existing bronze tables (much faster than re-scanning raw)"
echo "Estimated time: 1-2 minutes..."
echo ""

# Array of SQL files for trip tables (using existing bronze data)
SQL_FILES=(
  "02_bronze_taxi_trips_from_bronze.sql"
  "03_bronze_tnp_trips_from_bronze.sql"
)

# Execute each SQL file
for sql_file in "${SQL_FILES[@]}"; do
  echo "----------------------------------------"
  echo "Executing: $sql_file"
  echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "----------------------------------------"

  if [ -f "$sql_file" ]; then
    bq query \
      --use_legacy_sql=false \
      --project_id="$PROJECT_ID" \
      --location="$LOCATION" \
      < "$sql_file"

    if [ $? -eq 0 ]; then
      echo "✅ SUCCESS: $sql_file completed"
    else
      echo "❌ ERROR: $sql_file failed"
      exit 1
    fi
  else
    echo "⚠️  WARNING: $sql_file not found, skipping..."
  fi

  echo ""
done

echo "========================================"
echo "Trip Tables Recreated with Geographic Bounds!"
echo "Completed: $(date)"
echo "========================================"
echo ""
echo "Getting updated row counts..."
echo ""

# Query row counts for trip tables
bq query --use_legacy_sql=false --project_id="$PROJECT_ID" "
SELECT 'bronze_taxi_trips' as table_name,
  COUNT(*) as row_count,
  MIN(DATE(trip_start_timestamp)) as min_date,
  MAX(DATE(trip_start_timestamp)) as max_date
FROM \`${PROJECT_ID}.bronze_data.bronze_taxi_trips\`
UNION ALL
SELECT 'bronze_tnp_trips',
  COUNT(*),
  MIN(DATE(trip_start_timestamp)),
  MAX(DATE(trip_start_timestamp))
FROM \`${PROJECT_ID}.bronze_data.bronze_tnp_trips\`
ORDER BY table_name
"

echo ""
echo "✅ Trip tables now include Chicago geographic bounds validation!"
echo ""
echo "Filter summary:"
echo "  - Pickup & dropoff latitude: 41.6 to 42.1"
echo "  - Pickup & dropoff longitude: -87.95 to -87.5"
echo "  - Plus existing filters (trip_miles, fare, duration, non-null coords)"
