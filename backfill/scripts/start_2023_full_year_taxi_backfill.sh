#!/bin/bash
#
# Master Launcher for 2023 Full Year Taxi Backfill
# TAXI ONLY - TNP data not available for 2023+
# ULTRA-OPTIMIZED: 2s delays, 4-way parallel execution
#
# This script launches all 4 quarterly backfills in parallel with caffeinate
# to prevent system sleep during long-running execution.
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
BACKFILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Log files
MASTER_LOG="2023_full_year_taxi_backfill_$(date +%Y%m%d_%H%M%S).log"
PARALLEL_INFO="2023_parallel_taxi_backfill_info.txt"

# Redirect output to log
exec 1> >(tee -a "$MASTER_LOG")
exec 2>&1

echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  2023 FULL YEAR TAXI BACKFILL${NC}"
echo -e "${BLUE}  ULTRA-OPTIMIZED - 4-WAY PARALLEL${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}⚠️  TAXI ONLY MODE${NC}"
echo -e "${YELLOW}TNP data not available for 2023+${NC}"
echo ""
echo -e "Configuration:"
echo -e "  • Quarters: ${GREEN}Q1, Q2, Q3, Q4 2023${NC}"
echo -e "  • Datasets: ${GREEN}Taxi Only${NC}"
echo -e "  • Execution: ${GREEN}4-way Parallel${NC}"
echo -e "  • Delay: ${YELLOW}2 seconds (ULTRA-OPTIMIZED)${NC}"
echo -e "  • Total Dates: ${GREEN}365 days${NC}"
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
    print_error "Please check your internet connection"
    exit 1
fi

# Check 2: GCP authentication
print_info "Checking GCP authentication..."
if gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    print_success "GCP authentication: OK (${ACTIVE_ACCOUNT})"
else
    print_error "GCP authentication: FAILED"
    print_error "Please run: gcloud auth login"
    exit 1
fi

# Check 3: Project ID
print_info "Checking GCP project..."
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [[ "$CURRENT_PROJECT" == "$PROJECT_ID" ]]; then
    print_success "GCP project: OK (${PROJECT_ID})"
else
    print_error "GCP project: INCORRECT (current: ${CURRENT_PROJECT}, expected: ${PROJECT_ID})"
    print_info "Setting project to ${PROJECT_ID}..."
    gcloud config set project "$PROJECT_ID"
    print_success "Project set to ${PROJECT_ID}"
fi

# Check 4: Cloud Run jobs exist
print_info "Checking Cloud Run jobs..."
if gcloud run jobs describe extractor-taxi --region="${REGION}" --project="${PROJECT_ID}" &> /dev/null; then
    print_success "Cloud Run job 'extractor-taxi': OK"
else
    print_error "Cloud Run job 'extractor-taxi': NOT FOUND"
    exit 1
fi

# Check 5: BigQuery tables exist
print_info "Checking BigQuery tables..."
if bq show --project_id="${PROJECT_ID}" raw_data.raw_taxi_trips &> /dev/null; then
    print_success "BigQuery table 'raw_taxi_trips': OK"
else
    print_error "BigQuery table 'raw_taxi_trips': NOT FOUND"
    exit 1
fi

# Check 6: Power status
print_info "Checking power status..."
if command -v pmset &> /dev/null; then
    POWER_STATUS=$(pmset -g batt | grep -o "'.*'" | tr -d "'")
    BATTERY_PCT=$(pmset -g batt | grep -o '[0-9]*%' | tr -d '%')

    if [[ "$POWER_STATUS" == "AC Power" ]]; then
        print_success "Power: AC connected (${BATTERY_PCT}% battery)"
    elif [[ $BATTERY_PCT -ge 80 ]]; then
        print_success "Power: On battery (${BATTERY_PCT}% - sufficient)"
    else
        print_error "Power: On battery (${BATTERY_PCT}% - TOO LOW)"
        print_error "Please connect to AC power or charge battery to 80%+"
        exit 1
    fi
else
    print_info "Power check skipped (pmset not available)"
fi

# Check 7: Disk space
print_info "Checking disk space..."
FREE_SPACE=$(df -h . | tail -1 | awk '{print $4}')
FREE_SPACE_GB=$(df -g . | tail -1 | awk '{print $4}')
if [[ $FREE_SPACE_GB -ge 5 ]]; then
    print_success "Disk space: ${FREE_SPACE} available"
else
    print_error "Disk space: Only ${FREE_SPACE} available (need 5GB+)"
    exit 1
fi

# Check 8: Script files exist
print_info "Checking quarterly script files..."
SCRIPTS=(
    "${BACKFILL_DIR}/quarterly_backfill_q1_2023_taxi_only.sh"
    "${BACKFILL_DIR}/quarterly_backfill_q2_2023_taxi_only.sh"
    "${BACKFILL_DIR}/quarterly_backfill_q3_2023_taxi_only.sh"
    "${BACKFILL_DIR}/quarterly_backfill_q4_2023_taxi_only.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [[ -f "$script" ]]; then
        print_success "Script found: $(basename "$script")"
    else
        print_error "Script NOT FOUND: $script"
        exit 1
    fi
done

echo ""
print_success "All pre-flight checks passed!"
echo ""

# User confirmation
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  READY TO START${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo ""
echo "This will start 4 parallel backfill processes:"
echo "  • Q1 2023: Jan 1 - Mar 31 (90 days)"
echo "  • Q2 2023: Apr 1 - Jun 30 (91 days)"
echo "  • Q3 2023: Jul 1 - Sep 30 (92 days)"
echo "  • Q4 2023: Oct 1 - Dec 31 (92 days)"
echo ""
echo -e "${GREEN}Total: 365 taxi extractions${NC}"
echo -e "${YELLOW}Estimated time: 2-3 hours (with 2s delays)${NC}"
echo ""
echo -e "${YELLOW}Note: Your system will be kept awake with caffeinate${NC}"
echo ""

read -p "Start 2023 taxi backfill? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    print_info "Cancelled by user"
    exit 0
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STARTING PARALLEL BACKFILLS${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""

# Change to backfill directory
cd "$BACKFILL_DIR"

# Launch Q1
print_info "Launching Q1 2023 (Jan-Mar)..."
caffeinate -s -i bash quarterly_backfill_q1_2023_taxi_only.sh &
Q1_PID=$!
print_success "Q1 started (PID: ${Q1_PID})"
sleep 3

# Launch Q2
print_info "Launching Q2 2023 (Apr-Jun)..."
caffeinate -s -i bash quarterly_backfill_q2_2023_taxi_only.sh &
Q2_PID=$!
print_success "Q2 started (PID: ${Q2_PID})"
sleep 3

# Launch Q3
print_info "Launching Q3 2023 (Jul-Sep)..."
caffeinate -s -i bash quarterly_backfill_q3_2023_taxi_only.sh &
Q3_PID=$!
print_success "Q3 started (PID: ${Q3_PID})"
sleep 3

# Launch Q4
print_info "Launching Q4 2023 (Oct-Dec)..."
caffeinate -s -i bash quarterly_backfill_q4_2023_taxi_only.sh &
Q4_PID=$!
print_success "Q4 started (PID: ${Q4_PID})"

echo ""
print_success "All 4 quarters launched successfully!"
echo ""

# Save process info
cat > "$PARALLEL_INFO" <<EOF
2023 Taxi Backfill - 4-Way Parallel Execution
Started: $(date)

Process IDs:
  Q1 (Jan-Mar): ${Q1_PID}
  Q2 (Apr-Jun): ${Q2_PID}
  Q3 (Jul-Sep): ${Q3_PID}
  Q4 (Oct-Dec): ${Q4_PID}

Monitoring:
  ps -p ${Q1_PID} ${Q2_PID} ${Q3_PID} ${Q4_PID}

Logs:
  Q1: backfill_q1_2023_taxi_only_*.log
  Q2: backfill_q2_2023_taxi_only_*.log
  Q3: backfill_q3_2023_taxi_only_*.log
  Q4: backfill_q4_2023_taxi_only_*.log
EOF

print_info "Process info saved to: ${PARALLEL_INFO}"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  BACKFILLS RUNNING${NC}"
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""
echo "The 4 quarterly backfills are now running in parallel."
echo "Each process will complete independently."
echo ""
echo "To monitor progress:"
echo "  • Check process status: ps -p ${Q1_PID} ${Q2_PID} ${Q3_PID} ${Q4_PID}"
echo "  • View Q1 log: tail -f backfill_q1_2023_taxi_only_*.log"
echo "  • View Q2 log: tail -f backfill_q2_2023_taxi_only_*.log"
echo "  • View Q3 log: tail -f backfill_q3_2023_taxi_only_*.log"
echo "  • View Q4 log: tail -f backfill_q4_2023_taxi_only_*.log"
echo ""
echo "Waiting for all processes to complete..."
echo ""

# Wait for all processes
wait $Q1_PID
Q1_EXIT=$?
Q1_END=$(date)
print_info "Q1 finished at ${Q1_END} (exit code: ${Q1_EXIT})"

wait $Q2_PID
Q2_EXIT=$?
Q2_END=$(date)
print_info "Q2 finished at ${Q2_END} (exit code: ${Q2_EXIT})"

wait $Q3_PID
Q3_EXIT=$?
Q3_END=$(date)
print_info "Q3 finished at ${Q3_END} (exit code: ${Q3_EXIT})"

wait $Q4_PID
Q4_EXIT=$?
Q4_END=$(date)
print_info "Q4 finished at ${Q4_END} (exit code: ${Q4_EXIT})"

# Append completion info
cat >> "$PARALLEL_INFO" <<EOF

Completion Times:
  Q1: ${Q1_END} (exit: ${Q1_EXIT})
  Q2: ${Q2_END} (exit: ${Q2_EXIT})
  Q3: ${Q3_END} (exit: ${Q3_EXIT})
  Q4: ${Q4_END} (exit: ${Q4_EXIT})

Finished: $(date)
EOF

echo ""
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  COMPLETION SUMMARY${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""

if [[ $Q1_EXIT -eq 0 ]]; then
    print_success "Q1 2023: SUCCESS"
else
    print_error "Q1 2023: FAILED (exit code: ${Q1_EXIT})"
fi

if [[ $Q2_EXIT -eq 0 ]]; then
    print_success "Q2 2023: SUCCESS"
else
    print_error "Q2 2023: FAILED (exit code: ${Q2_EXIT})"
fi

if [[ $Q3_EXIT -eq 0 ]]; then
    print_success "Q3 2023: SUCCESS"
else
    print_error "Q3 2023: FAILED (exit code: ${Q3_EXIT})"
fi

if [[ $Q4_EXIT -eq 0 ]]; then
    print_success "Q4 2023: SUCCESS"
else
    print_error "Q4 2023: FAILED (exit code: ${Q4_EXIT})"
fi

echo ""

if [[ $Q1_EXIT -eq 0 ]] && [[ $Q2_EXIT -eq 0 ]] && [[ $Q3_EXIT -eq 0 ]] && [[ $Q4_EXIT -eq 0 ]]; then
    print_success "🎉 ALL 2023 TAXI BACKFILLS COMPLETED SUCCESSFULLY!"
    echo ""
    echo "Next steps:"
    echo "  1. Verify data in BigQuery"
    echo "  2. Check progress files (q1_2023_taxi_progress.txt, etc.)"
    echo "  3. Review logs for any warnings"
    echo "  4. Plan 2024 backfill (note: schema changes to explore)"
    echo ""
else
    print_error "Some backfills failed. Check individual logs for details."
    echo ""
fi

print_info "Master log: ${MASTER_LOG}"
print_info "Process info: ${PARALLEL_INFO}"
echo ""
