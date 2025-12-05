#!/bin/bash
#
# 4-Way Parallel October 2025 Extraction (Oct 5-31)
# Ultra-optimized with 3s delays
#

set -e

PROJECT_ID="chicago-bi-app-msds-432-476520"
REGION="us-central1"
JOB_NAME="extractor-taxi"
DELAY=3

echo "Starting 4-way parallel extraction for Oct 5-31, 2025"
echo "Delay between calls: ${DELAY}s"
echo ""

# Batch 1: Oct 5-11 (7 dates)
(
  for day in 5 6 7 8 9 10 11; do
    DATE="2025-10-$(printf '%02d' $day)"
    echo "[Batch 1] Extracting $DATE"
    gcloud run jobs execute "$JOB_NAME" \
      --project="$PROJECT_ID" \
      --region="$REGION" \
      --update-env-vars="START_DATE=${DATE},DATASET=taxi" \
      --wait --quiet
    echo "[Batch 1] ✅ $DATE complete"
    sleep $DELAY
  done
  echo "[Batch 1] FINISHED"
) &

# Batch 2: Oct 12-18 (7 dates)
(
  for day in 12 13 14 15 16 17 18; do
    DATE="2025-10-$(printf '%02d' $day)"
    echo "[Batch 2] Extracting $DATE"
    gcloud run jobs execute "$JOB_NAME" \
      --project="$PROJECT_ID" \
      --region="$REGION" \
      --update-env-vars="START_DATE=${DATE},DATASET=taxi" \
      --wait --quiet
    echo "[Batch 2] ✅ $DATE complete"
    sleep $DELAY
  done
  echo "[Batch 2] FINISHED"
) &

# Batch 3: Oct 19-25 (7 dates)
(
  for day in 19 20 21 22 23 24 25; do
    DATE="2025-10-$(printf '%02d' $day)"
    echo "[Batch 3] Extracting $DATE"
    gcloud run jobs execute "$JOB_NAME" \
      --project="$PROJECT_ID" \
      --region="$REGION" \
      --update-env-vars="START_DATE=${DATE},DATASET=taxi" \
      --wait --quiet
    echo "[Batch 3] ✅ $DATE complete"
    sleep $DELAY
  done
  echo "[Batch 3] FINISHED"
) &

# Batch 4: Oct 26-31 (6 dates)
(
  for day in 26 27 28 29 30 31; do
    DATE="2025-10-$(printf '%02d' $day)"
    echo "[Batch 4] Extracting $DATE"
    gcloud run jobs execute "$JOB_NAME" \
      --project="$PROJECT_ID" \
      --region="$REGION" \
      --update-env-vars="START_DATE=${DATE},DATASET=taxi" \
      --wait --quiet
    echo "[Batch 4] ✅ $DATE complete"
    sleep $DELAY
  done
  echo "[Batch 4] FINISHED"
) &

# Wait for all batches to complete
wait

echo ""
echo "=============================="
echo "All 4 batches complete!"
echo "Extracted Oct 5-31, 2025"
echo "=============================="
