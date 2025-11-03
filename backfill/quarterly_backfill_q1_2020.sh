#!/bin/bash
#
# Chicago BI App - Quarterly Backfill Script v2.1.0
# Q1 2020 (January 1 - March 31, 2020)
#
# This script runs historical data ingestion for an entire quarter
# with comprehensive error handling and data verification.
#
# NEW IN v2.1.0:
# - Data verification after each extraction
# - Automatic retry on failures
# - Detailed error reporting
# - BigQuery row count validation
#
# Usage:
#   ./quarterly_backfill_q1_2020.sh [dataset]
#
# Arguments:
#   dataset: taxi, tnp, or "all" (default: all)
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

# Retry configuration
MAX_RETRIES=2
RETRY_DELAY=60

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Chicago BI App - Q1 2020 Quarterly Backfill v2.1.0${NC}"
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

# Verify data was loaded to BigQuery
verify_bigquery_data() {
    local dataset_name=$1
    local extraction_date=$2
    local table_name="raw_${dataset_name}_trips"

    print_info "Verifying data in BigQuery for ${dataset_name} ${extraction_date}..."

    # Query BigQuery to check row count for this date
    local row_count=$(bq query --use_legacy_sql=false --format=csv \
        "SELECT COUNT(*) as count
         FROM \`${PROJECT_ID}.raw_data.${table_name}\`
         WHERE DATE(trip_start_timestamp) = '${extraction_date}'" \
        2>/dev/null | tail -n1)

    if [[ -z "$row_count" ]]; then
        print_error "Failed to query BigQuery for ${dataset_name} ${extraction_date}"
        return 1
    fi

    # Check if data exists
    if [[ "$row_count" -eq 0 ]]; then
        print_error "No rows found in BigQuery for ${dataset_name} ${extraction_date}"
        return 1
    fi

    print_success "Verified ${row_count} rows in BigQuery for ${dataset_name} ${extraction_date}"
    echo "$row_count"
    return 0
}

# Execute Cloud Run job for a specific date and dataset
run_extraction() {
    local dataset_name=$1
    local extraction_date=$2
    local job_name="extractor-${dataset_name}"

    print_info "Running ${dataset_name} extraction for ${extraction_date}..."

    # Execute Cloud Run job with environment variables
    local execution_output
    execution_output=$(gcloud run jobs execute "${job_name}" \
        --region="${REGION}" \
        --project="${PROJECT_ID}" \
        --update-env-vars="MODE=full,START_DATE=${extraction_date},END_DATE=${extraction_date}" \
        --wait 2>&1)

    local exit_code=$?

    # Check if execution succeeded
    if [[ $exit_code -ne 0 ]]; then
        print_error "Cloud Run execution failed for ${dataset_name} ${extraction_date}"
        echo "$execution_output" | tail -n 20
        return 1
    fi

    print_success "Cloud Run job completed for ${dataset_name} ${extraction_date}"

    # Wait a bit for BigQuery loading to complete
    sleep 10

    # Verify data in BigQuery
    local row_count
    if row_count=$(verify_bigquery_data "$dataset_name" "$extraction_date"); then
        print_success "Extraction and verification complete: ${row_count} rows"
        return 0
    else
        print_error "Data verification failed for ${dataset_name} ${extraction_date}"
        return 1
    fi
}

# Run extraction with retry logic
run_extraction_with_retry() {
    local dataset_name=$1
    local extraction_date=$2
    local attempt=1

    while [[ $attempt -le $((MAX_RETRIES + 1)) ]]; do
        if [[ $attempt -gt 1 ]]; then
            print_info "Retry attempt $((attempt - 1))/${MAX_RETRIES} for ${dataset_name} ${extraction_date}"
            sleep $RETRY_DELAY
        fi

        if run_extraction "$dataset_name" "$extraction_date"; then
            return 0
        fi

        ((attempt++))
    done

    print_error "Failed ${dataset_name} ${extraction_date} after $((MAX_RETRIES + 1)) attempts"
    return 1
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
    echo "Quarterly Backfill Log - Q1 2020 v2.1.0" > "$log_file"
    echo "Dataset: ${dataset_type}" >> "$log_file"
    echo "Start Time: $(date)" >> "$log_file"
    echo "---" >> "$log_file"

    # Determine which datasets to process
    datasets_to_process=()
    if [[ "$dataset_type" == "all" ]]; then
        datasets_to_process=("taxi" "tnp")
    else
        datasets_to_process=("$dataset_type")
    fi

    # Counter for progress tracking
    completed=0
    failed=0
    total_rows=0

    print_section "Starting Backfill Process"

    for dataset in "${datasets_to_process[@]}"; do
        print_info "Processing dataset: ${dataset}"

        for i in "${!dates_array[@]}"; do
            date="${dates_array[$i]}"
            progress=$((i + 1))

            echo ""
            print_info "Progress: ${progress}/${total_dates} (${dataset})"

            if row_count=$(run_extraction_with_retry "$dataset" "$date"); then
                ((completed++))
                ((total_rows += row_count))
                echo "✅ ${dataset} ${date} SUCCESS (${row_count} rows)" >> "$log_file"
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
    echo "Total Rows: ${total_rows}" >> "$log_file"

    echo -e "Total Executions: ${GREEN}$((completed + failed))${NC}"
    echo -e "Successful: ${GREEN}${completed}${NC}"
    echo -e "Failed: ${RED}${failed}${NC}"
    echo -e "Total Rows Loaded: ${GREEN}${total_rows}${NC}"
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

# Check if bq is installed
if ! command -v bq &> /dev/null; then
    print_error "bq CLI not found. Please install Google Cloud SDK with BigQuery component."
    exit 1
fi
print_success "bq CLI found"

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

# Set project
gcloud config set project "$PROJECT_ID" &> /dev/null
print_success "Project set to ${PROJECT_ID}"

# Validate dataset argument
if [[ "$DATASET" != "taxi" && "$DATASET" != "tnp" && "$DATASET" != "all" ]]; then
    print_error "Invalid dataset: ${DATASET}"
    echo "Valid options: taxi, tnp, all"
    exit 1
fi
print_success "Dataset validation passed"

# Check if Cloud Run jobs exist
if [[ "$DATASET" == "all" ]] || [[ "$DATASET" == "taxi" ]]; then
    if ! gcloud run jobs describe extractor-taxi --region="$REGION" &> /dev/null; then
        print_error "Cloud Run job 'extractor-taxi' not found"
        exit 1
    fi
    print_success "Cloud Run job 'extractor-taxi' found"
fi

if [[ "$DATASET" == "all" ]] || [[ "$DATASET" == "tnp" ]]; then
    if ! gcloud run jobs describe extractor-tnp --region="$REGION" &> /dev/null; then
        print_error "Cloud Run job 'extractor-tnp' not found"
        exit 1
    fi
    print_success "Cloud Run job 'extractor-tnp' found"
fi

# Check if BigQuery tables exist
if [[ "$DATASET" == "all" ]] || [[ "$DATASET" == "taxi" ]]; then
    if ! bq show "${PROJECT_ID}:raw_data.raw_taxi_trips" &> /dev/null; then
        print_error "BigQuery table 'raw_data.raw_taxi_trips' not found"
        exit 1
    fi
    print_success "BigQuery table 'raw_data.raw_taxi_trips' found"
fi

if [[ "$DATASET" == "all" ]] || [[ "$DATASET" == "tnp" ]]; then
    if ! bq show "${PROJECT_ID}:raw_data.raw_tnp_trips" &> /dev/null; then
        print_error "BigQuery table 'raw_data.raw_tnp_trips' not found"
        exit 1
    fi
    print_success "BigQuery table 'raw_data.raw_tnp_trips' found"
fi

# Confirmation prompt
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will execute Cloud Run jobs for 90 days of data.${NC}"
echo -e "${YELLOW}   Each extraction will be verified for data completeness.${NC}"
echo -e "${YELLOW}   Estimated cost: ~\$3-4 (one-time)${NC}"
echo -e "${YELLOW}   Estimated time: ~$(( (DELAY_SECONDS + 30) * 90 / 60 )) minutes per dataset${NC}"
echo ""
read -p "Continue with quarterly backfill? (yes/no): " confirmation

if [[ "$confirmation" != "yes" ]]; then
    print_info "Backfill cancelled by user"
    exit 0
fi

# Run the backfill
run_quarterly_backfill "$DATASET"

print_section "Next Steps"

echo "1. Verify data completeness in BigQuery:"
echo "   bq query --use_legacy_sql=false \"SELECT DATE(trip_start_timestamp) AS date, COUNT(*) as trips FROM \\\`${PROJECT_ID}.raw_data.raw_taxi_trips\\\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31' GROUP BY date ORDER BY date\""
echo ""
echo "2. Check partition count:"
echo "   bq query --use_legacy_sql=false \"SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as partition_count FROM \\\`${PROJECT_ID}.raw_data.raw_taxi_trips\\\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'\""
echo ""
echo "3. Compare taxi vs TNP volumes:"
echo "   bq query --use_legacy_sql=false \"SELECT 'Taxi' as type, COUNT(*) as trips FROM \\\`${PROJECT_ID}.raw_data.raw_taxi_trips\\\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31' UNION ALL SELECT 'TNP', COUNT(*) FROM \\\`${PROJECT_ID}.raw_data.raw_tnp_trips\\\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'\""
echo ""

print_success "Quarterly backfill script completed!"
