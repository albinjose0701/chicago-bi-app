#!/bin/bash
# Deploy Building Permits Pipeline to Cloud Run
# This script creates the Cloud Run job and sets up weekly scheduling

set -e  # Exit on error

PROJECT_ID="chicago-bi-app-msds-432-476520"
REGION="us-central1"
JOB_NAME="permits-pipeline"
SERVICE_ACCOUNT="chicago-bi-app@${PROJECT_ID}.iam.gserviceaccount.com"

echo "================================================================================"
echo "DEPLOYING BUILDING PERMITS PIPELINE"
echo "================================================================================"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Job Name: $JOB_NAME"
echo ""

# Step 1: Build and push the container
echo "Step 1/4: Building container image..."
gcloud builds submit \
  --config=cloudbuild.yaml \
  --project=$PROJECT_ID \
  --region=$REGION

echo "✓ Container built and pushed"
echo ""

# Step 2: Create Cloud Run job (if it doesn't exist)
echo "Step 2/4: Creating/Updating Cloud Run job..."

if gcloud run jobs describe $JOB_NAME --region=$REGION --project=$PROJECT_ID &> /dev/null; then
  echo "Job already exists. It was updated by the build step."
else
  echo "Creating new Cloud Run job..."
  gcloud run jobs create $JOB_NAME \
    --image=gcr.io/$PROJECT_ID/permits-pipeline:latest \
    --region=$REGION \
    --project=$PROJECT_ID \
    --max-retries=1 \
    --task-timeout=10m \
    --memory=1Gi \
    --cpu=1 \
    --service-account=$SERVICE_ACCOUNT
fi

echo "✓ Cloud Run job ready"
echo ""

# Step 3: Create Cloud Scheduler job for weekly execution
echo "Step 3/4: Setting up Cloud Scheduler (weekly execution)..."

SCHEDULER_JOB_NAME="permits-pipeline-weekly"

# Delete existing scheduler if it exists
if gcloud scheduler jobs describe $SCHEDULER_JOB_NAME --location=$REGION --project=$PROJECT_ID &> /dev/null; then
  echo "Deleting existing scheduler job..."
  gcloud scheduler jobs delete $SCHEDULER_JOB_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --quiet
fi

# Create new scheduler job (every Monday at 3 AM CT = 9 AM UTC)
echo "Creating scheduler job..."
gcloud scheduler jobs create http $SCHEDULER_JOB_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --schedule="0 9 * * 1" \
  --time-zone="America/Chicago" \
  --uri="https://$REGION-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/$PROJECT_ID/jobs/$JOB_NAME:run" \
  --http-method=POST \
  --oauth-service-account-email=$SERVICE_ACCOUNT \
  --description="Weekly building permits pipeline execution (every Monday at 3 AM CT)"

echo "✓ Scheduler configured: Every Monday at 3 AM CT"
echo ""

# Step 4: Test the pipeline with manual execution
echo "Step 4/4: Testing pipeline with manual execution..."
echo "Would you like to run a test execution now? (yes/no)"
read -r response

if [[ "$response" == "yes" || "$response" == "y" ]]; then
  echo "Executing pipeline job..."
  gcloud run jobs execute $JOB_NAME \
    --region=$REGION \
    --project=$PROJECT_ID \
    --wait

  echo "✓ Test execution completed"
else
  echo "Skipping test execution. You can manually trigger it with:"
  echo "  gcloud run jobs execute $JOB_NAME --region=$REGION --project=$PROJECT_ID"
fi

echo ""
echo "================================================================================"
echo "✓ DEPLOYMENT COMPLETE"
echo "================================================================================"
echo ""
echo "Resources created:"
echo "  • Cloud Run Job: $JOB_NAME"
echo "  • Cloud Scheduler: $SCHEDULER_JOB_NAME"
echo "  • Container Image: gcr.io/$PROJECT_ID/permits-pipeline:latest"
echo ""
echo "Scheduler configuration:"
echo "  • Schedule: Every Monday at 3 AM CT (after extraction at 2 AM)"
echo "  • Cron: 0 9 * * 1 (UTC)"
echo "  • Next run: Check with 'gcloud scheduler jobs describe $SCHEDULER_JOB_NAME --location=$REGION'"
echo ""
echo "Manual execution:"
echo "  gcloud run jobs execute $JOB_NAME --region=$REGION --project=$PROJECT_ID"
echo ""
echo "View logs:"
echo "  gcloud logging read \"resource.type=cloud_run_job AND resource.labels.job_name=$JOB_NAME\" --limit 50 --format json"
echo ""
echo "================================================================================"
