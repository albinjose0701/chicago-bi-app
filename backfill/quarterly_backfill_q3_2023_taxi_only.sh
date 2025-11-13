#!/bin/bash
#
# Resilient Q3 2023 Quarterly Backfill - TAXI ONLY
# ULTRA-OPTIMIZED: 2s delays (12x faster than Q2 2020, 2.5x faster than 2022)
# TNP data not available for 2023+, processing taxi trips only
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
START_DATE="2023-07-01"
END_DATE="2023-09-30"

# Delays - ULTRA OPTIMIZED for fastest safe execution (TAXI ONLY)
DELAY_SECONDS=2  # ULTRA-Optimized: 2s delays (2.5x faster than 2022)
NETWORK_RETRY_DELAY=120
MAX_NETWORK_RETRIES=10
MAX_EXTRACTION_RETRIES=3

# Create log file with timestamp
LOG_FILE="backfill_q3_2023_taxi_only_$(date +%Y%m%d_%H%M%S).log"
PROGRESS_FILE="q3_2023_taxi_progress.txt"

# Redirect all output to log file AND console
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Resilient Q3 2023 Backfill - TAXI ONLY${NC}"
echo -e "${BLUE}ULTRA-OPTIMIZED (2s delays)${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Quarter: ${GREEN}Q3 2023 (Jul 1 - Sep 30)${NC}"
echo -e "Date Range: ${GREEN}${START_DATE} to ${END_DATE}${NC}"
echo -e "Dataset: ${GREEN}TAXI ONLY${NC} (TNP not available for 2023+)"
echo -e "Project: ${GREEN}${PROJECT_ID}${NC}"
echo -e "Delay: ${YELLOW}2 seconds (ULTRA-OPTIMIZED - 12x faster than Q2 2020)${NC}"
echo -e "Log File: ${GREEN}${LOG_FILE}${NC}"
echo -e "Progress File: ${GREEN}${PROGRESS_FILE}${NC}"
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
    sleep 5
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

# Check if date already has data in BigQuery
check_date_exists() {
    local extraction_date=$1
    local table_name="raw_taxi_trips"
    local max_retries=5
    local retry=0

    while [[ $retry -lt $max_retries ]]; do
        local row_count=$(bq query --use_legacy_sql=false --format=csv --project_id="${PROJECT_ID}" \
            "SELECT COUNT(*) as count
             FROM \`${PROJECT_ID}.raw_data.${table_name}\`
             WHERE DATE(trip_start_timestamp) = '${extraction_date}'" 2>/dev/null | tail -n1)

        if [[ $? -eq 0 ]]; then
            if [[ -n "$row_count" ]] && [[ "$row_count" != "0" ]] && [[ "$row_count" != "count" ]]; then
                print_info "Date ${extraction_date} (taxi) already has ${row_count} rows - SKIPPING"
                return 0
            else
                return 1
            fi
        else
            retry=$((retry + 1))
            if [[ $retry -lt $max_retries ]]; then
                print_error "BigQuery query failed (attempt ${retry}/${max_retries}), retrying..."
                wait_for_network
                sleep 5
            fi
        fi
    done

    print_error "Could not verify if date exists after ${max_retries} attempts"
    return 1
}

# Verify data in BigQuery
verify_bigquery_data() {
    local extraction_date=$1
    local table_name="raw_taxi_trips"
    local max_retries=5
    local retry=0

    print_info "Verifying data in BigQuery for taxi ${extraction_date}..."

    while [[ $retry -lt $max_retries ]]; do
        local row_count=$(bq query --use_legacy_sql=false --format=csv --project_id="${PROJECT_ID}" \
            "SELECT COUNT(*) as count
             FROM \`${PROJECT_ID}.raw_data.${table_name}\`
             WHERE DATE(trip_start_timestamp) = '${extraction_date}'" 2>/dev/null | tail -n1)

        if [[ $? -eq 0 ]]; then
            if [[ -z "$row_count" ]] || [[ "$row_count" == "0" ]] || [[ "$row_count" == "count" ]]; then
                print_error "No rows found in BigQuery for taxi ${extraction_date}"
                return 1
            fi

            print_success "Verified ${row_count} rows in BigQuery for taxi ${extraction_date}"
            echo "taxi,${extraction_date},${row_count},$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$PROGRESS_FILE"
            echo "$row_count"
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

    print_error "Could not verify data after ${max_retries} attempts"
    return 1
}

# Execute Cloud Run job with network resilience
run_extraction() {
    local extraction_date=$1
    local job_name="extractor-taxi"
    local max_retries=$MAX_EXTRACTION_RETRIES
    local retry=0

    print_info "Running taxi extraction for ${extraction_date}..."

    while [[ $retry -lt $max_retries ]]; do
        if ! check_network; then
            wait_for_network
        fi

        local execution_output
        execution_output=$(gcloud run jobs execute "${job_name}" \
            --region="${REGION}" \
            --project="${PROJECT_ID}" \
            --update-env-vars="MODE=full,START_DATE=${extraction_date},END_DATE=${extraction_date}" \
            --wait 2>&1)

        local exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            print_success "Cloud Run job completed for taxi ${extraction_date}"
            sleep 10

            local row_count
            if row_count=$(verify_bigquery_data "$extraction_date"); then
                print_success "Extraction and verification complete: ${row_count} rows"
                return 0
            else
                print_error "Data verification failed for taxi ${extraction_date}"
                retry=$((retry + 1))
            fi
        else
            print_error "Cloud Run execution failed for taxi ${extraction_date}"
            echo "$execution_output" | tail -n 10
            retry=$((retry + 1))

            if [[ $retry -lt $max_retries ]]; then
                print_info "Retry attempt ${retry}/${max_retries} in 60 seconds..."
                sleep 60
            fi
        fi
    done

    print_error "Failed taxi ${extraction_date} after ${max_retries} attempts"
    return 1
}

# Main backfill logic
run_backfill() {
    print_info "Generating date range for Q3 2023..."

    dates_array=($(generate_date_range "$START_DATE" "$END_DATE"))
    total_dates=${#dates_array[@]}

    print_success "Generated ${total_dates} dates from ${START_DATE} to ${END_DATE}"
    print_info "Processing TAXI ONLY (TNP not available for 2023+)"

    completed=0
    failed=0
    skipped=0
    current_index=0

    for date in "${dates_array[@]}"; do
        print_info "Processing ${date} (${current_index}/${total_dates})..."

        # Check if already exists
        if check_date_exists "$date"; then
            skipped=$((skipped + 1))
            current_index=$((current_index + 1))
            continue
        fi

        # Run extraction
        if run_extraction "$date"; then
            completed=$((completed + 1))
            print_success "✅ Taxi ${date} SUCCESS"
        else
            failed=$((failed + 1))
            print_error "❌ Taxi ${date} FAILED"
        fi

        current_index=$((current_index + 1))

        # Delay before next extraction (skip for last date)
        if [[ $current_index -lt $total_dates ]]; then
            print_info "Waiting ${DELAY_SECONDS} seconds before next extraction..."
            sleep $DELAY_SECONDS
        fi
    done

    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}Q3 2023 Taxi Backfill Summary${NC}"
    echo -e "${BLUE}================================================${NC}"
    print_success "Completed: ${completed}"
    print_error "Failed: ${failed}"
    print_info "Skipped (already exists): ${skipped}"
    print_success "Total dates processed: ${total_dates}"
    echo ""
}

# Pre-flight checks
print_info "Running pre-flight checks..."

if ! check_network; then
    print_error "No network connection detected"
    wait_for_network
fi

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    print_error "Not authenticated with GCP. Please run: gcloud auth login"
    exit 1
fi

print_success "Pre-flight checks passed"
echo ""

# Run the backfill
run_backfill

print_success "Q3 2023 Taxi Backfill Complete!"
echo -e "Log file: ${GREEN}${LOG_FILE}${NC}"
echo -e "Progress file: ${GREEN}${PROGRESS_FILE}${NC}"
