#!/bin/bash
#
# Start Q2 2020 Backfill in Unattended Mode with System Keep-Awake
# This wrapper uses caffeinate to prevent system sleep
#

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Q2 2020 Quarterly Backfill - Unattended Mode${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Pre-flight checks
echo -e "${YELLOW}Running pre-flight checks...${NC}"
echo ""

# 1. Check if gcloud is authenticated
echo -n "Checking gcloud authentication... "
if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
    ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1)
    echo -e "${GREEN}✅ Authenticated as ${ACCOUNT}${NC}"
else
    echo -e "${RED}❌ Not authenticated${NC}"
    echo ""
    echo "Please run: gcloud auth login"
    exit 1
fi

# 2. Check if correct project is set
echo -n "Checking GCP project... "
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
EXPECTED_PROJECT="chicago-bi-app-msds-432-476520"
if [[ "$CURRENT_PROJECT" == "$EXPECTED_PROJECT" ]]; then
    echo -e "${GREEN}✅ Project: ${CURRENT_PROJECT}${NC}"
else
    echo -e "${RED}❌ Wrong project: ${CURRENT_PROJECT}${NC}"
    echo ""
    echo "Setting correct project..."
    gcloud config set project "$EXPECTED_PROJECT"
fi

# 3. Check network connectivity
echo -n "Checking network connectivity... "
if ping -c 1 -W 5 8.8.8.8 &> /dev/null; then
    echo -e "${GREEN}✅ Network OK${NC}"
else
    echo -e "${RED}❌ Network unavailable${NC}"
    echo ""
    echo "Please check your internet connection and try again."
    exit 1
fi

# 4. Check BigQuery access
echo -n "Checking BigQuery access... "
if bq ls --project_id="$EXPECTED_PROJECT" raw_data &>/dev/null; then
    echo -e "${GREEN}✅ BigQuery accessible${NC}"
else
    echo -e "${RED}❌ Cannot access BigQuery${NC}"
    exit 1
fi

# 5. Check if Cloud Run jobs exist
echo -n "Checking Cloud Run jobs... "
JOBS_OK=true
if ! gcloud run jobs describe extractor-taxi --region=us-central1 --project="$EXPECTED_PROJECT" &>/dev/null; then
    echo -e "${RED}❌ extractor-taxi job not found${NC}"
    JOBS_OK=false
fi
if ! gcloud run jobs describe extractor-tnp --region=us-central1 --project="$EXPECTED_PROJECT" &>/dev/null; then
    echo -e "${RED}❌ extractor-tnp job not found${NC}"
    JOBS_OK=false
fi
if [[ "$JOBS_OK" == "true" ]]; then
    echo -e "${GREEN}✅ Both extractor jobs found${NC}"
else
    exit 1
fi

# 6. Check current Q2 progress
echo -n "Checking current Q2 progress... "
Q2_TAXI_DATES=$(bq query --use_legacy_sql=false --format=csv --project_id="$EXPECTED_PROJECT" \
    "SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as count
     FROM \`${EXPECTED_PROJECT}.raw_data.raw_taxi_trips\`
     WHERE DATE(trip_start_timestamp) BETWEEN '2020-04-01' AND '2020-06-30'" 2>/dev/null | tail -n1)

Q2_TNP_DATES=$(bq query --use_legacy_sql=false --format=csv --project_id="$EXPECTED_PROJECT" \
    "SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as count
     FROM \`${EXPECTED_PROJECT}.raw_data.raw_tnp_trips\`
     WHERE DATE(trip_start_timestamp) BETWEEN '2020-04-01' AND '2020-06-30'" 2>/dev/null | tail -n1)

if [[ -n "$Q2_TAXI_DATES" && -n "$Q2_TNP_DATES" ]]; then
    echo -e "${GREEN}✅${NC}"
    echo -e "   Taxi: ${YELLOW}${Q2_TAXI_DATES}/91${NC} dates completed"
    echo -e "   TNP:  ${YELLOW}${Q2_TNP_DATES}/91${NC} dates completed"
    TAXI_REMAINING=$((91 - Q2_TAXI_DATES))
    TNP_REMAINING=$((91 - Q2_TNP_DATES))
    TOTAL_REMAINING=$((TAXI_REMAINING + TNP_REMAINING))
    echo -e "   ${YELLOW}${TOTAL_REMAINING} total extractions remaining${NC}"
else
    echo -e "${RED}❌ Could not check progress${NC}"
    exit 1
fi

# 7. Check Q1 completion status
echo -n "Checking Q1 completion (baseline)... "
Q1_TAXI_DATES=$(bq query --use_legacy_sql=false --format=csv --project_id="$EXPECTED_PROJECT" \
    "SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as count
     FROM \`${EXPECTED_PROJECT}.raw_data.raw_taxi_trips\`
     WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'" 2>/dev/null | tail -n1)

Q1_TNP_DATES=$(bq query --use_legacy_sql=false --format=csv --project_id="$EXPECTED_PROJECT" \
    "SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as count
     FROM \`${EXPECTED_PROJECT}.raw_data.raw_tnp_trips\`
     WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'" 2>/dev/null | tail -n1)

if [[ "$Q1_TAXI_DATES" == "91" && "$Q1_TNP_DATES" == "91" ]]; then
    echo -e "${GREEN}✅ Q1 complete (91/91 both datasets)${NC}"
else
    echo -e "${YELLOW}⚠️  Q1 incomplete (Taxi: ${Q1_TAXI_DATES}/91, TNP: ${Q1_TNP_DATES}/91)${NC}"
fi

# 8. Check battery status (if on laptop)
if [[ -f /usr/bin/pmset ]]; then
    echo -n "Checking power status... "
    POWER_SOURCE=$(pmset -g batt | grep -o "AC Power\|Battery Power")
    if [[ "$POWER_SOURCE" == "AC Power" ]]; then
        echo -e "${GREEN}✅ Connected to AC Power${NC}"
    else
        echo -e "${YELLOW}⚠️  Running on Battery Power${NC}"
        echo -e "   ${YELLOW}Recommend connecting to power for long-running process${NC}"
        read -p "   Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi
fi

echo ""
echo -e "${GREEN}All pre-flight checks passed!${NC}"
echo ""

# Show summary
echo -e "${BLUE}Q2 2020 Backfill Summary:${NC}"
echo -e "  Quarter: ${YELLOW}Q2 2020 (Apr 1 - Jun 30)${NC}"
echo -e "  Total dates: ${YELLOW}91${NC}"
echo -e "  Remaining extractions: ${YELLOW}${TOTAL_REMAINING}${NC}"
echo -e "  Estimated time: ${YELLOW}~$((TOTAL_REMAINING * 5 / 60)) hours${NC} (at ~5 min/extraction)"
echo -e "  Estimated cost: ${YELLOW}~\$2-3${NC} (one-time)"
echo ""
echo -e "${YELLOW}Expected Q2 Volume (COVID-19 Impact):${NC}"
echo -e "  Q1 2020: 25.9M trips (baseline)"
echo -e "  Q2 2020: ~10-15M trips (50-70% reduction expected)"
echo -e "  Why: Illinois stay-at-home order (Mar 21 - May 29)"
echo ""
echo -e "${YELLOW}The script will:${NC}"
echo "  • Keep your system awake using caffeinate"
echo "  • Handle network interruptions automatically"
echo "  • Skip dates that are already completed"
echo "  • Retry failures up to 3 times per date"
echo "  • Log all activity to timestamped log file"
echo "  • Process both Taxi and TNP datasets"
echo ""
echo -e "${YELLOW}You can safely leave your computer.${NC}"
echo -e "${YELLOW}To check progress later, look for the log file in:${NC}"
echo -e "  ${BLUE}/Users/albin/Desktop/chicago-bi-app/backfill/backfill_q2_2020_resilient_*.log${NC}"
echo ""

# Final confirmation
read -p "Press Enter to start the Q2 backfill, or Ctrl+C to cancel..."

echo ""
echo -e "${GREEN}Starting Q2 2020 backfill with system keep-awake enabled...${NC}"
echo ""
echo -e "${YELLOW}Note: To monitor progress from another terminal:${NC}"
echo -e "  ${BLUE}tail -f /Users/albin/Desktop/chicago-bi-app/backfill/backfill_q2_2020_resilient_*.log${NC}"
echo ""

# Change to backfill directory
cd /Users/albin/Desktop/chicago-bi-app/backfill

# Start with caffeinate to prevent system sleep
# -s: prevent system sleep
# -i: prevent idle sleep
caffeinate -s -i ./quarterly_backfill_q2_2020_resilient.sh all

# Capture exit code
EXIT_CODE=$?

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}✅ Q2 2020 backfill completed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review the log file for any issues"
    echo "2. Run data quality validation queries"
    echo "3. Compare Q1 vs Q2 volumes to analyze COVID impact"
else
    echo -e "${YELLOW}⚠️  Backfill ended with status: ${EXIT_CODE}${NC}"
    echo -e "${YELLOW}Check the log file for details.${NC}"
fi

exit $EXIT_CODE
