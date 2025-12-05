#!/bin/bash
#
# Deploy Authenticated TNP Trips Extractor
# This script deploys the TNP trips extractor with SODA API authentication
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
JOB_NAME="extractor-tnp"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${JOB_NAME}"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Deploy Authenticated TNP Trips Extractor${NC}"
echo -e "${BLUE}================================================${NC}"
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

# Step 1: Verify dependencies
print_section "Step 1: Verify Go Dependencies"

print_info "Running go mod tidy..."
go mod tidy

print_success "Dependencies verified"

# Step 2: Test authentication
print_section "Step 2: Test Authentication"

print_info "Testing if secrets are accessible..."

# Check if secrets exist
if gcloud secrets describe socrata-key-id --project=$PROJECT_ID &>/dev/null; then
    print_success "Secret 'socrata-key-id' exists"
else
    print_error "Secret 'socrata-key-id' NOT found!"
    echo "Please set up secrets first. See: docs/SOCRATA_SECRETS_USAGE.md"
    exit 1
fi

if gcloud secrets describe socrata-key-secret --project=$PROJECT_ID &>/dev/null; then
    print_success "Secret 'socrata-key-secret' exists"
else
    print_error "Secret 'socrata-key-secret' NOT found!"
    echo "Please set up secrets first. See: docs/SOCRATA_SECRETS_USAGE.md"
    exit 1
fi

# Quick test API call
print_info "Testing Socrata API with authentication (TNP dataset)..."

KEY_ID=$(gcloud secrets versions access latest --secret="socrata-key-id" --project=$PROJECT_ID)
KEY_SECRET=$(gcloud secrets versions access latest --secret="socrata-key-secret" --project=$PROJECT_ID)

RESPONSE=$(curl -s -w "\n%{http_code}" -u "$KEY_ID:$KEY_SECRET" \
    "https://data.cityofchicago.org/resource/m6dm-c72p.json?\$limit=1" 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
    print_success "Authentication test successful! (HTTP $HTTP_CODE)"
    print_success "Rate limit: 5,000+ requests/hour enabled"
else
    print_error "Authentication test failed (HTTP $HTTP_CODE)"
    echo "Response: $(echo "$RESPONSE" | head -n-1)"
    exit 1
fi

# Step 3: Build Docker image
print_section "Step 3: Build Docker Image"

print_info "Building Docker image: $IMAGE_NAME:latest"

if docker build -t $IMAGE_NAME:latest . ; then
    print_success "Docker image built successfully"
else
    print_error "Docker build failed"
    exit 1
fi

# Step 4: Push to Container Registry
print_section "Step 4: Push to Container Registry"

print_info "Pushing image to GCR: $IMAGE_NAME:latest"

if docker push $IMAGE_NAME:latest ; then
    print_success "Image pushed to Container Registry"
else
    print_error "Docker push failed"
    exit 1
fi

# Step 5: Update Cloud Run Job
print_section "Step 5: Update Cloud Run Job"

print_info "Checking if job exists..."

if gcloud run jobs describe $JOB_NAME --region=$REGION --project=$PROJECT_ID &>/dev/null; then
    print_info "Job exists, updating..."

    gcloud run jobs update $JOB_NAME \
        --region=$REGION \
        --project=$PROJECT_ID \
        --image=$IMAGE_NAME:latest \
        --task-timeout=3600s \
        --memory=1Gi \
        --cpu=1

    print_success "Cloud Run job updated"
else
    print_info "Job doesn't exist, creating..."

    gcloud run jobs create $JOB_NAME \
        --region=$REGION \
        --project=$PROJECT_ID \
        --image=$IMAGE_NAME:latest \
        --service-account=cloud-run@${PROJECT_ID}.iam.gserviceaccount.com \
        --task-timeout=3600s \
        --memory=1Gi \
        --cpu=1 \
        --max-retries=0

    print_success "Cloud Run job created"
fi

# Step 6: Test Cloud Run execution
print_section "Step 6: Test Execution"

echo ""
echo -e "${YELLOW}Would you like to test the extractor now? (yes/no)${NC}"
read -p "> " test_now

if [ "$test_now" = "yes" ]; then
    print_info "Running test extraction for a historical date..."

    # Use a date we know has data (Q1 2020)
    TEST_DATE="2020-01-15"

    print_info "Test date: $TEST_DATE"

    gcloud run jobs execute $JOB_NAME \
        --region=$REGION \
        --project=$PROJECT_ID \
        --update-env-vars="MODE=full,START_DATE=$TEST_DATE,END_DATE=$TEST_DATE" \
        --wait

    print_success "Test execution completed"
else
    print_info "Skipping test execution"
fi

# Summary
print_section "Deployment Complete!"

echo -e "${GREEN}✅ Authenticated TNP trips extractor deployed successfully!${NC}"
echo ""
echo "Summary:"
echo "  • Image: $IMAGE_NAME:latest"
echo "  • Job: $JOB_NAME"
echo "  • Region: $REGION"
echo "  • Dataset: m6dm-c72p (Transportation Network Providers Trips)"
echo "  • Authentication: ✅ SODA API (5,000+ requests/hour)"
echo "  • Service Account: cloud-run@${PROJECT_ID}.iam.gserviceaccount.com"
echo ""
echo "Next steps:"
echo "  1. Run Q1 2020 backfill for TNP:"
echo "     cd ~/Desktop/chicago-bi-app/backfill"
echo "     ./quarterly_backfill_q1_2020.sh tnp"
echo ""
echo "  2. Or test a single date:"
echo "     gcloud run jobs execute $JOB_NAME \\"
echo "       --region=$REGION \\"
echo "       --update-env-vars=START_DATE=2020-01-01,END_DATE=2020-01-01"
echo ""
echo -e "${BLUE}================================================${NC}"
echo ""
