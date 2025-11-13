#!/bin/bash
#
# Building Permits Full Backfill Script (2020-2025)
# CAFFEINATED - 7-WAY PARALLEL EXECUTION
# ULTRA-OPTIMIZED: 2s delays between extractions
#
# This script extracts building permit data for 2020-2025 (~2,162 days)
# using Cloud Run Jobs with network resilience and BigQuery verification.
#
# Dataset: ydr8-5enu
# Date field: issue_date
# Partitioning: Daily
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PROJECT_ID="chicago-bi-app-msds-432-476520"
REGION="us-central1"
JOB_NAME="extractor-permits"
START_DATE="2020-01-01"
END_DATE="2025-11-05"
DELAY_SECONDS=2
PARALLEL_WORKERS=7

# Logging
LOG_FILE="permits_backfill_$(date +%Y%m%d_%H%M%S).log"
PROGRESS_FILE="permits_backfill_progress.txt"
MASTER_LOG="permits_backfill_master_$(date +%Y%m%d_%H%M%S).log"

# Redirect output to log file
exec 1> >(tee -a "$MASTER_LOG")
exec 2>&1

echo -e "${CYAN}════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  BUILDING PERMITS FULL BACKFILL (2020-2025)${NC}"
echo -e "${CYAN}  CAFFEINATED - 7-WAY PARALLEL${NC}"
echo -e "${CYAN}════════════════════════════════════════════════${NC}"
echo ""
echo -e "Configuration:"
echo -e "  • Period: ${GREEN}2020-01-01 to 2025-11-05${NC}"
echo -e "  • Dataset: ${GREEN}Building Permits (ydr8-5enu)${NC}"
echo -e "  • Workers: ${GREEN}7 parallel processes${NC}"
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
if bq show --project_id="$PROJECT_ID" raw_data.raw_building_permits &> /dev/null; then
    print_success "BigQuery table 'raw_building_permits': OK"
else
    print_error "BigQuery table 'raw_building_permits': NOT FOUND"
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

# Calculate date ranges for parallel workers
calculate_date_range() {
    local worker_id=$1
    local total_days=$(( ($(date -j -f "%Y-%m-%d" "$END_DATE" +%s) - $(date -j -f "%Y-%m-%d" "$START_DATE" +%s)) / 86400 + 1 ))
    local days_per_worker=$(( (total_days + PARALLEL_WORKERS - 1) / PARALLEL_WORKERS ))
    local start_offset=$(( (worker_id - 1) * days_per_worker ))

    local worker_start=$(date -j -v+${start_offset}d -f "%Y-%m-%d" "$START_DATE" +"%Y-%m-%d" 2>/dev/null)
    local end_offset=$(( worker_id * days_per_worker - 1 ))
    local worker_end=$(date -j -v+${end_offset}d -f "%Y-%m-%d" "$START_DATE" +"%Y-%m-%d" 2>/dev/null)

    # Ensure worker_end doesn't exceed END_DATE
    if [[ "$worker_end" > "$END_DATE" ]]; then
        worker_end="$END_DATE"
    fi

    echo "${worker_start}:${worker_end}"
}

# Function to run extraction for a date range
run_worker() {
    local worker_id=$1
    local start_date=$2
    local end_date=$3
    local worker_log="permits_worker_${worker_id}_$(date +%Y%m%d_%H%M%S).log"
    local worker_progress="permits_worker_${worker_id}_progress.txt"

    exec 1> >(tee -a "$worker_log")
    exec 2>&1

    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  WORKER ${worker_id} - PERMITS BACKFILL${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Date range: ${GREEN}${start_date} to ${end_date}${NC}"
    echo ""

    # Initialize progress file
    echo "date,permits_count,timestamp" > "$worker_progress"

    wait_for_network() {
        while ! ping -c 1 -W 5 8.8.8.8 &> /dev/null; do
            echo -e "${RED}[Worker ${worker_id}] Network unavailable. Waiting 30 seconds...${NC}"
            sleep 30
        done
    }

    get_next_date() {
        local current_date=$1
        date -j -v+1d -f "%Y-%m-%d" "$current_date" +"%Y-%m-%d" 2>/dev/null
    }

    check_date_in_bigquery() {
        local check_date=$1
        local count=$(bq query --use_legacy_sql=false --format=csv \
            "SELECT COUNT(*) as cnt FROM \`${PROJECT_ID}.raw_data.raw_building_permits\`
             WHERE DATE(issue_date) = '${check_date}'" 2>/dev/null | tail -1)
        echo "$count"
    }

    CURRENT_DATE="$start_date"
    TOTAL_DATES=0
    SUCCESSFUL=0
    SKIPPED=0
    FAILED=0

    while [[ "$CURRENT_DATE" < "$end_date" ]] || [[ "$CURRENT_DATE" == "$end_date" ]]; do
        TOTAL_DATES=$((TOTAL_DATES + 1))

        echo -e "${BLUE}[Worker ${worker_id}] Date: ${CURRENT_DATE} (${TOTAL_DATES})${NC}"

        # Check if date already exists
        EXISTING_COUNT=$(check_date_in_bigquery "$CURRENT_DATE")

        if [[ "$EXISTING_COUNT" -gt 0 ]]; then
            echo -e "${GREEN}[Worker ${worker_id}] ${CURRENT_DATE} exists with ${EXISTING_COUNT} permits - SKIPPING${NC}"
            echo "${CURRENT_DATE},${EXISTING_COUNT},$(date -u +"%Y-%m-%dT%H:%M:%SZ") [SKIPPED]" >> "$worker_progress"
            SKIPPED=$((SKIPPED + 1))
            CURRENT_DATE=$(get_next_date "$CURRENT_DATE")
            sleep 1
            continue
        fi

        # Ensure network is available
        wait_for_network

        # Execute Cloud Run Job
        echo -e "${YELLOW}[Worker ${worker_id}] Executing extraction for ${CURRENT_DATE}...${NC}"

        if gcloud run jobs execute "$JOB_NAME" \
            --region="$REGION" \
            --update-env-vars="START_DATE=${CURRENT_DATE}" \
            --wait 2>&1 | grep -q "execution completed successfully" ; then

            # Wait for BigQuery consistency
            sleep 3

            # Verify in BigQuery
            PERMIT_COUNT=$(check_date_in_bigquery "$CURRENT_DATE")

            if [[ "$PERMIT_COUNT" -gt 0 ]]; then
                echo -e "${GREEN}[Worker ${worker_id}] ${CURRENT_DATE} completed: ${PERMIT_COUNT} permits loaded${NC}"
                echo "${CURRENT_DATE},${PERMIT_COUNT},$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$worker_progress"
                SUCCESSFUL=$((SUCCESSFUL + 1))
            else
                echo -e "${YELLOW}[Worker ${worker_id}] ${CURRENT_DATE} completed but 0 permits (may be no data for this date)${NC}"
                echo "${CURRENT_DATE},0,$(date -u +"%Y-%m-%dT%H:%M:%SZ") [ZERO]" >> "$worker_progress"
                SUCCESSFUL=$((SUCCESSFUL + 1))
            fi
        else
            echo -e "${RED}[Worker ${worker_id}] ${CURRENT_DATE} FAILED: Cloud Run execution failed${NC}"
            echo "${CURRENT_DATE},0,$(date -u +"%Y-%m-%dT%H:%M:%SZ") [FAILED]" >> "$worker_progress"
            FAILED=$((FAILED + 1))
        fi

        # Move to next date
        CURRENT_DATE=$(get_next_date "$CURRENT_DATE")

        # Delay between extractions
        if [[ "$CURRENT_DATE" < "$end_date" ]] || [[ "$CURRENT_DATE" == "$end_date" ]]; then
            sleep "$DELAY_SECONDS"
        fi
    done

    # Worker summary
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  WORKER ${worker_id} COMPLETE${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Summary:"
    echo -e "  • Total dates: ${TOTAL_DATES}"
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

# Export function for parallel execution
export -f run_worker
export -f print_success print_info print_error
export PROJECT_ID REGION JOB_NAME DELAY_SECONDS
export GREEN BLUE YELLOW RED CYAN NC

# User confirmation
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  READY TO START${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo ""
echo "This will start ${PARALLEL_WORKERS} parallel backfill processes for building permits"
echo -e "Period: ${GREEN}${START_DATE} to ${END_DATE}${NC}"
echo -e "Estimated time: ${YELLOW}15-20 minutes${NC}"
echo ""

read -p "Start building permits backfill? (yes/no): " CONFIRM
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
    DATE_RANGE=$(calculate_date_range $worker_id)
    WORKER_START=$(echo "$DATE_RANGE" | cut -d':' -f1)
    WORKER_END=$(echo "$DATE_RANGE" | cut -d':' -f2)

    print_info "Launching Worker ${worker_id}: ${WORKER_START} to ${WORKER_END}"
    caffeinate -s -i bash -c "$(declare -f run_worker); run_worker ${worker_id} ${WORKER_START} ${WORKER_END}" &
    PIDS+=($!)
    sleep 2
done

echo ""
print_success "All ${PARALLEL_WORKERS} workers launched!"
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
echo -e "${CYAN}════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  BUILDING PERMITS BACKFILL COMPLETE${NC}"
echo -e "${CYAN}════════════════════════════════════════════════${NC}"
echo ""

if [[ $FAILED_WORKERS -eq 0 ]]; then
    print_success "🎉 ALL WORKERS COMPLETED SUCCESSFULLY!"
    echo ""
    echo "Next steps:"
    echo "  1. Verify data: bq query --use_legacy_sql=false 'SELECT COUNT(*), MIN(DATE(issue_date)), MAX(DATE(issue_date)) FROM \`${PROJECT_ID}.raw_data.raw_building_permits\`'"
    echo "  2. Check worker logs: permits_worker_*_*.log"
    echo "  3. Review progress files: permits_worker_*_progress.txt"
    echo ""
    exit 0
else
    print_error "⚠️  ${FAILED_WORKERS} worker(s) failed. Check individual logs."
    exit 1
fi
