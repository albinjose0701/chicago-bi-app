#!/bin/bash
#
# Resilient Q2 2020 Quarterly Backfill with Network Failure Recovery
# This script handles internet interruptions and automatically resumes
# Processes both Taxi and TNP datasets
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
START_DATE="2020-04-01"
END_DATE="2020-06-30"
DATASET="${1:-all}"

# Delays
DELAY_SECONDS=30
NETWORK_RETRY_DELAY=120  # 2 minutes for network failures
MAX_NETWORK_RETRIES=10   # Try for 20 minutes before giving up
MAX_EXTRACTION_RETRIES=3

# Create log file with timestamp
LOG_FILE="backfill_q2_2020_resilient_$(date +%Y%m%d_%H%M%S).log"
PROGRESS_FILE="q2_progress.txt"

# Redirect all output to log file AND console
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Resilient Q2 2020 Quarterly Backfill${NC}"
echo -e "${BLUE}With Network Failure Recovery${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Quarter: ${GREEN}Q2 2020 (Apr 1 - Jun 30)${NC}"
echo -e "Date Range: ${GREEN}${START_DATE} to ${END_DATE}${NC}"
echo -e "Datasets: ${GREEN}${DATASET}${NC}"
echo -e "Project: ${GREEN}${PROJECT_ID}${NC}"
echo -e "Log File: ${GREEN}${LOG_FILE}${NC}"
echo -e "Progress File: ${GREEN}${PROGRESS_FILE}${NC}"
echo ""
echo -e "${YELLOW}This script is resilient to network interruptions${NC}"
echo -e "${YELLOW}It will automatically retry when internet comes back${NC}"
echo -e "${YELLOW}It will skip dates that are already completed${NC}"
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
    local dataset_name=$1
    local extraction_date=$2
    local table_name="raw_${dataset_name}_trips"
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
                print_info "Date ${extraction_date} (${dataset_name}) already has ${row_count} rows - SKIPPING"
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
    local dataset_name=$1
    local extraction_date=$2
    local table_name="raw_${dataset_name}_trips"
    local max_retries=5
    local retry=0

    print_info "Verifying data in BigQuery for ${dataset_name} ${extraction_date}..."

    while [[ $retry -lt $max_retries ]]; do
        local row_count=$(bq query --use_legacy_sql=false --format=csv --project_id="${PROJECT_ID}" \
            "SELECT COUNT(*) as count
             FROM \`${PROJECT_ID}.raw_data.${table_name}\`
             WHERE DATE(trip_start_timestamp) = '${extraction_date}'" 2>/dev/null | tail -n1)

        if [[ $? -eq 0 ]]; then
            if [[ -z "$row_count" ]] || [[ "$row_count" == "0" ]] || [[ "$row_count" == "count" ]]; then
                print_error "No rows found in BigQuery for ${dataset_name} ${extraction_date}"
                return 1
            fi

            print_success "Verified ${row_count} rows in BigQuery for ${dataset_name} ${extraction_date}"

            # Save to progress file
            echo "${dataset_name},${extraction_date},${row_count},$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$PROGRESS_FILE"

            echo "$row_count"
            return 0
        else
            # Query failed
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
    local dataset_name=$1
    local extraction_date=$2
    local job_name="extractor-${dataset_name}"
    local max_retries=$MAX_EXTRACTION_RETRIES
    local retry=0

    print_info "Running ${dataset_name} extraction for ${extraction_date}..."

    while [[ $retry -lt $max_retries ]]; do
        # Check network before attempting
        if ! check_network; then
            wait_for_network
        fi

        # Execute Cloud Run job
        local execution_output
        execution_output=$(gcloud run jobs execute "${job_name}" \
            --region="${REGION}" \
            --project="${PROJECT_ID}" \
            --update-env-vars="MODE=full,START_DATE=${extraction_date},END_DATE=${extraction_date}" \
            --wait 2>&1)

        local exit_code=$?

        # Check if execution succeeded
        if [[ $exit_code -eq 0 ]]; then
            print_success "Cloud Run job completed for ${dataset_name} ${extraction_date}"

            # Wait for BigQuery loading to complete
            sleep 10

            # Verify data in BigQuery
            local row_count
            if row_count=$(verify_bigquery_data "$dataset_name" "$extraction_date"); then
                print_success "Extraction and verification complete: ${row_count} rows"
                return 0
            else
                print_error "Data verification failed for ${dataset_name} ${extraction_date}"
                retry=$((retry + 1))
            fi
        else
            # Execution failed
            print_error "Cloud Run execution failed for ${dataset_name} ${extraction_date}"
            echo "$execution_output" | tail -n 10
            retry=$((retry + 1))

            if [[ $retry -lt $max_retries ]]; then
                print_info "Retry attempt ${retry}/${max_retries} in 60 seconds..."
                sleep 60
            fi
        fi
    done

    print_error "Failed ${dataset_name} ${extraction_date} after ${max_retries} attempts"
    return 1
}

# Main backfill logic
run_backfill() {
    print_info "Generating date range for Q2 2020..."

    # Generate all dates in Q2 2020
    dates_array=($(generate_date_range "$START_DATE" "$END_DATE"))
    total_dates=${#dates_array[@]}

    print_success "Generated ${total_dates} dates from ${START_DATE} to ${END_DATE}"

    # Determine which datasets to process
    datasets_to_process=()
    if [[ "$DATASET" == "all" ]]; then
        datasets_to_process=("taxi" "tnp")
    else
        datasets_to_process=("$DATASET")
    fi

    print_info "Will process datasets: ${datasets_to_process[*]}"

    # Counter for progress tracking
    completed=0
    skipped=0
    failed=0

    echo ""
    print_info "Starting backfill process..."
    echo ""

    for dataset in "${datasets_to_process[@]}"; do
        print_success "Processing dataset: ${dataset}"
        echo ""

        local current_index=0
        for date in "${dates_array[@]}"; do
            current_index=$((current_index + 1))
            print_info "Progress: ${current_index}/${total_dates} - ${dataset} ${date}"

            # Check if date already exists (with network resilience)
            if check_date_exists "$dataset" "$date"; then
                ((skipped++))
                echo ""
                continue
            fi

            # Run extraction with retry logic
            if run_extraction "$dataset" "$date"; then
                ((completed++))
                echo "✅ ${dataset} ${date} SUCCESS" >> "${LOG_FILE}.summary"
            else
                ((failed++))
                echo "❌ ${dataset} ${date} FAILED" >> "${LOG_FILE}.summary"
            fi

            # Delay between executions (skip on last date)
            if [[ $current_index -lt $total_dates ]]; then
                print_info "Waiting ${DELAY_SECONDS} seconds before next extraction..."
                sleep "$DELAY_SECONDS"
            fi

            echo ""
        done

        echo ""
        print_success "Completed processing ${dataset} dataset"
        echo ""
    done

    # Summary
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}Backfill Summary${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo -e "Completed: ${GREEN}${completed}${NC}"
    echo -e "Skipped (already existed): ${YELLOW}${skipped}${NC}"
    echo -e "Failed: ${RED}${failed}${NC}"
    echo -e "Log File: ${BLUE}${LOG_FILE}${NC}"
    echo -e "Progress File: ${BLUE}${PROGRESS_FILE}${NC}"
    echo ""

    if [[ $failed -eq 0 ]]; then
        print_success "Q2 2020 backfill completed successfully!"
        return 0
    else
        print_error "Q2 2020 backfill completed with ${failed} failures"
        return 1
    fi
}

# Validate arguments
if [[ "$DATASET" != "taxi" && "$DATASET" != "tnp" && "$DATASET" != "all" ]]; then
    print_error "Invalid dataset: ${DATASET}"
    echo "Valid options: taxi, tnp, all"
    exit 1
fi

# Create progress file with header if it doesn't exist
if [[ ! -f "$PROGRESS_FILE" ]]; then
    echo "dataset,date,rows,timestamp" > "$PROGRESS_FILE"
fi

# Run the backfill
run_backfill

exit $?
