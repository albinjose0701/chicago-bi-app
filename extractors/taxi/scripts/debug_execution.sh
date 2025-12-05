#!/bin/bash
#
# Debug Failed Cloud Run Execution
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ID="chicago-bi-app-msds-432-476520"
REGION="us-central1"
JOB_NAME="extractor-taxi"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Debug Cloud Run Job Execution${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Get the latest execution
print_info "Getting latest execution details..."
echo ""

EXECUTION_ID=$(gcloud run jobs executions list \
    --job=$JOB_NAME \
    --region=$REGION \
    --project=$PROJECT_ID \
    --limit=1 \
    --format="value(name)" | head -n1)

if [ -z "$EXECUTION_ID" ]; then
    echo -e "${RED}❌ No executions found${NC}"
    exit 1
fi

echo -e "${BLUE}Execution ID:${NC} $EXECUTION_ID"
echo ""

# Get execution details
print_info "Execution Details:"
gcloud run jobs executions describe $EXECUTION_ID \
    --region=$REGION \
    --project=$PROJECT_ID

echo ""
echo -e "${BLUE}================================================${NC}"
print_info "Viewing Logs (last 50 lines)..."
echo -e "${BLUE}================================================${NC}"
echo ""

# Get logs
gcloud logging read \
    "resource.type=cloud_run_job
     AND resource.labels.job_name=$JOB_NAME
     AND resource.labels.location=$REGION" \
    --limit=50 \
    --project=$PROJECT_ID \
    --format="table(timestamp,severity,textPayload)"

echo ""
echo -e "${BLUE}================================================${NC}"
print_info "Common Issues & Solutions:"
echo -e "${BLUE}================================================${NC}"
echo ""

echo "1. Secret not found:"
echo "   → Check: gcloud secrets list --project=$PROJECT_ID"
echo ""

echo "2. Permission denied:"
echo "   → Service account needs secretAccessor role"
echo ""

echo "3. Timeout:"
echo "   → Increase task-timeout in job configuration"
echo ""

echo "4. API rate limit:"
echo "   → Wait and retry, or add delays between calls"
echo ""

echo "5. Image not found:"
echo "   → Re-run deployment: ./deploy_with_cloud_build.sh"
echo ""

echo "View full logs in Cloud Console:"
echo "https://console.cloud.google.com/run/jobs/details/$REGION/$JOB_NAME?project=$PROJECT_ID"
echo ""
