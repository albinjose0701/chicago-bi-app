#!/bin/bash

# Extract October 3-31, 2025
PROJECT_ID="chicago-bi-app-msds-432-476520"
REGION="us-central1"
JOB_NAME="extractor-taxi"

for day in {3..31}; do
  DATE_STR="2025-10-$(printf '%02d' $day)"
  echo "=== Extracting $DATE_STR ==="

  gcloud run jobs execute "$JOB_NAME" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --update-env-vars="START_DATE=${DATE_STR},DATASET=taxi" \
    --wait --quiet

  echo "Completed $DATE_STR"
  sleep 2
done

echo "All extractions complete!"
