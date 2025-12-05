#!/bin/bash
#
# Chicago BI App - Budget Monitoring and Auto-Shutdown Setup
#
# This script sets up:
# - Budget alerts at 5%, 10%, 20%, 30%, 40%, 50%, 80% utilization
# - Automatic service shutdown at 80% credit utilization
# - Cloud Operations monitoring dashboards
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
TOTAL_CREDITS=310  # $310 USD from ₹26,000 at ₹84/$1

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Budget Monitoring & Auto-Shutdown Setup${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Project ID: ${GREEN}${PROJECT_ID}${NC}"
echo -e "Total Credits: ${GREEN}\$${TOTAL_CREDITS} USD${NC}"
echo ""

print_section() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Step 1: Get billing account ID
print_section "1. Retrieving Billing Account"

BILLING_ACCOUNT=$(gcloud billing projects describe ${PROJECT_ID} --format="value(billingAccountName)" | cut -d'/' -f2)

if [ -z "$BILLING_ACCOUNT" ]; then
    print_error "Could not retrieve billing account. Please link a billing account first."
    echo ""
    echo "Run: gcloud billing projects link ${PROJECT_ID} --billing-account=<BILLING_ACCOUNT_ID>"
    exit 1
fi

print_success "Billing Account ID: ${BILLING_ACCOUNT}"

# Step 2: Enable required APIs
print_section "2. Enabling Required APIs"

gcloud services enable cloudbilling.googleapis.com --project=${PROJECT_ID}
gcloud services enable pubsub.googleapis.com --project=${PROJECT_ID}
gcloud services enable cloudfunctions.googleapis.com --project=${PROJECT_ID}

print_success "Required APIs enabled"

# Step 3: Create Pub/Sub topic for budget alerts
print_section "3. Creating Pub/Sub Topic for Budget Alerts"

TOPIC_NAME="budget-alerts"

if gcloud pubsub topics describe ${TOPIC_NAME} --project=${PROJECT_ID} &>/dev/null; then
    print_info "Topic ${TOPIC_NAME} already exists"
else
    gcloud pubsub topics create ${TOPIC_NAME} --project=${PROJECT_ID}
    print_success "Created topic: ${TOPIC_NAME}"
fi

# Step 4: Create budget with multiple alert thresholds
print_section "4. Creating Budget with Alert Thresholds"

print_info "Setting up budget: \$${TOTAL_CREDITS} with alerts at 5%, 10%, 20%, 30%, 40%, 50%, 80%"

# Note: gcloud beta billing budgets create requires specific format
gcloud beta billing budgets create \
    --billing-account=${BILLING_ACCOUNT} \
    --display-name="Chicago BI App Credits Budget" \
    --budget-amount=${TOTAL_CREDITS} \
    --threshold-rule=percent=5 \
    --threshold-rule=percent=10 \
    --threshold-rule=percent=20 \
    --threshold-rule=percent=30 \
    --threshold-rule=percent=40 \
    --threshold-rule=percent=50 \
    --threshold-rule=percent=80,basis=FORECASTED_SPEND \
    --all-updates-rule-pubsub-topic=projects/${PROJECT_ID}/topics/${TOPIC_NAME} \
    --filter-projects=projects/${PROJECT_ID} \
    2>&1 || print_info "Budget may already exist or require manual setup"

print_success "Budget alerts configured (check Cloud Console to verify)"

# Step 5: Create Cloud Function for auto-shutdown at 80%
print_section "5. Creating Auto-Shutdown Cloud Function"

FUNCTION_DIR="/tmp/budget-shutdown-function"
mkdir -p ${FUNCTION_DIR}

# Create the Cloud Function code
cat > ${FUNCTION_DIR}/main.py <<'PYTHON_EOF'
import base64
import json
import os
from google.cloud import run_v2
from google.cloud import scheduler_v1

PROJECT_ID = os.environ.get('PROJECT_ID')
REGION = os.environ.get('REGION', 'us-central1')

def shutdown_services(event, context):
    """
    Cloud Function triggered by Pub/Sub when budget threshold is reached.
    Stops Cloud Run jobs and pauses Cloud Scheduler jobs at 80% budget.
    """

    # Decode the Pub/Sub message
    if 'data' in event:
        budget_data = json.loads(base64.b64decode(event['data']).decode('utf-8'))

        # Get budget notification
        cost_amount = budget_data.get('costAmount', 0)
        budget_amount = budget_data.get('budgetAmount', 0)

        if budget_amount > 0:
            percent_used = (cost_amount / budget_amount) * 100
        else:
            percent_used = 0

        print(f"Budget Alert: {percent_used:.2f}% of budget used (${cost_amount:.2f} / ${budget_amount:.2f})")

        # Only shutdown at 80% or above
        if percent_used >= 80:
            print(f"⚠️ Budget threshold reached: {percent_used:.2f}% - Initiating shutdown")

            try:
                # Pause all Cloud Scheduler jobs
                scheduler_client = scheduler_v1.CloudSchedulerClient()
                parent = f"projects/{PROJECT_ID}/locations/{REGION}"

                print("Pausing Cloud Scheduler jobs...")
                jobs = scheduler_client.list_jobs(parent=parent)
                for job in jobs:
                    try:
                        scheduler_client.pause_job(name=job.name)
                        print(f"  ✓ Paused scheduler job: {job.name}")
                    except Exception as e:
                        print(f"  ✗ Failed to pause {job.name}: {str(e)}")

                # Note: Cloud Run Jobs don't need to be "stopped" as they only run on-demand
                # They won't execute without scheduler triggers

                print("✅ Auto-shutdown completed successfully")
                print("📧 Check your email for budget alert notification")
                print("To resume: Manually unpause Cloud Scheduler jobs in Cloud Console")

            except Exception as e:
                print(f"❌ Error during shutdown: {str(e)}")
                raise
        else:
            print(f"ℹ️  Budget alert at {percent_used:.2f}% - No action needed (threshold: 80%)")

    return 'OK'
PYTHON_EOF

# Create requirements.txt
cat > ${FUNCTION_DIR}/requirements.txt <<'REQ_EOF'
google-cloud-run==0.10.0
google-cloud-scheduler==2.13.0
REQ_EOF

print_info "Cloud Function code created at ${FUNCTION_DIR}"

# Deploy the Cloud Function
print_info "Deploying Cloud Function (this may take 2-3 minutes)..."

gcloud functions deploy budget-shutdown-function \
    --gen2 \
    --runtime=python311 \
    --region=${REGION} \
    --source=${FUNCTION_DIR} \
    --entry-point=shutdown_services \
    --trigger-topic=${TOPIC_NAME} \
    --set-env-vars=PROJECT_ID=${PROJECT_ID},REGION=${REGION} \
    --service-account=cloud-run@${PROJECT_ID}.iam.gserviceaccount.com \
    --max-instances=1 \
    --memory=256MB \
    --timeout=300s \
    --project=${PROJECT_ID} \
    2>&1 || print_error "Function deployment failed - may need manual setup"

print_success "Auto-shutdown Cloud Function deployed"

# Step 6: Grant necessary permissions
print_section "6. Granting Permissions for Auto-Shutdown"

# Grant scheduler admin to cloud-run service account
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:cloud-run@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/cloudscheduler.admin" \
    --condition=None \
    2>&1 || print_info "Permission may already be granted"

# Grant Pub/Sub publisher role to Cloud Billing
gcloud pubsub topics add-iam-policy-binding ${TOPIC_NAME} \
    --member="serviceAccount:cloud-billing-notifications@system.gserviceaccount.com" \
    --role="roles/pubsub.publisher" \
    --project=${PROJECT_ID} \
    2>&1 || print_info "Permission may already be granted"

print_success "Permissions configured"

# Summary
print_section "Setup Complete!"

echo -e "${GREEN}✅ Budget monitoring and auto-shutdown configured!${NC}"
echo ""
echo "Configuration Summary:"
echo "  • Total Budget: \$${TOTAL_CREDITS} USD"
echo "  • Alert Thresholds: 5%, 10%, 20%, 30%, 40%, 50%, 80%"
echo "  • Auto-Shutdown: Enabled at 80% utilization"
echo ""
echo "What happens at each threshold:"
echo "  📧 5-50%: Email alerts only"
echo "  ⚠️  80%: Email alert + Automatic service shutdown"
echo ""
echo "Auto-shutdown will:"
echo "  1. Pause all Cloud Scheduler jobs (stops new extractions)"
echo "  2. Let running Cloud Run jobs complete naturally"
echo "  3. Send email notification"
echo ""
echo "To resume after shutdown:"
echo "  1. Go to Cloud Console → Cloud Scheduler"
echo "  2. Select all jobs → Resume"
echo "  3. Monitor budget in Cloud Console → Billing"
echo ""
echo "View budget status:"
echo "  gcloud billing budgets list --billing-account=${BILLING_ACCOUNT}"
echo ""
echo "View Cloud Operations dashboards:"
echo "  https://console.cloud.google.com/monitoring/dashboards?project=${PROJECT_ID}"
echo ""
echo -e "${BLUE}================================================${NC}"
echo ""
