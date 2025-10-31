#!/bin/bash
#
# Chicago BI App - Monthly Backfill Script
#
# This script runs historical data ingestion for a specific month.
# Daily partitions: 28-31 partitions depending on the month
#
# Usage:
#   ./monthly_backfill.sh <YYYY-MM> [dataset]
#
# Arguments:
#   YYYY-MM: Year and month (e.g., 2020-01, 2020-02, 2020-03)
#   dataset: taxi, tnp, covid, permits, or "all" (default: all)
#
# Examples:
#   ./monthly_backfill.sh 2020-01 taxi       # January 2020 taxi trips only
#   ./monthly_backfill.sh 2020-02 all        # February 2020 all datasets
#   ./monthly_backfill.sh 2020-03            # March 2020 all datasets
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
YEAR_MONTH="${1:-}"
DATASET="${2:-all}"

# Delay between job executions (to avoid rate limits)
DELAY_SECONDS=30

# Validate arguments
if [[ -z "$YEAR_MONTH" ]]; then
    echo -e "${RED}Error: Missing required argument YYYY-MM${NC}"
    echo ""
    echo "Usage: $0 <YYYY-MM> [dataset]"
    echo ""
    echo "Examples:"
    echo "  $0 2020-01 taxi       # January 2020 taxi trips"
    echo "  $0 2020-02 all        # February 2020 all datasets"
    echo "  $0 2020-03            # March 2020 all datasets"
    exit 1
fi

# Parse year and month
YEAR=$(echo "$YEAR_MONTH" | cut -d'-' -f1)
MONTH=$(echo "$YEAR_MONTH" | cut -d'-' -f2)

# Validate year and month format
if ! [[ "$YEAR" =~ ^[0-9]{4}$ ]] || ! [[ "$MONTH" =~ ^(0[1-9]|1[0-2])$ ]]; then
    echo -e "${RED}Error: Invalid year-month format. Use YYYY-MM (e.g., 2020-01)${NC}"
    exit 1
fi

# Calculate start and end dates
START_DATE="${YEAR}-${MONTH}-01"

# Calculate last day of month (cross-platform compatible)
if date -v1d &> /dev/null; then
    # macOS
    END_DATE=$(date -j -v1d -v+1m -v-1d -f "%Y-%m-%d" "$START_DATE" "+%Y-%m-%d")
else
    # Linux
    END_DATE=$(date -d "$START_DATE + 1 month - 1 day" "+%Y-%m-%d")
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Chicago BI App - Monthly Backfill${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Month: ${GREEN}${YEAR_MONTH}${NC}"
echo -e "Date Range: ${GREEN}${START_DATE} to ${END_DATE}${NC}"
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

# Generate array of all dates in the month
generate_date_range() {
    local start_date=$1
    local end_date=$2
    local current_date=$start_date
    local dates=()

    while [[ "$current_date" < "$end_date" ]] || [[ "$current_date" == "$end_date" ]]; do
        dates+=("$current_date")
        # Increment date by 1 day (macOS/Linux compatible)
        if date -v1d &> /dev/null; then
            # macOS
            current_date=$(date -j -v+1d -f "%Y-%m-%d" "$current_date" "+%Y-%m-%d")
        else
            # Linux
            current_date=$(date -d "$current_date + 1 day" "+%Y-%m-%d")
        fi
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
run_monthly_backfill() {
    local dataset_type=$1

    print_section "Generating Date Range for ${YEAR_MONTH}"

    # Generate all dates in the month
    dates_array=($(generate_date_range "$START_DATE" "$END_DATE"))
    total_dates=${#dates_array[@]}

    print_success "Generated ${total_dates} dates from ${START_DATE} to ${END_DATE}"

    # Create log file
    log_file="backfill_${YEAR_MONTH}_${dataset_type}_$(date +%Y%m%d_%H%M%S).log"
    echo "Monthly Backfill Log - ${YEAR_MONTH}" > "$log_file"
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
        print_success "Monthly backfill completed successfully!"
        return 0
    else
        print_error "Monthly backfill completed with ${failed} failures. Check log: ${log_file}"
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
echo -e "${YELLOW}⚠️  WARNING: This will execute Cloud Run jobs for ${total_dates:-28-31} days of data.${NC}"
echo -e "${YELLOW}   Estimated cost: ~\$0.40-0.60 (one-time)${NC}"
echo -e "${YELLOW}   Estimated time: ~${DELAY_SECONDS}s × 30 = $(( DELAY_SECONDS * 30 / 60 )) minutes per dataset${NC}"
echo ""
read -p "Continue with monthly backfill for ${YEAR_MONTH}? (yes/no): " confirmation

if [[ "$confirmation" != "yes" ]]; then
    print_info "Backfill cancelled by user"
    exit 0
fi

# Run the backfill
run_monthly_backfill "$DATASET"

print_section "Next Steps"

echo "1. Verify data in BigQuery:"
echo "   bq query --use_legacy_sql=false \"SELECT DATE(trip_start_timestamp) AS date, COUNT(*) as trips FROM \\\`chicago-bi.raw_data.raw_taxi_trips\\\` WHERE DATE(trip_start_timestamp) BETWEEN '${START_DATE}' AND '${END_DATE}' GROUP BY date ORDER BY date\""
echo ""
echo "2. Check partition count:"
echo "   bq query --use_legacy_sql=false \"SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as partition_count FROM \\\`chicago-bi.raw_data.raw_taxi_trips\\\` WHERE DATE(trip_start_timestamp) BETWEEN '${START_DATE}' AND '${END_DATE}'\""
echo ""
echo "3. Process to gold layer:"
echo "   ./process_to_gold.sh ${YEAR_MONTH}"
echo ""
echo "4. Archive after analysis:"
echo "   ./archive_month.sh ${YEAR_MONTH}"
echo ""

print_success "Monthly backfill script completed!"
