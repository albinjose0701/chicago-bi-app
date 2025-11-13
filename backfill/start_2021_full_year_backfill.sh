#!/bin/bash
#
# Master Launcher for 2021 Full Year Backfill
# Runs all 4 quarters in parallel with caffeinate and network resilience
# Estimated completion: 2.5-3 hours for entire year 2021
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
MASTER_LOG="2021_full_year_backfill_$(date +%Y%m%d_%H%M%S).log"
TRACKING_FILE="2021_parallel_backfill_info.txt"

# Redirect all output to log file AND console
exec 1> >(tee -a "$MASTER_LOG")
exec 2>&1

echo -e "${CYAN}════════════════════════════════════════════════${NC}"
echo -e "${CYAN}   2021 FULL YEAR BACKFILL - 4-WAY PARALLEL     ${NC}"
echo -e "${CYAN}════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo -e "  Year: ${GREEN}2021 (Jan 1 - Dec 31)${NC}"
echo -e "  Quarters: ${GREEN}Q1, Q2, Q3, Q4 (running in parallel)${NC}"
echo -e "  Total Dates: ${GREEN}365 days${NC}"
echo -e "  Total Extractions: ${GREEN}730 (365 taxi + 365 TNP)${NC}"
echo -e "  Delay per extraction: ${YELLOW}5 seconds (HIGHLY OPTIMIZED)${NC}"
echo -e "  Estimated completion: ${YELLOW}2.5-3 hours${NC}"
echo -e "  Log File: ${GREEN}${MASTER_LOG}${NC}"
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

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Pre-flight check: Network connectivity
check_network() {
    print_header "PRE-FLIGHT CHECK: Network Connectivity"

    if ping -c 1 -W 5 8.8.8.8 &> /dev/null; then
        print_success "Internet connectivity verified"
        return 0
    else
        print_error "No internet connection detected"
        return 1
    fi
}

# Pre-flight check: GCP authentication
check_gcp_auth() {
    print_header "PRE-FLIGHT CHECK: GCP Authentication"

    local account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -n1)

    if [[ -n "$account" ]]; then
        print_success "Authenticated as: ${account}"

        local current_project=$(gcloud config get-value project 2>/dev/null)
        if [[ "$current_project" == "$PROJECT_ID" ]]; then
            print_success "Project set to: ${PROJECT_ID}"
            return 0
        else
            print_error "Wrong project. Current: ${current_project}, Expected: ${PROJECT_ID}"
            echo "Run: gcloud config set project ${PROJECT_ID}"
            return 1
        fi
    else
        print_error "Not authenticated to GCP"
        echo "Run: gcloud auth login"
        return 1
    fi
}

# Pre-flight check: Cloud Run jobs exist
check_cloud_run_jobs() {
    print_header "PRE-FLIGHT CHECK: Cloud Run Jobs"

    local jobs_ok=true

    for job in "extractor-taxi" "extractor-tnp"; do
        if gcloud run jobs describe "$job" --region="$REGION" --project="$PROJECT_ID" &>/dev/null; then
            print_success "Cloud Run job '${job}' exists"
        else
            print_error "Cloud Run job '${job}' not found"
            jobs_ok=false
        fi
    done

    if [[ "$jobs_ok" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Pre-flight check: BigQuery tables exist
check_bigquery_tables() {
    print_header "PRE-FLIGHT CHECK: BigQuery Tables"

    local tables_ok=true

    for table in "raw_taxi_trips" "raw_tnp_trips"; do
        if bq show --project_id="$PROJECT_ID" "raw_data.${table}" &>/dev/null; then
            print_success "BigQuery table '${table}' exists"
        else
            print_error "BigQuery table '${table}' not found"
            tables_ok=false
        fi
    done

    if [[ "$tables_ok" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Pre-flight check: Battery and power
check_power() {
    print_header "PRE-FLIGHT CHECK: Power Status"

    local power_source=$(pmset -g batt | grep -o "AC Power\|Battery Power" || echo "Unknown")
    local battery_pct=$(pmset -g batt | grep -o '[0-9]*%' | tr -d '%' || echo "0")

    echo -e "Power Source: ${YELLOW}${power_source}${NC}"
    echo -e "Battery Level: ${YELLOW}${battery_pct}%${NC}"

    if [[ "$power_source" == "AC Power" ]]; then
        print_success "Connected to AC Power - optimal for long-running process"
        return 0
    elif [[ $battery_pct -ge 80 ]]; then
        print_info "Running on battery (${battery_pct}%) - consider connecting to AC power"
        echo ""
        read -p "Continue on battery? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            return 0
        else
            echo "Cancelled. Please connect to AC power and try again."
            return 1
        fi
    else
        print_error "Battery too low (${battery_pct}%) - connect to AC power first"
        return 1
    fi
}

# Pre-flight check: Disk space
check_disk_space() {
    print_header "PRE-FLIGHT CHECK: Disk Space"

    local available_gb=$(df -H . | awk 'NR==2 {print $4}' | tr -d 'G')

    echo -e "Available disk space: ${YELLOW}${available_gb}${NC}"

    # Check if we have at least 5GB free
    if [[ $(echo "$available_gb > 5" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        print_success "Sufficient disk space available"
        return 0
    else
        print_error "Low disk space (${available_gb} available)"
        return 1
    fi
}

# Check if scripts exist
check_scripts_exist() {
    print_header "PRE-FLIGHT CHECK: Quarterly Scripts"

    local scripts_ok=true

    for quarter in q1 q2 q3 q4; do
        local script="quarterly_backfill_${quarter}_2021_resilient.sh"
        if [[ -f "$script" ]]; then
            print_success "Script '${script}' found"
            chmod +x "$script"
        else
            print_error "Script '${script}' not found"
            scripts_ok=false
        fi
    done

    if [[ "$scripts_ok" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Run all pre-flight checks
run_preflight_checks() {
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}   RUNNING PRE-FLIGHT CHECKS                    ${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"

    local checks_passed=true

    check_network || checks_passed=false
    check_gcp_auth || checks_passed=false
    check_cloud_run_jobs || checks_passed=false
    check_bigquery_tables || checks_passed=false
    check_power || checks_passed=false
    check_disk_space || checks_passed=false
    check_scripts_exist || checks_passed=false

    if [[ "$checks_passed" == "true" ]]; then
        echo ""
        print_header "✅ ALL PRE-FLIGHT CHECKS PASSED"
        return 0
    else
        echo ""
        print_header "❌ SOME PRE-FLIGHT CHECKS FAILED"
        echo "Please fix the issues above before proceeding."
        return 1
    fi
}

# Start all 4 quarters in parallel
start_parallel_backfill() {
    print_header "STARTING 4-WAY PARALLEL BACKFILL"

    # Create tracking file
    cat > "$TRACKING_FILE" << EOF
2021 Full Year Parallel Backfill Started: $(date)
EOF

    echo -e "${YELLOW}Launching all 4 quarters with caffeinate...${NC}"
    echo ""

    # Launch Q1
    echo -e "${CYAN}[Q1]${NC} Starting Q1 2021 backfill (Jan-Mar, 90 days)..."
    caffeinate -s -i ./quarterly_backfill_q1_2021_resilient.sh all &
    Q1_PID=$!
    echo "Q1 PID: $Q1_PID" | tee -a "$TRACKING_FILE"
    sleep 2

    # Launch Q2
    echo -e "${CYAN}[Q2]${NC} Starting Q2 2021 backfill (Apr-Jun, 91 days)..."
    caffeinate -s -i ./quarterly_backfill_q2_2021_resilient.sh all &
    Q2_PID=$!
    echo "Q2 PID: $Q2_PID" | tee -a "$TRACKING_FILE"
    sleep 2

    # Launch Q3
    echo -e "${CYAN}[Q3]${NC} Starting Q3 2021 backfill (Jul-Sep, 92 days)..."
    caffeinate -s -i ./quarterly_backfill_q3_2021_resilient.sh all &
    Q3_PID=$!
    echo "Q3 PID: $Q3_PID" | tee -a "$TRACKING_FILE"
    sleep 2

    # Launch Q4
    echo -e "${CYAN}[Q4]${NC} Starting Q4 2021 backfill (Oct-Dec, 92 days)..."
    caffeinate -s -i ./quarterly_backfill_q4_2021_resilient.sh all &
    Q4_PID=$!
    echo "Q4 PID: $Q4_PID" | tee -a "$TRACKING_FILE"

    echo "" | tee -a "$TRACKING_FILE"

    print_success "All 4 quarters launched successfully!"
    echo ""
    echo -e "${BLUE}Process IDs:${NC}"
    echo -e "  Q1: ${GREEN}${Q1_PID}${NC}"
    echo -e "  Q2: ${GREEN}${Q2_PID}${NC}"
    echo -e "  Q3: ${GREEN}${Q3_PID}${NC}"
    echo -e "  Q4: ${GREEN}${Q4_PID}${NC}"
    echo ""

    print_info "Monitoring progress... (Ctrl+C to detach, processes will continue)"
    echo ""
}

# Monitor progress
monitor_progress() {
    local start_time=$(date +%s)

    # Wait for all processes to complete
    echo -e "${YELLOW}Waiting for all quarters to complete...${NC}"
    echo ""

    wait $Q1_PID
    Q1_EXIT=$?
    echo "" | tee -a "$TRACKING_FILE"
    echo "Q1 Completed: $(date)" | tee -a "$TRACKING_FILE"
    echo "Q1 Exit Code: $Q1_EXIT" | tee -a "$TRACKING_FILE"

    wait $Q2_PID
    Q2_EXIT=$?
    echo "Q2 Completed: $(date)" | tee -a "$TRACKING_FILE"
    echo "Q2 Exit Code: $Q2_EXIT" | tee -a "$TRACKING_FILE"

    wait $Q3_PID
    Q3_EXIT=$?
    echo "Q3 Completed: $(date)" | tee -a "$TRACKING_FILE"
    echo "Q3 Exit Code: $Q3_EXIT" | tee -a "$TRACKING_FILE"

    wait $Q4_PID
    Q4_EXIT=$?
    echo "Q4 Completed: $(date)" | tee -a "$TRACKING_FILE"
    echo "Q4 Exit Code: $Q4_EXIT" | tee -a "$TRACKING_FILE"

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))

    echo "" | tee -a "$TRACKING_FILE"
    echo "Total Duration: ${hours}h ${minutes}m" | tee -a "$TRACKING_FILE"
}

# Generate final report
generate_report() {
    print_header "2021 FULL YEAR BACKFILL COMPLETION REPORT"

    echo -e "${BLUE}Completion Status:${NC}"

    local all_success=true

    if [[ $Q1_EXIT -eq 0 ]]; then
        print_success "Q1 2021 (Jan-Mar): Completed successfully"
    else
        print_error "Q1 2021 (Jan-Mar): Failed with exit code $Q1_EXIT"
        all_success=false
    fi

    if [[ $Q2_EXIT -eq 0 ]]; then
        print_success "Q2 2021 (Apr-Jun): Completed successfully"
    else
        print_error "Q2 2021 (Apr-Jun): Failed with exit code $Q2_EXIT"
        all_success=false
    fi

    if [[ $Q3_EXIT -eq 0 ]]; then
        print_success "Q3 2021 (Jul-Sep): Completed successfully"
    else
        print_error "Q3 2021 (Jul-Sep): Failed with exit code $Q3_EXIT"
        all_success=false
    fi

    if [[ $Q4_EXIT -eq 0 ]]; then
        print_success "Q4 2021 (Oct-Dec): Completed successfully"
    else
        print_error "Q4 2021 (Oct-Dec): Failed with exit code $Q4_EXIT"
        all_success=false
    fi

    echo ""
    echo -e "${BLUE}Progress Files:${NC}"
    for quarter in q1 q2 q3 q4; do
        local progress_file="${quarter}_2021_progress.txt"
        if [[ -f "$progress_file" ]]; then
            local count=$(($(wc -l < "$progress_file") - 1))  # Subtract header
            echo -e "  ${quarter}_2021_progress.txt: ${GREEN}${count} entries${NC}"
        fi
    done

    echo ""
    echo -e "${BLUE}Log Files:${NC}"
    echo -e "  Master Log: ${GREEN}${MASTER_LOG}${NC}"
    for file in backfill_q*_2021_resilient_*.log; do
        if [[ -f "$file" ]]; then
            echo -e "  ${file}"
        fi
    done

    echo ""

    if [[ "$all_success" == "true" ]]; then
        print_header "🎉 2021 FULL YEAR BACKFILL COMPLETED SUCCESSFULLY!"
        echo ""
        echo -e "${GREEN}Next Steps:${NC}"
        echo "  1. Verify data in BigQuery"
        echo "  2. Check for any missing dates"
        echo "  3. Validate data quality"
        echo "  4. Update session context documentation"
        echo ""
        return 0
    else
        print_header "⚠️  2021 BACKFILL COMPLETED WITH ERRORS"
        echo ""
        echo "Please review the logs above and retry failed quarters."
        echo ""
        return 1
    fi
}

# Main execution
main() {
    # Run pre-flight checks
    if ! run_preflight_checks; then
        exit 1
    fi

    # Confirm before starting
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Ready to start 2021 full year backfill (4-way parallel)${NC}"
    echo -e "${YELLOW}Estimated time: 2.5-3 hours${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Start backfill now? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    # Start parallel backfill
    start_parallel_backfill

    # Monitor and wait for completion
    monitor_progress

    # Generate final report
    generate_report

    exit $?
}

# Run main
main
