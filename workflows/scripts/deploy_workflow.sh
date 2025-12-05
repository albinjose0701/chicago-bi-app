#!/bin/bash
#
# Deploy Cloud Workflows for Quarterly Backfill
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
PROJECT_ID="chicago-bi-app-msds-432-476520"
REGION="us-central1"
WORKFLOW_NAME="quarterly-backfill-workflow"
WORKFLOW_FILE="quarterly_backfill_workflow.yaml"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Deploy Cloud Workflows for Backfill${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Enable Workflows API
echo -e "${YELLOW}Enabling Workflows API...${NC}"
gcloud services enable workflows.googleapis.com --project=${PROJECT_ID}
gcloud services enable workflowexecutions.googleapis.com --project=${PROJECT_ID}

# Deploy workflow
echo -e "${YELLOW}Deploying workflow: ${WORKFLOW_NAME}${NC}"
gcloud workflows deploy ${WORKFLOW_NAME} \
  --source=${WORKFLOW_FILE} \
  --location=${REGION} \
  --project=${PROJECT_ID} \
  --service-account=cloud-run@${PROJECT_ID}.iam.gserviceaccount.com

echo ""
echo -e "${GREEN}✅ Workflow deployed successfully!${NC}"
echo ""
echo "To execute the workflow:"
echo "  gcloud workflows execute ${WORKFLOW_NAME} --location=${REGION} --data='{\"dataset\":\"taxi\"}'"
echo ""
echo "To view workflow executions:"
echo "  gcloud workflows executions list ${WORKFLOW_NAME} --location=${REGION}"
echo ""
echo "To view execution details:"
echo "  gcloud workflows executions describe <EXECUTION_ID> --workflow=${WORKFLOW_NAME} --location=${REGION}"
echo ""
