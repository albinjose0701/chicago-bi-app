#!/bin/bash
#
# Quarterly Backfill Script - Q3 2024 (Jul 1 - Sep 30)
# TAXI ONLY - TNP data not available for 2024+
# NEW DATASET: ajtu-isnz (different from 2020-2023)
# ULTRA-OPTIMIZED: 2s delays between extractions
#
# This script extracts taxi trip data for Q3 2024 (92 days)
# using Cloud Run Jobs with network resilience and BigQuery verification.
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
PROJECT_ID="chicago-bi-app-msds-432-476520"
REGION="us-central1"
JOB_NAME="extractor-taxi"
START_DATE="2024-07-01"
END_DATE="2024-09-30"
DELAY_SECONDS=2

# Logging
LOG_FILE="backfill_q3_2024_taxi_only_$(date +%Y%m%d_%H%M%S).log"
PROGRESS_FILE="q3_2024_taxi_progress.txt"

# Redirect output to log file
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Q3 2024 TAXI BACKFILL (Jul 1 - Sep 30)${NC}"
echo -e "${BLUE}  NEW DATASET: ajtu-isnz${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""
echo -e "Configuration:"
echo -e "  • Period: ${GREEN}2024-07-01 to 2024-09-30${NC}"
echo -e "  • Days: ${GREEN}92 days${NC}"
echo -e "  • Dataset: ${GREEN}Taxi Only${NC}"
echo -e "  • Delay: ${YELLOW}2 seconds${NC}"
echo -e "  • Project: ${PROJECT_ID}"
echo -e "  • Region: ${REGION}"
echo ""
echo -e "Logging:"
echo -e "  • Log file: ${LOG_FILE}"
echo -e "  • Progress: ${PROGRESS_FILE}"
echo ""

# Initialize progress file
echo "date,taxi_rows,timestamp" > "$PROGRESS_FILE"

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

wait_for_network() {
    while ! ping -c 1 -W 5 8.8.8.8 &> /dev/null; do
        print_error "Network unavailable. Waiting 30 seconds..."
        sleep 30
    done
}

# Function to get next date
get_next_date() {
    local current_date=$1
    date -j -v+1d -f "%Y-%m-%d" "$current_date" +"%Y-%m-%d" 2>/dev/null || \
    date -d "$current_date + 1 day" +"%Y-%m-%d" 2>/dev/null
}

# Function to check if date exists in BigQuery
check_date_in_bigquery() {
    local check_date=$1
    local count=$(bq query --use_legacy_sql=false --format=csv \
        "SELECT COUNT(*) as cnt FROM \`${PROJECT_ID}.raw_data.raw_taxi_trips\`
         WHERE DATE(trip_start_timestamp) = '${check_date}'" 2>/dev/null | tail -1)
    echo "$count"
}

# Main extraction loop
CURRENT_DATE="$START_DATE"
TOTAL_DATES=0
SUCCESSFUL=0
SKIPPED=0
FAILED=0

echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STARTING EXTRACTIONS${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""

while [[ "$CURRENT_DATE" < "$END_DATE" ]] || [[ "$CURRENT_DATE" == "$END_DATE" ]]; do
    TOTAL_DATES=$((TOTAL_DATES + 1))

    echo -e "${BLUE}──────────────────────────────────────────────${NC}"
    echo -e "${BLUE}Date: ${CURRENT_DATE} (${TOTAL_DATES}/92)${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────${NC}"

    # Check if date already exists in BigQuery
    print_info "Checking if ${CURRENT_DATE} already exists in BigQuery..."
    EXISTING_COUNT=$(check_date_in_bigquery "$CURRENT_DATE")

    if [[ "$EXISTING_COUNT" -gt 0 ]]; then
        print_success "${CURRENT_DATE} already exists with ${EXISTING_COUNT} trips - SKIPPING"
        echo "${CURRENT_DATE},${EXISTING_COUNT},$(date -u +"%Y-%m-%dT%H:%M:%SZ") [SKIPPED]" >> "$PROGRESS_FILE"
        SKIPPED=$((SKIPPED + 1))
        CURRENT_DATE=$(get_next_date "$CURRENT_DATE")
        sleep 1
        continue
    fi

    # Ensure network is available
    wait_for_network

    # Execute Cloud Run Job
    print_info "Executing extraction for ${CURRENT_DATE}..."

    if gcloud run jobs execute "$JOB_NAME" \
        --region="$REGION" \
        --update-env-vars="START_DATE=${CURRENT_DATE},DATASET=taxi" \
        --wait 2>&1; then

        # Wait a moment for BigQuery to be consistent
        sleep 3

        # Verify in BigQuery
        TRIP_COUNT=$(check_date_in_bigquery "$CURRENT_DATE")

        if [[ "$TRIP_COUNT" -gt 0 ]]; then
            print_success "${CURRENT_DATE} completed: ${TRIP_COUNT} trips loaded"
            echo "${CURRENT_DATE},${TRIP_COUNT},$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$PROGRESS_FILE"
            SUCCESSFUL=$((SUCCESSFUL + 1))
        else
            print_error "${CURRENT_DATE} FAILED: No data in BigQuery after extraction"
            echo "${CURRENT_DATE},0,$(date -u +"%Y-%m-%dT%H:%M:%SZ") [FAILED]" >> "$PROGRESS_FILE"
            FAILED=$((FAILED + 1))
        fi
    else
        print_error "${CURRENT_DATE} FAILED: Cloud Run execution failed"
        echo "${CURRENT_DATE},0,$(date -u +"%Y-%m-%dT%H:%M:%SZ") [FAILED]" >> "$PROGRESS_FILE"
        FAILED=$((FAILED + 1))
    fi

    # Move to next date
    CURRENT_DATE=$(get_next_date "$CURRENT_DATE")

    # Delay between extractions (except for last one)
    if [[ "$CURRENT_DATE" < "$END_DATE" ]] || [[ "$CURRENT_DATE" == "$END_DATE" ]]; then
        sleep "$DELAY_SECONDS"
    fi
done

# Summary
echo ""
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Q3 2024 BACKFILL COMPLETE${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""
echo -e "Summary:"
echo -e "  • Total dates: ${TOTAL_DATES}"
echo -e "  • Successful: ${GREEN}${SUCCESSFUL}${NC}"
echo -e "  • Skipped: ${YELLOW}${SKIPPED}${NC}"
echo -e "  • Failed: ${RED}${FAILED}${NC}"
echo ""
echo -e "Files:"
echo -e "  • Log: ${LOG_FILE}"
echo -e "  • Progress: ${PROGRESS_FILE}"
echo ""

if [[ $FAILED -eq 0 ]]; then
    print_success "🎉 Q3 2024 backfill completed successfully!"
    exit 0
else
    print_error "⚠️  Q3 2024 backfill completed with ${FAILED} failures"
    exit 1
fi
