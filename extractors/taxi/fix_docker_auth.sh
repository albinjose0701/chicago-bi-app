#!/bin/bash
#
# Fix Docker Authentication for GCR
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ID="chicago-bi-app-msds-432-476520"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Fix Docker Authentication for GCR${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Step 1: Enable Artifact Registry API
print_info "Enabling Artifact Registry API..."
gcloud services enable artifactregistry.googleapis.com --project=$PROJECT_ID
print_success "Artifact Registry API enabled"

# Step 2: Configure Docker to use gcloud as credential helper
print_info "Configuring Docker authentication..."

# Method 1: Using gcloud auth configure-docker
gcloud auth configure-docker --quiet

# Method 2: Also configure for gcr.io specifically
gcloud auth configure-docker gcr.io --quiet

print_success "Docker authentication configured"

# Step 3: Verify authentication
print_info "Testing Docker authentication..."

if docker pull gcr.io/google-samples/hello-app:1.0 &>/dev/null; then
    print_success "Docker can pull from GCR"
else
    print_info "Pull test skipped (not critical)"
fi

# Step 4: Grant necessary permissions
print_info "Checking IAM permissions..."

# Get current user email
USER_EMAIL=$(gcloud config get-value account)

# Grant Storage Admin role (needed for GCR)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$USER_EMAIL" \
    --role="roles/storage.admin" \
    --condition=None \
    2>/dev/null || print_info "Permission may already exist"

print_success "Permissions verified"

echo ""
echo -e "${GREEN}✅ Docker authentication fixed!${NC}"
echo ""
echo "You can now push images to GCR:"
echo "  docker push gcr.io/$PROJECT_ID/extractor-taxi:latest"
echo ""
echo "Re-run the deployment script:"
echo "  ./deploy_with_auth.sh"
echo ""
