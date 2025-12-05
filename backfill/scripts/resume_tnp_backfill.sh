#!/bin/bash
#
# Resume TNP Backfill - Starting from 2020-01-10
# This script resumes the Q1 2020 backfill for TNP dataset only
#
# TNP already has data for: 2020-01-01 through 2020-01-09
# This script will process: 2020-01-10 through 2020-03-31 (81 dates)
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
START_DATE="2020-01-10"  # Resume from here
END_DATE="2020-03-31"
DATASET="tnp"

# Delay between job executions
DELAY_SECONDS=30

# Retry configuration
MAX_RETRIES=2
RETRY_DELAY=60

# Create log file
LOG_FILE="resume_tnp_backfill_$(date +%Y%m%d_%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Resume TNP Backfill - Starting from 2020-01-10${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Date Range: ${GREEN}${START_DATE} to ${END_DATE}${NC}"
echo -e "Dataset: ${GREEN}${DATASET}${NC}"
echo -e "Project: ${GREEN}${PROJECT_ID}${NC}"
echo -e "Log File: ${GREEN}${LOG_FILE}${NC}"
echo ""

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Generate date range
generate_date_range() {
    local start_date=$1
    local end_date=$2
    local current_date=$start_date
    local dates=()

    while [[ "$current_date" < "$end_date" ]] || [[ "$current_date" == "$end_date" ]]; do
        dates+=("$current_date")
        # Increment date by 1 day (macOS compatible)
        current_date=$(date -j -v+1d -f "%Y-%m-%d" "$current_date" "+%Y-%m-%d" 2>/dev/null || date -d "$current_date + 1 day" "+%Y-%m-%d")
    done

    echo "${dates[@]}"
}

# Verify data in BigQuery
verify_bigquery_data() {
    local extraction_date=$1
    local table_name="raw_tnp_trips"

    print_info "Verifying data in BigQuery for ${extraction_date}..."

    local row_count=$(bq query --use_legacy_sql=false --format=csv --project_id="${PROJECT_ID}" \
        "SELECT COUNT(*) as count
         FROM \`${PROJECT_ID}.raw_data.${table_name}\`
         WHERE DATE(trip_start_timestamp) = '${extraction_date}'" 2>/dev/null | tail -n1)

    if [[ -z "$row_count" ]] || [[ "$row_count" == "0" ]]; then
        print_error "No rows found in BigQuery for ${extraction_date}"
        return 1
    fi

    print_success "Verified ${row_count} rows in BigQuery for ${extraction_date}"
    echo "$row_count"
    return 0
}

# Run extraction for a single date
run_extraction() {
    local extraction_date=$1
    local job_name="extractor-tnp"

    print_info "Running TNP extraction for ${extraction_date}..."

    # Execute Cloud Run job
    gcloud run jobs execute "${job_name}" \
        --region="${REGION}" \
        --project="${PROJECT_ID}" \
        --update-env-vars="START_DATE=${extraction_date}" \
        --wait 2>&1 | tee -a extraction_output.tmp

    local exit_code=${PIPESTATUS[0]}

    if [[ $exit_code -ne 0 ]]; then
        print_error "Cloud Run execution failed for ${extraction_date}"
        return 1
    fi

    print_success "Cloud Run job completed for ${extraction_date}"

    # Wait a bit for BigQuery load to complete
    sleep 10

    # Verify data loaded
    if verify_bigquery_data "${extraction_date}" > /dev/null; then
        print_success "Extraction and verification complete for ${extraction_date}"
        return 0
    else
        print_error "Verification failed for ${extraction_date}"
        return 1
    fi
}

# Run extraction with retry
run_extraction_with_retry() {
    local extraction_date=$1
    local attempt=1

    while [[ $attempt -le $((MAX_RETRIES + 1)) ]]; do
        if run_extraction "${extraction_date}"; then
            return 0
        fi

        if [[ $attempt -le $MAX_RETRIES ]]; then
            print_info "Retry attempt ${attempt}/${MAX_RETRIES} for ${extraction_date}"
            sleep $RETRY_DELAY
        fi

        attempt=$((attempt + 1))
    done

    print_error "Failed after ${MAX_RETRIES} retries for ${extraction_date}"
    return 1
}

# Main execution
print_info "Generating date range..."
DATES=($(generate_date_range "$START_DATE" "$END_DATE"))
TOTAL_DATES=${#DATES[@]}

echo ""
print_info "Will process ${TOTAL_DATES} dates for TNP dataset"
print_info "Estimated time: ~$((TOTAL_DATES * 5 / 60)) hours (at ~5 min per date)"
echo ""

# Confirm before starting
read -p "Press Enter to start, or Ctrl+C to cancel..."

# Process each date
SUCCESS_COUNT=0
FAILED_DATES=()

for date in "${DATES[@]}"; do
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_info "Processing: TNP ${date} (${SUCCESS_COUNT}/$((SUCCESS_COUNT + ${#FAILED_DATES[@]}))/${TOTAL_DATES})"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if run_extraction_with_retry "${date}"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        print_success "TNP ${date} SUCCESS"
    else
        FAILED_DATES+=("${date}")
        print_error "TNP ${date} FAILED"
    fi

    # Delay before next extraction (except for last one)
    if [[ "$date" != "${DATES[-1]}" ]]; then
        print_info "Waiting ${DELAY_SECONDS} seconds before next extraction..."
        sleep $DELAY_SECONDS
    fi
done

# Summary
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Backfill Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Total Dates: ${TOTAL_DATES}"
echo -e "Successful: ${GREEN}${SUCCESS_COUNT}${NC}"
echo -e "Failed: ${RED}${#FAILED_DATES[@]}${NC}"
echo ""

if [[ ${#FAILED_DATES[@]} -gt 0 ]]; then
    echo -e "${RED}Failed Dates:${NC}"
    for date in "${FAILED_DATES[@]}"; do
        echo "  - ${date}"
    done
    echo ""
    echo -e "${YELLOW}To retry failed dates, you can run them manually:${NC}"
    echo "gcloud run jobs execute extractor-tnp --update-env-vars=\"START_DATE=YYYY-MM-DD\" --region=us-central1 --wait"
    exit 1
else
    print_success "All dates processed successfully!"
    echo ""
    echo -e "${GREEN}TNP Q1 2020 backfill is now COMPLETE!${NC}"
    echo ""
    echo "Verify final results:"
    echo "  bq query \"SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as dates FROM \\\`${PROJECT_ID}.raw_data.raw_tnp_trips\\\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'\""
    exit 0
fi
