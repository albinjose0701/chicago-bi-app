#!/bin/bash
#
# Resilient TNP Backfill with Network Failure Recovery
# This script handles internet interruptions and automatically resumes
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
START_DATE="2020-01-10"
END_DATE="2020-03-31"
DATASET="tnp"

# Delays
DELAY_SECONDS=30
NETWORK_RETRY_DELAY=120  # 2 minutes for network failures
MAX_NETWORK_RETRIES=10   # Try for 20 minutes before giving up
MAX_EXTRACTION_RETRIES=3

# Create log file with timestamp
LOG_FILE="resume_tnp_resilient_$(date +%Y%m%d_%H%M%S).log"
PROGRESS_FILE="tnp_progress.txt"

# Redirect all output to log file AND console
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Resilient TNP Backfill with Network Recovery${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Date Range: ${GREEN}${START_DATE} to ${END_DATE}${NC}"
echo -e "Dataset: ${GREEN}${DATASET}${NC}"
echo -e "Project: ${GREEN}${PROJECT_ID}${NC}"
echo -e "Log File: ${GREEN}${LOG_FILE}${NC}"
echo -e "Progress File: ${GREEN}${PROGRESS_FILE}${NC}"
echo ""
echo -e "${YELLOW}This script is resilient to network interruptions${NC}"
echo -e "${YELLOW}It will automatically retry when internet comes back${NC}"
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

# Check if internet is available
check_network() {
    if ping -c 1 -W 5 8.8.8.8 &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Wait for network to come back
wait_for_network() {
    local attempt=1
    print_error "Network appears to be down. Waiting for connection..."

    while ! check_network; do
        echo -ne "\r${YELLOW}Network check attempt ${attempt}... (will keep trying)${NC}"
        sleep 10
        attempt=$((attempt + 1))
    done

    echo ""
    print_success "Network is back online!"
    sleep 5  # Give it a moment to stabilize
}

# Check if date already has data in BigQuery
check_date_exists() {
    local extraction_date=$1
    local table_name="raw_tnp_trips"
    local max_retries=5
    local retry=0

    while [[ $retry -lt $max_retries ]]; do
        # Try to query BigQuery
        local row_count=$(bq query --use_legacy_sql=false --format=csv --project_id="${PROJECT_ID}" \
            "SELECT COUNT(*) as count
             FROM \`${PROJECT_ID}.raw_data.${table_name}\`
             WHERE DATE(trip_start_timestamp) = '${extraction_date}'" 2>/dev/null | tail -n1)

        if [[ $? -eq 0 ]]; then
            # Query succeeded
            if [[ -n "$row_count" ]] && [[ "$row_count" != "0" ]] && [[ "$row_count" != "count" ]]; then
                print_info "Date ${extraction_date} already has ${row_count} rows - SKIPPING"
                return 0  # Date exists, skip it
            else
                return 1  # Date doesn't exist, process it
            fi
        else
            # Query failed, might be network issue
            retry=$((retry + 1))
            if [[ $retry -lt $max_retries ]]; then
                print_error "BigQuery query failed (attempt ${retry}/${max_retries}), retrying..."
                wait_for_network
                sleep 5
            fi
        fi
    done

    print_error "Could not verify if date exists after ${max_retries} attempts"
    return 1  # Process it to be safe
}

# Verify data in BigQuery
verify_bigquery_data() {
    local extraction_date=$1
    local table_name="raw_tnp_trips"
    local max_retries=5
    local retry=0

    print_info "Verifying data in BigQuery for ${extraction_date}..."

    while [[ $retry -lt $max_retries ]]; do
        local row_count=$(bq query --use_legacy_sql=false --format=csv --project_id="${PROJECT_ID}" \
            "SELECT COUNT(*) as count
             FROM \`${PROJECT_ID}.raw_data.${table_name}\`
             WHERE DATE(trip_start_timestamp) = '${extraction_date}'" 2>/dev/null | tail -n1)

        if [[ $? -eq 0 ]]; then
            if [[ -z "$row_count" ]] || [[ "$row_count" == "0" ]] || [[ "$row_count" == "count" ]]; then
                print_error "No rows found in BigQuery for ${extraction_date}"
                return 1
            fi

            print_success "Verified ${row_count} rows in BigQuery for ${extraction_date}"

            # Save to progress file
            echo "${extraction_date},${row_count},$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$PROGRESS_FILE"

            return 0
        else
            retry=$((retry + 1))
            if [[ $retry -lt $max_retries ]]; then
                print_error "Verification query failed (attempt ${retry}/${max_retries}), retrying..."
                wait_for_network
                sleep 5
            fi
        fi
    done

    print_error "Verification failed after ${max_retries} attempts"
    return 1
}

# Run extraction with network resilience
run_extraction() {
    local extraction_date=$1
    local job_name="extractor-tnp"
    local network_retry=0

    print_info "Running TNP extraction for ${extraction_date}..."

    while [[ $network_retry -lt $MAX_NETWORK_RETRIES ]]; do
        # Check network first
        if ! check_network; then
            wait_for_network
        fi

        # Execute Cloud Run job
        if gcloud run jobs execute "${job_name}" \
            --region="${REGION}" \
            --project="${PROJECT_ID}" \
            --update-env-vars="START_DATE=${extraction_date}" \
            --wait 2>&1 | tee -a extraction_output.tmp; then

            print_success "Cloud Run job completed for ${extraction_date}"

            # Wait for BigQuery load
            sleep 15

            # Verify with retries
            if verify_bigquery_data "${extraction_date}"; then
                return 0
            else
                print_error "Verification failed, will retry extraction"
                return 1
            fi
        else
            # Execution failed
            network_retry=$((network_retry + 1))

            if [[ $network_retry -lt $MAX_NETWORK_RETRIES ]]; then
                print_error "Cloud Run execution failed (network attempt ${network_retry}/${MAX_NETWORK_RETRIES})"
                print_info "Waiting for network to stabilize..."
                wait_for_network
                sleep 30
            else
                print_error "Cloud Run execution failed after ${MAX_NETWORK_RETRIES} network retries"
                return 1
            fi
        fi
    done

    return 1
}

# Run extraction with multiple retries
run_extraction_with_retry() {
    local extraction_date=$1
    local attempt=1

    # First check if this date already has data
    if check_date_exists "${extraction_date}"; then
        return 0  # Already done, skip
    fi

    while [[ $attempt -le $MAX_EXTRACTION_RETRIES ]]; do
        print_info "Extraction attempt ${attempt}/${MAX_EXTRACTION_RETRIES} for ${extraction_date}"

        if run_extraction "${extraction_date}"; then
            print_success "Successfully extracted ${extraction_date}"
            return 0
        fi

        if [[ $attempt -lt $MAX_EXTRACTION_RETRIES ]]; then
            print_error "Attempt ${attempt} failed for ${extraction_date}, retrying..."
            sleep 60
            wait_for_network  # Make sure network is up
        fi

        attempt=$((attempt + 1))
    done

    print_error "Failed after ${MAX_EXTRACTION_RETRIES} extraction attempts for ${extraction_date}"
    return 1
}

# Generate date range
generate_date_range() {
    local start_date=$1
    local end_date=$2
    local current_date=$start_date
    local dates=()

    while [[ "$current_date" < "$end_date" ]] || [[ "$current_date" == "$end_date" ]]; do
        dates+=("$current_date")
        current_date=$(date -j -v+1d -f "%Y-%m-%d" "$current_date" "+%Y-%m-%d" 2>/dev/null || date -d "$current_date + 1 day" "+%Y-%m-%d")
    done

    echo "${dates[@]}"
}

# Initial network check
print_info "Checking network connectivity..."
if ! check_network; then
    wait_for_network
fi

print_success "Network is available, proceeding with backfill"
sleep 2

# Initialize progress file
echo "# TNP Backfill Progress - Started $(date)" > "$PROGRESS_FILE"
echo "# Format: date,row_count,timestamp" >> "$PROGRESS_FILE"

# Generate dates
print_info "Generating date range..."
DATES=($(generate_date_range "$START_DATE" "$END_DATE"))
TOTAL_DATES=${#DATES[@]}

echo ""
print_info "Will process ${TOTAL_DATES} dates for TNP dataset"
print_info "Estimated time: ~$((TOTAL_DATES * 5 / 60)) hours (at ~5 min per date)"
print_info "Script will automatically handle network interruptions"
echo ""
echo -e "${YELLOW}Starting in 10 seconds... (Ctrl+C to cancel)${NC}"
sleep 10

# Process each date
SUCCESS_COUNT=0
SKIPPED_COUNT=0
FAILED_DATES=()
START_TIME=$(date +%s)
CURRENT_INDEX=0

for date in "${DATES[@]}"; do
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    ELAPSED_HOURS=$((ELAPSED / 3600))
    ELAPSED_MINS=$(( (ELAPSED % 3600) / 60 ))

    print_info "Processing: TNP ${date}"
    print_info "Progress: ${SUCCESS_COUNT} completed, ${SKIPPED_COUNT} skipped, ${#FAILED_DATES[@]} failed of ${TOTAL_DATES} total"
    print_info "Elapsed time: ${ELAPSED_HOURS}h ${ELAPSED_MINS}m"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Check if already exists first
    if check_date_exists "${date}"; then
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        print_success "TNP ${date} SKIPPED (already exists)"
    elif run_extraction_with_retry "${date}"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        print_success "TNP ${date} SUCCESS"
    else
        FAILED_DATES+=("${date}")
        print_error "TNP ${date} FAILED after all retries"

        # Continue with next date instead of stopping
        print_info "Continuing with next date..."
    fi

    # Delay before next extraction (except for last one)
    CURRENT_INDEX=$((CURRENT_INDEX + 1))
    if [[ $CURRENT_INDEX -lt $TOTAL_DATES ]]; then
        print_info "Waiting ${DELAY_SECONDS} seconds before next extraction..."
        sleep $DELAY_SECONDS
    fi
done

# Calculate total time
END_TIME=$(date +%s)
TOTAL_ELAPSED=$((END_TIME - START_TIME))
TOTAL_HOURS=$((TOTAL_ELAPSED / 3600))
TOTAL_MINS=$(( (TOTAL_ELAPSED % 3600) / 60 ))

# Summary
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Backfill Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Total Dates: ${TOTAL_DATES}"
echo -e "Successful: ${GREEN}${SUCCESS_COUNT}${NC}"
echo -e "Skipped (already exists): ${YELLOW}${SKIPPED_COUNT}${NC}"
echo -e "Failed: ${RED}${#FAILED_DATES[@]}${NC}"
echo -e "Total Time: ${TOTAL_HOURS}h ${TOTAL_MINS}m"
echo ""

if [[ ${#FAILED_DATES[@]} -gt 0 ]]; then
    echo -e "${RED}Failed Dates:${NC}"
    for date in "${FAILED_DATES[@]}"; do
        echo "  - ${date}"
    done
    echo ""
    echo -e "${YELLOW}To retry failed dates, re-run this script or run manually:${NC}"
    echo "gcloud run jobs execute extractor-tnp --update-env-vars=\"START_DATE=YYYY-MM-DD\" --region=us-central1 --wait"
    echo ""

    # Calculate completion percentage
    COMPLETED=$((SUCCESS_COUNT + SKIPPED_COUNT))
    PERCENTAGE=$((COMPLETED * 100 / TOTAL_DATES))
    echo -e "Completion: ${PERCENTAGE}% (${COMPLETED}/${TOTAL_DATES})"
    exit 1
else
    print_success "All dates processed successfully!"
    echo ""
    echo -e "${GREEN}TNP Q1 2020 backfill is now COMPLETE!${NC}"
    echo ""
    echo "Verify final results:"
    echo "  bq query \"SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as dates, COUNT(*) as total_trips FROM \\\`${PROJECT_ID}.raw_data.raw_tnp_trips\\\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'\""
    exit 0
fi
