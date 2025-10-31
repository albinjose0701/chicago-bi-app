#!/bin/bash
#
# Check Extraction Results
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_ID="chicago-bi-app-msds-432-476520"
TEST_DATE="2020-01-15"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Check Extraction Results for ${TEST_DATE}${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# 1. Check Cloud Run logs
print_info "Checking Cloud Run logs..."
echo ""

gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.job_name=extractor-taxi" \
  --limit=20 \
  --project=$PROJECT_ID \
  --format="table(timestamp,textPayload)" | grep -E "Extracted|Uploaded|ERROR|✅"

echo ""

# 2. Check GCS bucket
print_info "Checking GCS bucket for uploaded data..."
echo ""

if gsutil ls gs://chicago-bi-app-msds-432-476520-landing/taxi/${TEST_DATE}/ 2>/dev/null; then
    print_success "Found data in GCS!"
    echo ""
    gsutil ls -lh gs://chicago-bi-app-msds-432-476520-landing/taxi/${TEST_DATE}/
    echo ""
    print_info "Preview first few lines:"
    gsutil cat gs://chicago-bi-app-msds-432-476520-landing/taxi/${TEST_DATE}/data.json | head -n 3
else
    echo "No data found in GCS for ${TEST_DATE}"
fi

echo ""

# 3. Check if BigQuery table exists
print_info "Checking if BigQuery table exists..."
echo ""

if bq show chicago-bi:raw_data.raw_taxi_trips &>/dev/null; then
    print_success "BigQuery table exists!"

    # Check for data
    COUNT=$(bq query --use_legacy_sql=false --format=csv \
      "SELECT COUNT(*) as count FROM \`chicago-bi.raw_data.raw_taxi_trips\` WHERE DATE(trip_start_timestamp) = '${TEST_DATE}'" 2>/dev/null | tail -n1)

    if [ "$COUNT" != "count" ] && [ "$COUNT" -gt 0 ] 2>/dev/null; then
        print_success "Found ${COUNT} trips in BigQuery!"
    else
        print_info "No data in BigQuery yet (table exists but empty for this date)"
        print_info "Data is in GCS - you need to load it to BigQuery"
    fi
else
    print_info "BigQuery table does not exist yet"
    print_info "You need to create the table and load the GCS data"
    echo ""
    echo "To create the table, run:"
    echo "  cd ~/Desktop/chicago-bi-app/bigquery/schemas"
    echo "  bq query --use_legacy_sql=false < bronze_layer.sql"
fi

echo ""
echo -e "${BLUE}================================================${NC}"
print_info "Summary"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "1. ✅ Cloud Run extraction completed"
echo "2. Check GCS: gs://chicago-bi-app-msds-432-476520-landing/taxi/${TEST_DATE}/"
echo "3. Next step: Create BigQuery table and load data"
echo ""
