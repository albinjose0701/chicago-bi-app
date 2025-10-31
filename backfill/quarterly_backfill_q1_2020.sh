#!/bin/bash
#
# Chicago BI App - Quarterly Backfill Script
# Q1 2020 (January 1 - March 31, 2020)
#
# This script runs historical data ingestion for an entire quarter.
# Daily partitions: 90 partitions (Jan 1 - Mar 31, 2020)
#
# Usage:
#   ./quarterly_backfill_q1_2020.sh [dataset]
#
# Arguments:
#   dataset: taxi, tnp, covid, permits, or "all" (default: all)
#
# Examples:
#   ./quarterly_backfill_q1_2020.sh taxi       # Only taxi trips
#   ./quarterly_backfill_q1_2020.sh all        # All datasets
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
START_DATE="2020-01-01"
END_DATE="2020-03-31"
DATASET="${1:-all}"

# Delay between job executions (to avoid rate limits)
DELAY_SECONDS=30

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Chicago BI App - Q1 2020 Quarterly Backfill${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Quarter: ${GREEN}Q1 2020 (Jan 1 - Mar 31)${NC}"
echo -e "Partitions: ${GREEN}90 daily partitions${NC}"
echo -e "Dataset: ${GREEN}${DATASET}${NC}"
echo -e "Project: ${GREEN}${PROJECT_ID}${NC}"
echo ""

print_section() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Generate array of all dates in Q1 2020
generate_date_range() {
    local start_date=$1
    local end_date=$2
    local current_date=$start_date
    local dates=()

    while [[ "$current_date" < "$end_date" ]] || [[ "$current_date" == "$end_date" ]]; do
        dates+=("$current_date")
        # Increment date by 1 day (macOS/Linux compatible)
        current_date=$(date -j -v+1d -f "%Y-%m-%d" "$current_date" "+%Y-%m-%d" 2>/dev/null || date -d "$current_date + 1 day" "+%Y-%m-%d")
    done

    echo "${dates[@]}"
}

# Execute Cloud Run job for a specific date and dataset
run_extraction() {
    local dataset_name=$1
    local extraction_date=$2
    local job_name="extractor-${dataset_name}"

    print_info "Running ${dataset_name} extraction for ${extraction_date}..."

    # Execute Cloud Run job with environment variables
    if gcloud run jobs execute "${job_name}" \
        --region="${REGION}" \
        --project="${PROJECT_ID}" \
        --update-env-vars="MODE=full,START_DATE=${extraction_date},END_DATE=${extraction_date}" \
        --wait 2>&1 | tee -a backfill_log.txt; then
        print_success "Completed ${dataset_name} for ${extraction_date}"
        return 0
    else
        print_error "Failed ${dataset_name} for ${extraction_date}"
        return 1
    fi
}

# Main backfill logic
run_quarterly_backfill() {
    local dataset_type=$1

    print_section "Generating Date Range for Q1 2020"

    # Generate all dates in Q1 2020
    dates_array=($(generate_date_range "$START_DATE" "$END_DATE"))
    total_dates=${#dates_array[@]}

    print_success "Generated ${total_dates} dates from ${START_DATE} to ${END_DATE}"

    # Create log file
    log_file="backfill_q1_2020_${dataset_type}_$(date +%Y%m%d_%H%M%S).log"
    echo "Quarterly Backfill Log - Q1 2020" > "$log_file"
    echo "Dataset: ${dataset_type}" >> "$log_file"
    echo "Start Time: $(date)" >> "$log_file"
    echo "---" >> "$log_file"

    # Determine which datasets to process
    datasets_to_process=()
    if [[ "$dataset_type" == "all" ]]; then
        datasets_to_process=("taxi" "tnp")  # Add "covid" "permits" when ready
    else
        datasets_to_process=("$dataset_type")
    fi

    # Counter for progress tracking
    completed=0
    failed=0

    print_section "Starting Backfill Process"

    for dataset in "${datasets_to_process[@]}"; do
        print_info "Processing dataset: ${dataset}"

        for i in "${!dates_array[@]}"; do
            date="${dates_array[$i]}"
            progress=$((i + 1))

            echo ""
            print_info "Progress: ${progress}/${total_dates} (${dataset})"

            if run_extraction "$dataset" "$date"; then
                ((completed++))
                echo "✅ ${dataset} ${date} SUCCESS" >> "$log_file"
            else
                ((failed++))
                echo "❌ ${dataset} ${date} FAILED" >> "$log_file"
            fi

            # Delay between executions to avoid rate limits
            if [[ $progress -lt $total_dates ]]; then
                print_info "Waiting ${DELAY_SECONDS} seconds before next extraction..."
                sleep "$DELAY_SECONDS"
            fi
        done
    done

    # Summary
    print_section "Backfill Summary"

    echo "End Time: $(date)" >> "$log_file"
    echo "---" >> "$log_file"
    echo "Completed: ${completed}" >> "$log_file"
    echo "Failed: ${failed}" >> "$log_file"

    echo -e "Total Executions: ${GREEN}$((completed + failed))${NC}"
    echo -e "Successful: ${GREEN}${completed}${NC}"
    echo -e "Failed: ${RED}${failed}${NC}"
    echo -e "Log File: ${BLUE}${log_file}${NC}"

    if [[ $failed -eq 0 ]]; then
        print_success "Quarterly backfill completed successfully!"
        return 0
    else
        print_error "Quarterly backfill completed with ${failed} failures. Check log: ${log_file}"
        return 1
    fi
}

# Pre-flight checks
print_section "Pre-Flight Checks"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI not found. Please install Google Cloud SDK."
    exit 1
fi
print_success "gcloud CLI found"

# Check if authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    print_error "Not authenticated. Run: gcloud auth login"
    exit 1
fi
print_success "Authenticated to GCP"

# Check if project exists
if ! gcloud projects describe "$PROJECT_ID" &> /dev/null; then
    print_error "Project ${PROJECT_ID} not found"
    exit 1
fi
print_success "Project ${PROJECT_ID} exists"

# Validate dataset argument
if [[ "$DATASET" != "taxi" && "$DATASET" != "tnp" && "$DATASET" != "covid" && "$DATASET" != "permits" && "$DATASET" != "all" ]]; then
    print_error "Invalid dataset: ${DATASET}"
    echo "Valid options: taxi, tnp, covid, permits, all"
    exit 1
fi
print_success "Dataset validation passed"

# Confirmation prompt
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will execute Cloud Run jobs for 90 days of data.${NC}"
echo -e "${YELLOW}   Estimated cost: ~\$1.50 (one-time)${NC}"
echo -e "${YELLOW}   Estimated time: ~${DELAY_SECONDS}s × 90 = $(( DELAY_SECONDS * 90 / 60 )) minutes per dataset${NC}"
echo ""
read -p "Continue with quarterly backfill? (yes/no): " confirmation

if [[ "$confirmation" != "yes" ]]; then
    print_info "Backfill cancelled by user"
    exit 0
fi

# Run the backfill
run_quarterly_backfill "$DATASET"

print_section "Next Steps"

echo "1. Verify data in BigQuery:"
echo "   bq query --use_legacy_sql=false \"SELECT DATE(trip_start_timestamp) AS date, COUNT(*) as trips FROM \\\`chicago-bi.raw_data.raw_taxi_trips\\\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31' GROUP BY date ORDER BY date\""
echo ""
echo "2. Check partition count:"
echo "   bq query --use_legacy_sql=false \"SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as partition_count FROM \\\`chicago-bi.raw_data.raw_taxi_trips\\\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'\""
echo ""
echo "3. Process to gold layer:"
echo "   ./process_to_gold.sh 2020-Q1"
echo ""
echo "4. Archive after analysis:"
echo "   ./archive_quarter.sh 2020-Q1"
echo ""

print_success "Quarterly backfill script completed!"
