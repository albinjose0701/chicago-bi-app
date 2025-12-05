#!/bin/bash

# =====================================================
# Master Script: Create All Gold Layer Tables
# =====================================================
# Purpose: Execute all Gold layer table creation scripts
# Location: us-central1
# Created: 2025-11-13
# =====================================================

set -e  # Exit on any error

PROJECT_ID="chicago-bi-app-msds-432-476520"
LOCATION="us-central1"
DATASET="gold_data"

echo "=========================================="
echo "Gold Layer Table Creation - Master Script"
echo "=========================================="
echo "Project: $PROJECT_ID"
echo "Location: $LOCATION"
echo "Dataset: $DATASET"
echo "Start Time: $(date)"
echo "=========================================="
echo ""

# Verify dataset exists
echo "[1/8] Verifying gold_data dataset exists..."
if bq ls --project_id=$PROJECT_ID | grep -q "$DATASET"; then
  echo "✓ Dataset $DATASET exists"
else
  echo "✗ Dataset $DATASET not found. Creating..."
  bq mk --dataset --location=$LOCATION --description="Gold layer - Analytics-ready aggregations and ML features" $PROJECT_ID:$DATASET
  echo "✓ Dataset created"
fi
echo ""

# Table 1: Taxi Hourly by ZIP
echo "[2/8] Creating gold_taxi_hourly_by_zip..."
START_TIME=$(date +%s)
bq query --location=$LOCATION --use_legacy_sql=false < 02_gold_taxi_hourly_by_zip.sql
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "✓ gold_taxi_hourly_by_zip created in ${DURATION}s"
echo ""

# Table 2: Taxi Daily by ZIP
echo "[3/8] Creating gold_taxi_daily_by_zip..."
START_TIME=$(date +%s)
bq query --location=$LOCATION --use_legacy_sql=false < 03_gold_taxi_daily_by_zip.sql
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "✓ gold_taxi_daily_by_zip created in ${DURATION}s"
echo ""

# Table 3: Route Pairs (Top 10)
echo "[4/8] Creating gold_route_pairs..."
START_TIME=$(date +%s)
bq query --location=$LOCATION --use_legacy_sql=false < 04_gold_route_pairs.sql
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "✓ gold_route_pairs created in ${DURATION}s"
echo ""

# Table 4: Permits ROI
echo "[5/8] Creating gold_permits_roi..."
START_TIME=$(date +%s)
bq query --location=$LOCATION --use_legacy_sql=false < 05_gold_permits_roi.sql
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "✓ gold_permits_roi created in ${DURATION}s"
echo ""

# Table 5: COVID Hotspots (Complex - may take longer)
echo "[6/8] Creating gold_covid_hotspots (complex table, may take 5-10 minutes)..."
START_TIME=$(date +%s)
bq query --location=$LOCATION --use_legacy_sql=false < 06_gold_covid_hotspots.sql
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "✓ gold_covid_hotspots created in ${DURATION}s"
echo ""

# Table 6: Loan Targets
echo "[7/8] Creating gold_loan_targets..."
START_TIME=$(date +%s)
bq query --location=$LOCATION --use_legacy_sql=false < 07_gold_loan_targets.sql
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "✓ gold_loan_targets created in ${DURATION}s"
echo ""

# Table 7: Forecasts (Sample Data)
echo "[8/8] Creating gold_forecasts..."
START_TIME=$(date +%s)
bq query --location=$LOCATION --use_legacy_sql=false < 08_gold_forecasts.sql
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "✓ gold_forecasts created in ${DURATION}s"
echo ""

# List all created tables
echo "=========================================="
echo "All Gold layer tables created successfully!"
echo "=========================================="
echo ""
echo "Tables in $DATASET:"
bq ls --project_id=$PROJECT_ID $DATASET
echo ""

# Summary verification
echo "=========================================="
echo "Quick Verification Summary"
echo "=========================================="

echo ""
echo "1. gold_taxi_hourly_by_zip:"
bq query --location=$LOCATION --use_legacy_sql=false --format=pretty \
  "SELECT COUNT(*) as row_count, MIN(trip_date) as earliest_date, MAX(trip_date) as latest_date FROM \`$PROJECT_ID.$DATASET.gold_taxi_hourly_by_zip\`"

echo ""
echo "2. gold_taxi_daily_by_zip:"
bq query --location=$LOCATION --use_legacy_sql=false --format=pretty \
  "SELECT COUNT(*) as row_count, MIN(trip_date) as earliest_date, MAX(trip_date) as latest_date FROM \`$PROJECT_ID.$DATASET.gold_taxi_daily_by_zip\`"

echo ""
echo "3. gold_route_pairs:"
bq query --location=$LOCATION --use_legacy_sql=false --format=pretty \
  "SELECT COUNT(*) as row_count, MIN(rank) as min_rank, MAX(rank) as max_rank FROM \`$PROJECT_ID.$DATASET.gold_route_pairs\`"

echo ""
echo "4. gold_permits_roi:"
bq query --location=$LOCATION --use_legacy_sql=false --format=pretty \
  "SELECT COUNT(*) as row_count, SUM(total_permits) as total_permits FROM \`$PROJECT_ID.$DATASET.gold_permits_roi\`"

echo ""
echo "5. gold_covid_hotspots:"
bq query --location=$LOCATION --use_legacy_sql=false --format=pretty \
  "SELECT COUNT(*) as row_count, COUNT(DISTINCT zip_code) as unique_zips, COUNT(DISTINCT week_start) as unique_weeks FROM \`$PROJECT_ID.$DATASET.gold_covid_hotspots\`"

echo ""
echo "6. gold_loan_targets:"
bq query --location=$LOCATION --use_legacy_sql=false --format=pretty \
  "SELECT COUNT(*) as row_count, COUNTIF(is_loan_eligible) as eligible_zips FROM \`$PROJECT_ID.$DATASET.gold_loan_targets\`"

echo ""
echo "7. gold_forecasts:"
bq query --location=$LOCATION --use_legacy_sql=false --format=pretty \
  "SELECT COUNT(*) as row_count, COUNT(DISTINCT zip_code) as unique_zips, MIN(forecast_date) as earliest_forecast, MAX(forecast_date) as latest_forecast FROM \`$PROJECT_ID.$DATASET.gold_forecasts\`"

echo ""
echo "=========================================="
echo "Gold Layer Creation Complete!"
echo "End Time: $(date)"
echo "=========================================="
