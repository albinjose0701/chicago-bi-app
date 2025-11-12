#!/bin/bash

# ============================================================================
# Master Script: Create All Bronze Layer Tables
# Executes all bronze table creation scripts in order
# ============================================================================

set -e  # Exit on error

PROJECT_ID="chicago-bi-app-msds-432-476520"
LOCATION="us-central1"

echo "========================================"
echo "Creating Bronze Layer Tables"
echo "Project: $PROJECT_ID"
echo "Location: $LOCATION"
echo "Started: $(date)"
echo "========================================"
echo ""

# Array of SQL files to execute in order
SQL_FILES=(
  "01_create_bronze_dataset.sql"
  "02_bronze_taxi_trips.sql"
  "03_bronze_tnp_trips.sql"
  "04_bronze_covid_cases.sql"
  "05_bronze_building_permits.sql"
  "06_bronze_ccvi.sql"
  "07_bronze_public_health.sql"
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
echo "Bronze Layer Creation Complete!"
echo "Completed: $(date)"
echo "========================================"
echo ""
echo "Verifying tables..."
echo ""

# List all bronze tables
bq ls --project_id="$PROJECT_ID" bronze_data

echo ""
echo "To query row counts:"
echo "bq query --use_legacy_sql=false 'SELECT \"bronze_taxi_trips\" as table_name, COUNT(*) as row_count FROM \`${PROJECT_ID}.bronze_data.bronze_taxi_trips\`'"
