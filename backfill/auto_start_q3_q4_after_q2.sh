#!/bin/bash
#
# Automatic Q3/Q4 Starter - Waits for Q2 to finish, then starts Q3+Q4 in parallel
# NO USER INPUT REQUIRED - Fully automated
#

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ID="chicago-bi-app-msds-432-476520"
Q2_LOG_PATTERN="backfill_q2_2020_resilient_*.log"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Automatic Q3/Q4 Backfill Launcher${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}This script will:${NC}"
echo "  1. Monitor Q2 backfill progress"
echo "  2. Wait for Q2 to complete"
echo "  3. Automatically start Q3 + Q4 in parallel"
echo "  4. Use optimized 10s delays (3x faster)"
echo ""

# Function to check if Q2 is still running
check_q2_running() {
    if ps aux | grep -q "[q]uarterly_backfill_q2_2020_resilient.sh"; then
        return 0  # Still running
    else
        return 1  # Not running
    fi
}

# Function to get Q2 progress
get_q2_progress() {
    local log_file=$(ls -t backfill_q2_2020_resilient_*.log 2>/dev/null | head -1)
    if [[ -f "$log_file" ]]; then
        local completed=$(grep -c "✅ Verified" "$log_file" 2>/dev/null || echo "0")
        echo "$completed"
    else
        echo "0"
    fi
}

# Wait for Q2 to finish
echo -e "${YELLOW}Monitoring Q2 2020 backfill...${NC}"
echo ""

while check_q2_running; do
    PROGRESS=$(get_q2_progress)
    echo -ne "\r${YELLOW}Q2 Progress: ${PROGRESS}/182 complete... waiting for completion${NC}   "
    sleep 60  # Check every minute
done

echo ""
echo ""
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_success "Q2 2020 backfill completed!"
echo ""

# Get Q2 final stats
Q2_LOG=$(ls -t backfill_q2_2020_resilient_*.log 2>/dev/null | head -1)
if [[ -f "$Q2_LOG" ]]; then
    echo -e "${BLUE}Q2 Final Stats:${NC}"
    TAXI_Q2=$(bq query --use_legacy_sql=false --format=csv --project_id="$PROJECT_ID" \
        "SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as count
         FROM \`${PROJECT_ID}.raw_data.raw_taxi_trips\`
         WHERE DATE(trip_start_timestamp) BETWEEN '2020-04-01' AND '2020-06-30'" 2>/dev/null | tail -n1)

    TNP_Q2=$(bq query --use_legacy_sql=false --format=csv --project_id="$PROJECT_ID" \
        "SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as count
         FROM \`${PROJECT_ID}.raw_data.raw_tnp_trips\`
         WHERE DATE(trip_start_timestamp) BETWEEN '2020-04-01' AND '2020-06-30'" 2>/dev/null | tail -n1)

    echo "  Taxi dates: ${TAXI_Q2}/91"
    echo "  TNP dates: ${TNP_Q2}/91"
    echo ""
fi

# Wait a bit for any final writes to complete
echo -e "${YELLOW}Waiting 30 seconds for final writes to complete...${NC}"
sleep 30

# Start Q3 and Q4 in parallel
echo ""
echo -e "${GREEN}Starting Q3 and Q4 backfills in parallel!${NC}"
echo -e "${GREEN}Using optimized 10s delays (3x faster than Q2)${NC}"
echo ""

# Change to backfill directory
cd /Users/albin/Desktop/chicago-bi-app/backfill

# Create timestamped startup log
STARTUP_LOG="q3_q4_parallel_startup_$(date +%Y%m%d_%H%M%S).log"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Starting Q3 2020 Backfill${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Start Q3 in background with caffeinate
caffeinate -s -i ./quarterly_backfill_q3_2020_resilient.sh all > q3_startup.log 2>&1 &
Q3_PID=$!

sleep 5

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Starting Q4 2020 Backfill${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Start Q4 in background with caffeinate
caffeinate -s -i ./quarterly_backfill_q4_2020_resilient.sh all > q4_startup.log 2>&1 &
Q4_PID=$!

echo ""
print_success "Both Q3 and Q4 backfills started successfully!"
echo ""
echo -e "${BLUE}Process Information:${NC}"
echo "  Q3 PID: ${Q3_PID}"
echo "  Q4 PID: ${Q4_PID}"
echo ""
echo -e "${BLUE}Log Files:${NC}"
echo "  Q3: backfill_q3_2020_resilient_*.log"
echo "  Q4: backfill_q4_2020_resilient_*.log"
echo ""
echo -e "${BLUE}Progress Files:${NC}"
echo "  Q3: q3_progress.txt"
echo "  Q4: q4_progress.txt"
echo ""
echo -e "${YELLOW}Monitor with:${NC}"
echo "  Q3: tail -f backfill_q3_2020_resilient_*.log"
echo "  Q4: tail -f backfill_q4_2020_resilient_*.log"
echo ""
echo -e "${BLUE}Expected Completion:${NC}"
echo "  Q3: 92 dates × 2 datasets × ~2 min = ~6 hours"
echo "  Q4: 92 dates × 2 datasets × ~2 min = ~6 hours"
echo "  Running in parallel = ~6 hours total"
echo "  Estimated finish time: $(date -v+6H '+%Y-%m-%d %H:%M')"
echo ""

# Save info to file
{
    echo "Q3/Q4 Parallel Backfill Started: $(date)"
    echo "Q3 PID: $Q3_PID"
    echo "Q4 PID: $Q4_PID"
    echo "Q2 Completion: $(date)"
} > parallel_backfill_info.txt

print_success "Automation complete! Q3 and Q4 running in background."
echo ""
echo -e "${GREEN}You can now close this terminal - processes will continue running.${NC}"
echo ""

# Keep monitoring in the background
{
    # Wait for both to finish
    wait $Q3_PID
    Q3_EXIT=$?

    wait $Q4_PID
    Q4_EXIT=$?

    # Log completion
    {
        echo ""
        echo "================================================"
        echo "Q3/Q4 Parallel Backfill Completion Report"
        echo "================================================"
        echo "Completion Time: $(date)"
        echo "Q3 Exit Code: $Q3_EXIT"
        echo "Q4 Exit Code: $Q4_EXIT"
        echo ""
    } >> parallel_backfill_info.txt

} &

exit 0
