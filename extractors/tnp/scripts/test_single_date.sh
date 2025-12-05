#!/bin/bash
#
# Test TNP Trips Extractor with a Known Good Date
# Uses 2020-01-15 (middle of Q1 2020, known to have data)
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_ID="chicago-bi-app-msds-432-476520"
REGION="us-central1"
JOB_NAME="extractor-tnp"
TEST_DATE="2020-01-15"  # Known good date with lots of data

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Test TNP Trips Extractor with Known Good Date${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

echo "Test Date: ${BLUE}${TEST_DATE}${NC}"
echo "Expected: 100,000-150,000 TNP trips (pre-COVID Wednesday)"
echo ""
print_info "Running extraction..."
echo ""

# Execute Cloud Run job
gcloud run jobs execute $JOB_NAME \
    --region=$REGION \
    --project=$PROJECT_ID \
    --update-env-vars="MODE=full,START_DATE=${TEST_DATE},END_DATE=${TEST_DATE}" \
    --wait

echo ""
print_success "Test execution completed!"
echo ""

# Check the results in BigQuery (if table exists)
print_info "Checking BigQuery for results..."

RESULT=$(bq query --use_legacy_sql=false --format=csv \
  "SELECT COUNT(*) as trip_count
   FROM \`chicago-bi.raw_data.raw_tnp_trips\`
   WHERE DATE(trip_start_timestamp) = '${TEST_DATE}'" 2>/dev/null | tail -n1)

if [ ! -z "$RESULT" ] && [ "$RESULT" != "trip_count" ]; then
    echo ""
    print_success "Found ${RESULT} trips in BigQuery for ${TEST_DATE}"

    if [ "$RESULT" -gt 0 ]; then
        print_success "Test PASSED - Data successfully extracted and loaded!"
    else
        print_info "No trips found - check Cloud Run logs for details"
    fi
else
    print_info "BigQuery table not ready yet, or still loading"
    print_info "Check Cloud Run logs for extraction details:"
    echo "  gcloud logging read \"resource.type=cloud_run_job AND resource.labels.job_name=${JOB_NAME}\" --limit=50"
fi

echo ""
echo -e "${BLUE}================================================${NC}"
