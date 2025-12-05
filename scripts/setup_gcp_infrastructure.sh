#!/bin/bash
#
# Chicago BI App - GCP Infrastructure Setup Script
#
# This script sets up all required GCP resources for the Chicago BI project:
# - Enables required APIs
# - Creates service accounts
# - Creates Cloud Storage buckets
# - Creates BigQuery datasets
# - Sets up IAM permissions
# - Prepares for Cloud Run and Cloud Scheduler deployment
#

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_ID="chicago-bi-app-msds-432-476520"
REGION="us-central1"
ZONE="us-central1-a"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Chicago BI App - GCP Infrastructure Setup${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Project ID: ${GREEN}${PROJECT_ID}${NC}"
echo -e "Region: ${GREEN}${REGION}${NC}"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to print info messages
print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Set the active project
print_section "1. Setting Active Project"
gcloud config set project ${PROJECT_ID}
print_success "Active project set to ${PROJECT_ID}"

# Enable required APIs
print_section "2. Enabling Required GCP APIs"

APIs=(
    "run.googleapis.com"                    # Cloud Run
    "cloudbuild.googleapis.com"             # Cloud Build
    "cloudscheduler.googleapis.com"         # Cloud Scheduler
    "aiplatform.googleapis.com"             # Vertex AI (for ML forecasting)
    "compute.googleapis.com"                # Compute Engine (required by Cloud Run)
    "artifactregistry.googleapis.com"       # Artifact Registry
    "secretmanager.googleapis.com"          # Secret Manager
)

for api in "${APIs[@]}"; do
    echo "Enabling ${api}..."
    gcloud services enable ${api} --project=${PROJECT_ID} || print_info "API ${api} may already be enabled"
done

print_success "All required APIs enabled"

# Create service accounts
print_section "3. Creating Service Accounts"

# Check if geo-etl service account exists
if gcloud iam service-accounts describe geo-etl@${PROJECT_ID}.iam.gserviceaccount.com --project=${PROJECT_ID} &>/dev/null; then
    print_info "Service account geo-etl already exists"
else
    gcloud iam service-accounts create geo-etl \
        --display-name="Geo ETL Service Account" \
        --description="Service account for geospatial ETL operations" \
        --project=${PROJECT_ID}
    print_success "Created geo-etl service account"
fi

# Create scheduler service account
if gcloud iam service-accounts describe scheduler@${PROJECT_ID}.iam.gserviceaccount.com --project=${PROJECT_ID} &>/dev/null; then
    print_info "Service account scheduler already exists"
else
    gcloud iam service-accounts create scheduler \
        --display-name="Cloud Scheduler Service Account" \
        --description="Service account for Cloud Scheduler jobs" \
        --project=${PROJECT_ID}
    print_success "Created scheduler service account"
fi

# Create cloud-run service account
if gcloud iam service-accounts describe cloud-run@${PROJECT_ID}.iam.gserviceaccount.com --project=${PROJECT_ID} &>/dev/null; then
    print_info "Service account cloud-run already exists"
else
    gcloud iam service-accounts create cloud-run \
        --display-name="Cloud Run Service Account" \
        --description="Service account for Cloud Run jobs" \
        --project=${PROJECT_ID}
    print_success "Created cloud-run service account"
fi

# Grant IAM roles
print_section "4. Granting IAM Roles"

# Roles for geo-etl service account
echo "Granting roles to geo-etl service account..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:geo-etl@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataEditor" \
    --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:geo-etl@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/bigquery.jobUser" \
    --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:geo-etl@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/storage.objectAdmin" \
    --condition=None

print_success "Granted roles to geo-etl service account"

# Roles for scheduler service account
echo "Granting roles to scheduler service account..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:scheduler@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/run.invoker" \
    --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:scheduler@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/cloudscheduler.jobRunner" \
    --condition=None

print_success "Granted roles to scheduler service account"

# Roles for cloud-run service account
echo "Granting roles to cloud-run service account..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:cloud-run@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataEditor" \
    --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:cloud-run@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/bigquery.jobUser" \
    --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:cloud-run@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/storage.objectAdmin" \
    --condition=None

print_success "Granted roles to cloud-run service account"

# Create Cloud Storage buckets
print_section "5. Creating Cloud Storage Buckets"

# Landing bucket
LANDING_BUCKET="${PROJECT_ID}-landing"
if gsutil ls -b gs://${LANDING_BUCKET} &>/dev/null; then
    print_info "Bucket gs://${LANDING_BUCKET} already exists"
else
    gsutil mb -l ${REGION} -p ${PROJECT_ID} gs://${LANDING_BUCKET}
    print_success "Created bucket gs://${LANDING_BUCKET}"

    # Set lifecycle policy
    cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "SetStorageClass",
          "storageClass": "NEARLINE"
        },
        "condition": {
          "age": 30
        }
      },
      {
        "action": {
          "type": "Delete"
        },
        "condition": {
          "age": 90
        }
      }
    ]
  }
}
EOF
    gsutil lifecycle set /tmp/lifecycle.json gs://${LANDING_BUCKET}
    print_success "Set lifecycle policy on landing bucket"
fi

# Archive bucket
ARCHIVE_BUCKET="${PROJECT_ID}-archive"
if gsutil ls -b gs://${ARCHIVE_BUCKET} &>/dev/null; then
    print_info "Bucket gs://${ARCHIVE_BUCKET} already exists"
else
    gsutil mb -l ${REGION} -p ${PROJECT_ID} gs://${ARCHIVE_BUCKET}
    print_success "Created bucket gs://${ARCHIVE_BUCKET}"

    # Set lifecycle policy for archive
    cat > /tmp/archive_lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "SetStorageClass",
          "storageClass": "ARCHIVE"
        },
        "condition": {
          "age": 365
        }
      }
    ]
  }
}
EOF
    gsutil lifecycle set /tmp/archive_lifecycle.json gs://${ARCHIVE_BUCKET}
    print_success "Set lifecycle policy on archive bucket"
fi

# Create BigQuery datasets
print_section "6. Creating BigQuery Datasets"

DATASETS=("raw_data" "cleaned_data" "analytics" "reference" "monitoring")
DESCRIPTIONS=(
    "Bronze layer - Raw ingested data with full lineage"
    "Silver layer - Cleaned and validated data"
    "Gold layer - Pre-aggregated analytics and metrics"
    "Reference and dimension tables"
    "Operational monitoring and data quality metrics"
)

for i in "${!DATASETS[@]}"; do
    dataset="${DATASETS[$i]}"
    description="${DESCRIPTIONS[$i]}"

    if bq ls -d ${dataset} --project_id=${PROJECT_ID} &>/dev/null; then
        print_info "Dataset ${dataset} already exists"
    else
        bq mk --dataset \
            --location=${REGION} \
            --description="${description}" \
            ${PROJECT_ID}:${dataset}
        print_success "Created dataset ${dataset}"
    fi
done

# Skip table creation - user will define schema later
print_section "7. Skipping Table Creation"

print_info "Table schemas will be created later after data model finalization"
print_info "Use Cloud Operations UI for monitoring instead of custom tables"

# Summary
print_section "Setup Complete!"

echo -e "${GREEN}✅ GCP Infrastructure setup completed successfully!${NC}"
echo ""
echo "Summary of created resources:"
echo "  • Service Accounts: geo-etl, scheduler, cloud-run"
echo "  • Cloud Storage: gs://${LANDING_BUCKET}, gs://${ARCHIVE_BUCKET}"
echo "  • BigQuery Datasets: raw_data, cleaned_data, analytics, reference, monitoring (empty - no tables yet)"
echo ""
echo "Next steps:"
echo ""
echo "  1. ${YELLOW}IMPORTANT${NC}: Set up budget monitoring and auto-shutdown:"
echo "     ${GREEN}./setup_budget_shutdown.sh${NC}"
echo "     (Sets alerts at 5%, 10%, 20%, 30%, 40%, 50%, 80% with auto-shutdown at 80%)"
echo ""
echo "  2. Access Cloud Operations UI for monitoring:"
echo "     https://console.cloud.google.com/monitoring/dashboards?project=${PROJECT_ID}"
echo ""
echo "  3. Build and deploy Cloud Run extractors:"
echo "     cd extractors/taxi"
echo "     gcloud builds submit --tag gcr.io/${PROJECT_ID}/extractor-taxi"
echo "     gcloud run jobs create extractor-taxi --image gcr.io/${PROJECT_ID}/extractor-taxi --region ${REGION}"
echo ""
echo "  4. Upload geospatial reference data to BigQuery:"
echo "     cd geospatial/geopandas"
echo "     python generate_zip_boundaries.py --project-id ${PROJECT_ID}"
echo ""
echo "  5. Set up Cloud Scheduler jobs:"
echo "     cd scheduler"
echo "     ./daily_extract.sh"
echo ""
echo "  6. Define your data model and create tables when ready"
echo ""
echo -e "${BLUE}================================================${NC}"
echo ""
