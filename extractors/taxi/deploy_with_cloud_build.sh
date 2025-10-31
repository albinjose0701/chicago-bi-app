#!/bin/bash
#
# Deploy Authenticated Taxi Extractor using Cloud Build
# This method avoids local Docker authentication issues
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
JOB_NAME="extractor-taxi"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${JOB_NAME}"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Deploy Authenticated Taxi Extractor${NC}"
echo -e "${BLUE}(Using Cloud Build - No Docker Auth Issues!)${NC}"
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

# Step 1: Backup original files
print_section "Step 1: Backup Original Files"

if [ -f "main_no_auth.go" ]; then
    print_info "Backup already exists, skipping..."
else
    cp main.go main_no_auth.go
    cp go.mod go_no_auth.mod
    print_success "Backed up main.go → main_no_auth.go"
    print_success "Backed up go.mod → go_no_auth.mod"
fi

# Step 2: Replace with authenticated version
print_section "Step 2: Replace with Authenticated Version"

if [ ! -f "main_with_auth.go" ]; then
    print_error "main_with_auth.go not found!"
    echo "Please ensure you have the authenticated version in this directory."
    exit 1
fi

cp main_with_auth.go main.go
cp go_with_auth.mod go.mod

print_success "Replaced main.go with authenticated version"
print_success "Replaced go.mod with updated dependencies"

# Step 3: Update dependencies
print_section "Step 3: Update Go Dependencies"

print_info "Running go mod tidy..."
go mod tidy

print_success "Dependencies updated"

# Step 4: Test authentication
print_section "Step 4: Test Authentication"

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
print_info "Testing Socrata API with authentication..."

KEY_ID=$(gcloud secrets versions access latest --secret="socrata-key-id" --project=$PROJECT_ID)
KEY_SECRET=$(gcloud secrets versions access latest --secret="socrata-key-secret" --project=$PROJECT_ID)

RESPONSE=$(curl -s -w "\n%{http_code}" -u "$KEY_ID:$KEY_SECRET" \
    "https://data.cityofchicago.org/resource/wrvz-psew.json?\$limit=1" 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
    print_success "Authentication test successful! (HTTP $HTTP_CODE)"
    print_success "Rate limit: 5,000+ requests/hour enabled"
else
    print_error "Authentication test failed (HTTP $HTTP_CODE)"
    echo "Response: $(echo "$RESPONSE" | head -n-1)"
    exit 1
fi

# Step 5: Enable Cloud Build API
print_section "Step 5: Enable Cloud Build API"

print_info "Enabling Cloud Build API..."
gcloud services enable cloudbuild.googleapis.com --project=$PROJECT_ID
print_success "Cloud Build API enabled"

# Step 6: Build using Cloud Build (NO LOCAL DOCKER NEEDED!)
print_section "Step 6: Build Image with Cloud Build"

print_info "Building Docker image using Cloud Build..."
print_info "This runs in the cloud - no local Docker authentication needed!"

gcloud builds submit --tag $IMAGE_NAME:latest --project=$PROJECT_ID .

print_success "Image built and pushed to Container Registry"
print_info "Image: $IMAGE_NAME:latest"

# Step 7: Update Cloud Run Job
print_section "Step 7: Update Cloud Run Job"

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

# Step 8: Test Cloud Run execution
print_section "Step 8: Test Execution"

echo ""
echo -e "${YELLOW}Would you like to test the extractor now? (yes/no)${NC}"
read -p "> " test_now

if [ "$test_now" = "yes" ]; then
    print_info "Running test extraction for yesterday's date..."

    YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)

    print_info "Test date: $YESTERDAY"

    gcloud run jobs execute $JOB_NAME \
        --region=$REGION \
        --project=$PROJECT_ID \
        --update-env-vars="MODE=full,START_DATE=$YESTERDAY,END_DATE=$YESTERDAY" \
        --wait

    print_success "Test execution completed"
else
    print_info "Skipping test execution"
fi

# Summary
print_section "Deployment Complete!"

echo -e "${GREEN}✅ Authenticated extractor deployed successfully!${NC}"
echo ""
echo "Summary:"
echo "  • Build Method: Cloud Build (no Docker auth issues!)"
echo "  • Image: $IMAGE_NAME:latest"
echo "  • Job: $JOB_NAME"
echo "  • Region: $REGION"
echo "  • Authentication: ✅ SODA API (5,000+ requests/hour)"
echo "  • Service Account: cloud-run@${PROJECT_ID}.iam.gserviceaccount.com"
echo ""
echo "Next steps:"
echo "  1. Run Q1 2020 backfill:"
echo "     cd ~/Desktop/chicago-bi-app/backfill"
echo "     ./quarterly_backfill_q1_2020.sh all"
echo ""
echo "  2. Or test a single date:"
echo "     gcloud run jobs execute $JOB_NAME \\"
echo "       --region=$REGION \\"
echo "       --update-env-vars=START_DATE=2020-01-01,END_DATE=2020-01-01"
echo ""
echo -e "${BLUE}================================================${NC}"
echo ""
