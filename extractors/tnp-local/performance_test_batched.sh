#!/bin/bash
#
# TNP Performance Test - Batched Cloud Run Execution
# Tests 2 weeks (Jan 1-14, 2020) in batches of 3 jobs
#

set -e

# Configuration
PROJECT_ID="chicago-bi-app-msds-432-476520"
REGION="us-central1"
JOB_NAME="extractor-tnp"
BATCH_SIZE=3

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Test dates (Jan 1-14, 2020)
DATES=(
    "2020-01-01"
    "2020-01-02"
    "2020-01-03"
    "2020-01-04"
    "2020-01-05"
    "2020-01-06"
    "2020-01-07"
    "2020-01-08"
    "2020-01-09"
    "2020-01-10"
    "2020-01-11"
    "2020-01-12"
    "2020-01-13"
    "2020-01-14"
)

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}TNP Performance Test - Cloud Run (Batched)${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Test Period: ${GREEN}Jan 1-14, 2020 (14 days)${NC}"
echo -e "Batch Size: ${GREEN}${BATCH_SIZE} parallel jobs${NC}"
echo -e "Total Batches: ${GREEN}$((${#DATES[@]} / BATCH_SIZE + 1))${NC}"
echo -e "Project: ${GREEN}${PROJECT_ID}${NC}"
echo ""

# Log file
LOG_FILE="performance_test_$(date +%Y%m%d_%H%M%S).log"
echo "Performance Test Log" > "$LOG_FILE"
echo "Start Time: $(date)" >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"

START_TIME=$(date +%s)

# Process dates in batches
batch_num=1
for ((i=0; i<${#DATES[@]}; i+=BATCH_SIZE)); do
    batch_dates=("${DATES[@]:i:BATCH_SIZE}")

    echo -e "${YELLOW}Batch ${batch_num}: Processing ${#batch_dates[@]} dates...${NC}"
    echo "Batch ${batch_num}: ${batch_dates[*]}" >> "$LOG_FILE"

    # Launch jobs in parallel (in background)
    batch_start=$(date +%s)
    pids=()

    for date in "${batch_dates[@]}"; do
        echo -e "  ${BLUE}→${NC} Launching job for ${date}..."

        (
            gcloud run jobs execute "${JOB_NAME}" \
                --region="${REGION}" \
                --project="${PROJECT_ID}" \
                --update-env-vars="MODE=full,START_DATE=${date},END_DATE=${date}" \
                --wait \
                >> "${LOG_FILE}.${date}.txt" 2>&1

            exit_code=$?
            if [ $exit_code -eq 0 ]; then
                echo "  ${GREEN}✅${NC} ${date} completed successfully"
            else
                echo "  ${RED}❌${NC} ${date} failed (exit code: $exit_code)"
            fi
        ) &

        pids+=($!)
        sleep 3  # Small delay between launches to avoid rate limits
    done

    # Wait for all jobs in this batch to complete
    echo -e "  ${YELLOW}⏳${NC} Waiting for batch ${batch_num} jobs to complete..."

    for pid in "${pids[@]}"; do
        wait "$pid"
    done

    batch_duration=$(($(date +%s) - batch_start))
    echo -e "  ${GREEN}✅${NC} Batch ${batch_num} completed in ${batch_duration}s"
    echo "Batch ${batch_num} duration: ${batch_duration}s" >> "$LOG_FILE"

    # Wait before next batch (to avoid rate limits)
    if [ $((i + BATCH_SIZE)) -lt ${#DATES[@]} ]; then
        echo -e "  ${YELLOW}⏸${NC}  Waiting 10s before next batch..."
        sleep 10
    fi

    ((batch_num++))
done

TOTAL_DURATION=$(($(date +%s) - START_TIME))

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Performance Test Complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Total Duration: ${GREEN}${TOTAL_DURATION}s ($(echo "scale=2; $TOTAL_DURATION/60" | bc)m)${NC}"
echo -e "Days Processed: ${GREEN}${#DATES[@]}${NC}"
echo -e "Average per Day: ${GREEN}$(echo "scale=2; $TOTAL_DURATION/${#DATES[@]}" | bc)s${NC}"
echo ""

echo "---" >> "$LOG_FILE"
echo "End Time: $(date)" >> "$LOG_FILE"
echo "Total Duration: ${TOTAL_DURATION}s" >> "$LOG_FILE"

echo -e "${YELLOW}📊 Next Steps:${NC}"
echo ""
echo "1. View execution logs:"
echo "   gcloud logging read 'resource.type=cloud_run_job AND resource.labels.job_name=extractor-tnp AND timestamp>=\"$(date -u -d '5 minutes ago' '+%Y-%m-%dT%H:%M:%SZ')\"' --limit=500 --format=json --project=${PROJECT_ID}"
echo ""
echo "2. Check BigQuery for data:"
echo "   bq query --use_legacy_sql=false \"SELECT DATE(trip_start_timestamp) AS date, COUNT(*) as trips FROM \\\`${PROJECT_ID}.raw_data.raw_tnp_trips\\\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-01-14' GROUP BY date ORDER BY date\""
echo ""
echo "3. Analyze performance metrics:"
echo "   grep 'Duration\\|trips' ${LOG_FILE}"
echo ""

echo -e "${GREEN}✅ Performance test completed! Log saved to: ${LOG_FILE}${NC}"
