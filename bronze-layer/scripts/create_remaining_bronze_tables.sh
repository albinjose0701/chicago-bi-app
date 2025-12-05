#!/bin/bash

# ============================================================================
# Create Remaining Bronze Layer Tables (4 tables)
# Executes only the tables that haven't been created yet
# Skips taxi and TNP which already exist
# ============================================================================

set -e  # Exit on error

PROJECT_ID="chicago-bi-app-msds-432-476520"
LOCATION="us-central1"

echo "========================================"
echo "Creating Remaining Bronze Layer Tables"
echo "Project: $PROJECT_ID"
echo "Location: $LOCATION"
echo "Started: $(date)"
echo "========================================"
echo ""
echo "Skipping: bronze_taxi_trips (already exists)"
echo "Skipping: bronze_tnp_trips (already exists)"
echo ""

# Array of SQL files for missing tables only
SQL_FILES=(
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
echo "Remaining Bronze Tables Created!"
echo "Completed: $(date)"
echo "========================================"
echo ""
echo "Verifying all bronze tables..."
echo ""

# List all bronze tables
bq ls --project_id="$PROJECT_ID" bronze_data

echo ""
echo "Getting row counts..."
echo ""

# Query row counts for all bronze tables
bq query --use_legacy_sql=false --project_id="$PROJECT_ID" "
SELECT 'bronze_taxi_trips' as table_name, COUNT(*) as row_count
FROM \`${PROJECT_ID}.bronze_data.bronze_taxi_trips\`
UNION ALL
SELECT 'bronze_tnp_trips', COUNT(*)
FROM \`${PROJECT_ID}.bronze_data.bronze_tnp_trips\`
UNION ALL
SELECT 'bronze_covid_cases', COUNT(*)
FROM \`${PROJECT_ID}.bronze_data.bronze_covid_cases\`
UNION ALL
SELECT 'bronze_building_permits', COUNT(*)
FROM \`${PROJECT_ID}.bronze_data.bronze_building_permits\`
UNION ALL
SELECT 'bronze_ccvi', COUNT(*)
FROM \`${PROJECT_ID}.bronze_data.bronze_ccvi\`
UNION ALL
SELECT 'bronze_public_health', COUNT(*)
FROM \`${PROJECT_ID}.bronze_data.bronze_public_health\`
ORDER BY table_name
"

echo ""
echo "✅ Bronze layer complete - all 6 tables created!"
