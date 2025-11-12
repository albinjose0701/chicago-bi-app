#!/bin/bash

# ============================================================================
# Create All Silver Layer Tables
# Executes all silver layer table creation scripts in sequence
# ============================================================================

set -e  # Exit on error

PROJECT_ID="chicago-bi-app-msds-432-476520"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "Creating Silver Layer Tables"
echo "Project: ${PROJECT_ID}"
echo "============================================"
echo ""

# Step 1: Create silver_data dataset
echo "[1/5] Creating silver_data dataset..."
bq query --project_id="${PROJECT_ID}" --use_legacy_sql=false < "${SCRIPT_DIR}/01_create_silver_dataset.sql"
echo "✅ Dataset created"
echo ""

# Step 2: Create silver_trips_enriched (taxi + TNP combined)
echo "[2/5] Creating silver_trips_enriched (taxi + TNP combined with spatial enrichment)..."
echo "⚠️  This may take 10-20 minutes due to 168M records and spatial joins..."
bq query --project_id="${PROJECT_ID}" --use_legacy_sql=false < "${SCRIPT_DIR}/02_silver_trips_enriched.sql"
echo "✅ silver_trips_enriched created"
echo ""

# Step 3: Create silver_permits_enriched
echo "[3/5] Creating silver_permits_enriched (building permits with spatial enrichment)..."
bq query --project_id="${PROJECT_ID}" --use_legacy_sql=false < "${SCRIPT_DIR}/03_silver_permits_enriched.sql"
echo "✅ silver_permits_enriched created"
echo ""

# Step 4: Create silver_covid_latest
echo "[4/5] Creating silver_covid_latest (latest week by ZIP with risk categories)..."
bq query --project_id="${PROJECT_ID}" --use_legacy_sql=false < "${SCRIPT_DIR}/04_silver_covid_latest.sql"
echo "✅ silver_covid_latest created"
echo ""

# Step 5: Create silver_ccvi_high_risk
echo "[5/5] Creating silver_ccvi_high_risk (high vulnerability areas only)..."
bq query --project_id="${PROJECT_ID}" --use_legacy_sql=false < "${SCRIPT_DIR}/05_silver_ccvi_high_risk.sql"
echo "✅ silver_ccvi_high_risk created"
echo ""

echo "============================================"
echo "All Silver Layer Tables Created Successfully!"
echo "============================================"
echo ""
echo "Tables created:"
echo "  1. silver_trips_enriched (taxi + TNP with spatial enrichment)"
echo "  2. silver_permits_enriched (building permits with spatial enrichment)"
echo "  3. silver_covid_latest (latest week with risk categories)"
echo "  4. silver_ccvi_high_risk (high vulnerability areas)"
echo ""
echo "Verify tables:"
echo "  bq ls --project_id=${PROJECT_ID} silver_data"
echo ""
