#!/bin/bash
#
# Daily Extraction Schedule - Cloud Scheduler Setup
# Creates cron jobs to trigger Cloud Run extractors daily at 3 AM Central
#

set -e

PROJECT_ID="${PROJECT_ID:-chicago-bi}"
REGION="${REGION:-us-central1}"
SERVICE_ACCOUNT="scheduler@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Setting up Cloud Scheduler for daily extraction..."
echo "Project: $PROJECT_ID"
echo "Region: $REGION"

# Function to create scheduler job
create_scheduler_job() {
    local job_name=$1
    local cloud_run_job=$2
    local schedule=$3
    local description=$4

    echo "Creating scheduler job: $job_name"

    gcloud scheduler jobs create http "$job_name" \
        --location="$REGION" \
        --schedule="$schedule" \
        --time-zone="America/Chicago" \
        --uri="https://${REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${PROJECT_ID}/jobs/${cloud_run_job}:run" \
        --http-method=POST \
        --oidc-service-account-email="$SERVICE_ACCOUNT" \
        --description="$description" \
        --max-retry-attempts=3 \
        --min-backoff=5s \
        --max-backoff=300s \
        || echo "Job $job_name may already exist, updating..."

    # If creation failed, try updating
    if [ $? -ne 0 ]; then
        gcloud scheduler jobs update http "$job_name" \
            --location="$REGION" \
            --schedule="$schedule" \
            --time-zone="America/Chicago" \
            --uri="https://${REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${PROJECT_ID}/jobs/${cloud_run_job}:run" \
            --http-method=POST \
            --oidc-service-account-email="$SERVICE_ACCOUNT" \
            --description="$description"
    fi
}

# Create scheduler jobs
create_scheduler_job \
    "daily-taxi-extract" \
    "extractor-taxi" \
    "0 8 * * *" \
    "Daily taxi trip extraction at 3 AM Central"

create_scheduler_job \
    "daily-tnp-extract" \
    "extractor-tnp" \
    "15 8 * * *" \
    "Daily TNP permit extraction at 3:15 AM Central"

create_scheduler_job \
    "daily-covid-extract" \
    "extractor-covid" \
    "30 8 * * *" \
    "Daily COVID-19 data extraction at 3:30 AM Central"

create_scheduler_job \
    "daily-permits-extract" \
    "extractor-permits" \
    "45 8 * * *" \
    "Daily building permit extraction at 3:45 AM Central"

echo ""
echo "✅ Cloud Scheduler jobs created successfully!"
echo ""
echo "List all jobs:"
echo "  gcloud scheduler jobs list --location=$REGION"
echo ""
echo "Run job manually:"
echo "  gcloud scheduler jobs run daily-taxi-extract --location=$REGION"
echo ""
echo "View logs:"
echo "  gcloud logging read 'resource.type=cloud_scheduler_job' --limit 50"
