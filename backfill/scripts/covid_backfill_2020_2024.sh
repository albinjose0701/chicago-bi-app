#!/bin/bash
#
# COVID-19 Cases Full Backfill Script (March 2020 - May 2024)
# CAFFEINATED - 8-WAY PARALLEL EXECUTION
# ULTRA-OPTIMIZED: 2s delays between extractions
#
# This script extracts COVID-19 case data by ZIP code for 2020-2024 (~220 weeks)
# using Cloud Run Jobs with network resilience and BigQuery verification.
#
# Dataset: yhhz-zm2v
# Date field: week_start (Sundays only)
# Partitioning: Daily (by week_start)
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
PROJECT_ID="chicago-bi-app-msds-432-476520"
REGION="us-central1"
JOB_NAME="extractor-covid"
START_DATE="2020-03-01"  # First Sunday in March 2020
END_DATE="2024-05-19"     # Last week in May 2024
DELAY_SECONDS=2
PARALLEL_WORKERS=8

# Logging
MASTER_LOG="covid_backfill_master_$(date +%Y%m%d_%H%M%S).log"
PROGRESS_FILE="covid_backfill_progress.txt"

# Redirect output to log file
exec 1> >(tee -a "$MASTER_LOG")
exec 2>&1

echo -e "${MAGENTA}════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}  COVID-19 CASES FULL BACKFILL (2020-2024)${NC}"
echo -e "${MAGENTA}  CAFFEINATED - 8-WAY PARALLEL${NC}"
echo -e "${MAGENTA}════════════════════════════════════════════════${NC}"
echo ""
echo -e "Configuration:"
echo -e "  • Period: ${GREEN}2020-03-01 to 2024-05-19${NC}"
echo -e "  • Dataset: ${GREEN}COVID-19 by ZIP (yhhz-zm2v)${NC}"
echo -e "  • Frequency: ${GREEN}Weekly (Sundays)${NC}"
echo -e "  • Workers: ${GREEN}8 parallel processes${NC}"
echo -e "  • Delay: ${YELLOW}2 seconds${NC}"
echo -e "  • Project: ${PROJECT_ID}"
echo -e "  • Region: ${REGION}"
echo -e "  • Keep-Awake: ${GREEN}caffeinate enabled${NC}"
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

# Pre-flight checks
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PRE-FLIGHT CHECKS${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""

# Check 1: Network connectivity
print_info "Checking network connectivity..."
if ping -c 1 -W 5 8.8.8.8 &> /dev/null; then
    print_success "Network connectivity: OK"
else
    print_error "Network connectivity: FAILED"
    exit 1
fi

# Check 2: GCP authentication
print_info "Checking GCP authentication..."
if gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    print_success "GCP authentication: OK (${ACTIVE_ACCOUNT})"
else
    print_error "GCP authentication: FAILED"
    exit 1
fi

# Check 3: Cloud Run job exists
print_info "Checking Cloud Run job..."
if gcloud run jobs describe "$JOB_NAME" --region="$REGION" --project="$PROJECT_ID" &> /dev/null; then
    print_success "Cloud Run job '${JOB_NAME}': OK"
else
    print_error "Cloud Run job '${JOB_NAME}': NOT FOUND"
    exit 1
fi

# Check 4: BigQuery table exists
print_info "Checking BigQuery table..."
if bq show --project_id="$PROJECT_ID" raw_data.raw_covid19_cases_by_zip &> /dev/null; then
    print_success "BigQuery table 'raw_covid19_cases_by_zip': OK"
else
    print_error "BigQuery table 'raw_covid19_cases_by_zip': NOT FOUND"
    exit 1
fi

# Check 5: Power status
print_info "Checking power status..."
if command -v pmset &> /dev/null; then
    POWER_STATUS=$(pmset -g batt | grep -o "'.*'" | tr -d "'")
    BATTERY_PCT=$(pmset -g batt | grep -o '[0-9]*%' | tr -d '%')

    if [[ "$POWER_STATUS" == "AC Power" ]]; then
        print_success "Power: AC connected (${BATTERY_PCT}% battery)"
    elif [[ $BATTERY_PCT -ge 70 ]]; then
        print_success "Power: On battery (${BATTERY_PCT}% - sufficient)"
    else
        print_error "Power: On battery (${BATTERY_PCT}% - TOO LOW)"
        print_error "Please connect to AC power"
        exit 1
    fi
else
    print_info "Power check skipped (pmset not available)"
fi

echo ""
print_success "All pre-flight checks passed!"
echo ""

# Generate list of all Sundays between START_DATE and END_DATE
generate_sundays() {
    local start_date=$1
    local end_date=$2
    local current_date=$start_date

    # Find first Sunday
    while true; do
        DAY_OF_WEEK=$(date -j -f "%Y-%m-%d" "$current_date" +%u 2>/dev/null)
        if [[ "$DAY_OF_WEEK" -eq 7 ]]; then
            break
        fi
        current_date=$(date -j -v+1d -f "%Y-%m-%d" "$current_date" +"%Y-%m-%d" 2>/dev/null)
    done

    # Generate all Sundays
    while [[ "$current_date" < "$end_date" ]] || [[ "$current_date" == "$end_date" ]]; do
        echo "$current_date"
        current_date=$(date -j -v+7d -f "%Y-%m-%d" "$current_date" +"%Y-%m-%d" 2>/dev/null)
    done
}

print_info "Generating list of weeks (Sundays)..."
SUNDAYS=($(generate_sundays "$START_DATE" "$END_DATE"))
TOTAL_WEEKS=${#SUNDAYS[@]}
print_success "Found ${TOTAL_WEEKS} weeks to process"
echo ""

# Calculate week ranges for parallel workers
calculate_week_range() {
    local worker_id=$1
    local weeks_per_worker=$(( (TOTAL_WEEKS + PARALLEL_WORKERS - 1) / PARALLEL_WORKERS ))
    local start_idx=$(( (worker_id - 1) * weeks_per_worker ))
    local end_idx=$(( worker_id * weeks_per_worker - 1 ))

    # Ensure end_idx doesn't exceed array bounds
    if [[ $end_idx -ge $TOTAL_WEEKS ]]; then
        end_idx=$((TOTAL_WEEKS - 1))
    fi

    echo "${start_idx}:${end_idx}"
}

# Function to run extraction for a week range
run_worker() {
    local worker_id=$1
    local start_idx=$2
    local end_idx=$3
    local worker_log="covid_worker_${worker_id}_$(date +%Y%m%d_%H%M%S).log"
    local worker_progress="covid_worker_${worker_id}_progress.txt"

    exec 1> >(tee -a "$worker_log")
    exec 2>&1

    echo -e "${MAGENTA}════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  WORKER ${worker_id} - COVID-19 BACKFILL${NC}"
    echo -e "${MAGENTA}════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Weeks: ${GREEN}${start_idx} to ${end_idx} ($((end_idx - start_idx + 1)) weeks)${NC}"
    echo ""

    # Initialize progress file
    echo "week_start,records_count,timestamp" > "$worker_progress"

    wait_for_network() {
        while ! ping -c 1 -W 5 8.8.8.8 &> /dev/null; do
            echo -e "${RED}[Worker ${worker_id}] Network unavailable. Waiting 30 seconds...${NC}"
            sleep 30
        done
    }

    check_week_in_bigquery() {
        local check_date=$1
        local count=$(bq query --use_legacy_sql=false --format=csv \
            "SELECT COUNT(*) as cnt FROM \`${PROJECT_ID}.raw_data.raw_covid19_cases_by_zip\`
             WHERE DATE(week_start) = '${check_date}'" 2>/dev/null | tail -1)
        echo "$count"
    }

    TOTAL_PROCESSED=0
    SUCCESSFUL=0
    SKIPPED=0
    FAILED=0

    for idx in $(seq $start_idx $end_idx); do
        WEEK_START="${SUNDAYS[$idx]}"
        TOTAL_PROCESSED=$((TOTAL_PROCESSED + 1))

        echo -e "${BLUE}[Worker ${worker_id}] Week: ${WEEK_START} (${TOTAL_PROCESSED}/$((end_idx - start_idx + 1)))${NC}"

        # Check if week already exists
        EXISTING_COUNT=$(check_week_in_bigquery "$WEEK_START")

        if [[ "$EXISTING_COUNT" -gt 0 ]]; then
            echo -e "${GREEN}[Worker ${worker_id}] ${WEEK_START} exists with ${EXISTING_COUNT} records - SKIPPING${NC}"
            echo "${WEEK_START},${EXISTING_COUNT},$(date -u +"%Y-%m-%dT%H:%M:%SZ") [SKIPPED]" >> "$worker_progress"
            SKIPPED=$((SKIPPED + 1))
            sleep 1
            continue
        fi

        # Ensure network is available
        wait_for_network

        # Execute Cloud Run Job
        echo -e "${YELLOW}[Worker ${worker_id}] Executing extraction for week ${WEEK_START}...${NC}"

        if gcloud run jobs execute "$JOB_NAME" \
            --region="$REGION" \
            --update-env-vars="START_DATE=${WEEK_START}" \
            --wait 2>&1 | grep -q "execution completed successfully" ; then

            # Wait for BigQuery consistency
            sleep 3

            # Verify in BigQuery
            RECORD_COUNT=$(check_week_in_bigquery "$WEEK_START")

            if [[ "$RECORD_COUNT" -gt 0 ]]; then
                echo -e "${GREEN}[Worker ${worker_id}] ${WEEK_START} completed: ${RECORD_COUNT} records loaded${NC}"
                echo "${WEEK_START},${RECORD_COUNT},$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$worker_progress"
                SUCCESSFUL=$((SUCCESSFUL + 1))
            else
                echo -e "${YELLOW}[Worker ${worker_id}] ${WEEK_START} completed but 0 records (may be no data)${NC}"
                echo "${WEEK_START},0,$(date -u +"%Y-%m-%dT%H:%M:%SZ") [ZERO]" >> "$worker_progress"
                SUCCESSFUL=$((SUCCESSFUL + 1))
            fi
        else
            echo -e "${RED}[Worker ${worker_id}] ${WEEK_START} FAILED: Cloud Run execution failed${NC}"
            echo "${WEEK_START},0,$(date -u +"%Y-%m-%dT%H:%M:%SZ") [FAILED]" >> "$worker_progress"
            FAILED=$((FAILED + 1))
        fi

        # Delay between extractions
        if [[ $idx -lt $end_idx ]]; then
            sleep "$DELAY_SECONDS"
        fi
    done

    # Worker summary
    echo ""
    echo -e "${MAGENTA}════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  WORKER ${worker_id} COMPLETE${NC}"
    echo -e "${MAGENTA}════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Summary:"
    echo -e "  • Total weeks: ${TOTAL_PROCESSED}"
    echo -e "  • Successful: ${GREEN}${SUCCESSFUL}${NC}"
    echo -e "  • Skipped: ${YELLOW}${SKIPPED}${NC}"
    echo -e "  • Failed: ${RED}${FAILED}${NC}"
    echo ""

    if [[ $FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Export function and variables for parallel execution
export -f run_worker
export -f print_success print_info print_error
export -f generate_sundays calculate_week_range
export PROJECT_ID REGION JOB_NAME DELAY_SECONDS PARALLEL_WORKERS
export GREEN BLUE YELLOW RED CYAN MAGENTA NC
export SUNDAYS TOTAL_WEEKS

# User confirmation
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  READY TO START${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo ""
echo "This will start ${PARALLEL_WORKERS} parallel backfill processes for COVID-19 data"
echo -e "Period: ${GREEN}${START_DATE} to ${END_DATE}${NC}"
echo -e "Total weeks: ${GREEN}${TOTAL_WEEKS}${NC}"
echo -e "Estimated time: ${YELLOW}5-10 minutes${NC}"
echo ""

read -p "Start COVID-19 backfill? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    print_info "Cancelled by user"
    exit 0
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  LAUNCHING PARALLEL WORKERS${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""

# Launch workers
PIDS=()
for worker_id in $(seq 1 $PARALLEL_WORKERS); do
    WEEK_RANGE=$(calculate_week_range $worker_id)
    WORKER_START_IDX=$(echo "$WEEK_RANGE" | cut -d':' -f1)
    WORKER_END_IDX=$(echo "$WEEK_RANGE" | cut -d':' -f2)

    if [[ $WORKER_START_IDX -le $WORKER_END_IDX ]]; then
        WORKER_START_WEEK="${SUNDAYS[$WORKER_START_IDX]}"
        WORKER_END_WEEK="${SUNDAYS[$WORKER_END_IDX]}"
        WEEKS_COUNT=$((WORKER_END_IDX - WORKER_START_IDX + 1))

        print_info "Launching Worker ${worker_id}: ${WORKER_START_WEEK} to ${WORKER_END_WEEK} (${WEEKS_COUNT} weeks)"
        caffeinate -s -i bash -c "$(declare -f run_worker); $(declare -p SUNDAYS); run_worker ${worker_id} ${WORKER_START_IDX} ${WORKER_END_IDX}" &
        PIDS+=($!)
        sleep 2
    fi
done

echo ""
print_success "All ${#PIDS[@]} workers launched!"
echo ""
print_info "Waiting for workers to complete..."
echo ""

# Wait for all workers
FAILED_WORKERS=0
for i in "${!PIDS[@]}"; do
    wait "${PIDS[$i]}"
    EXIT_CODE=$?
    WORKER_NUM=$((i + 1))

    if [[ $EXIT_CODE -eq 0 ]]; then
        print_success "Worker ${WORKER_NUM} completed successfully"
    else
        print_error "Worker ${WORKER_NUM} failed (exit code: ${EXIT_CODE})"
        FAILED_WORKERS=$((FAILED_WORKERS + 1))
    fi
done

# Final summary
echo ""
echo -e "${MAGENTA}════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}  COVID-19 BACKFILL COMPLETE${NC}"
echo -e "${MAGENTA}════════════════════════════════════════════════${NC}"
echo ""

if [[ $FAILED_WORKERS -eq 0 ]]; then
    print_success "🎉 ALL WORKERS COMPLETED SUCCESSFULLY!"
    echo ""
    echo "Next steps:"
    echo "  1. Verify data: bq query --use_legacy_sql=false 'SELECT COUNT(*), MIN(DATE(week_start)), MAX(DATE(week_start)) FROM \`${PROJECT_ID}.raw_data.raw_covid19_cases_by_zip\`'"
    echo "  2. Check worker logs: covid_worker_*_*.log"
    echo "  3. Review progress files: covid_worker_*_progress.txt"
    echo "  4. Analyze trends: SELECT zip_code, SUM(cases_weekly) FROM table GROUP BY zip_code"
    echo ""
    exit 0
else
    print_error "⚠️  ${FAILED_WORKERS} worker(s) failed. Check individual logs."
    exit 1
fi
