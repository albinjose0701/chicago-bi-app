# Chicago BI App - Setup Guide

Complete setup instructions for deploying the Chicago Business Intelligence Platform on GCP.

---

## Prerequisites

### Required Software
- **Google Cloud SDK** (gcloud CLI) - [Install](https://cloud.google.com/sdk/docs/install)
- **Git** - Version control
- **Go 1.21+** - For building extractors
- **Python 3.9+** - For geospatial processing
- **Docker** (optional) - For local testing

### GCP Account Requirements
- GCP account with ₹26,000 educational credits
- Billing account enabled
- Project owner permissions

---

## Step 1: GCP Project Setup

### Create Project
```bash
# Set project variables
export PROJECT_ID=chicago-bi
export REGION=us-central1
export BILLING_ACCOUNT_ID=<YOUR_BILLING_ACCOUNT_ID>

# Create project
gcloud projects create $PROJECT_ID --name="Chicago BI App"

# Link billing account
gcloud billing projects link $PROJECT_ID \
  --billing-account=$BILLING_ACCOUNT_ID

# Set default project
gcloud config set project $PROJECT_ID
```

### Enable Required APIs
```bash
gcloud services enable \
  bigquery.googleapis.com \
  bigquerystorage.googleapis.com \
  run.googleapis.com \
  storage.googleapis.com \
  cloudscheduler.googleapis.com \
  cloudbuild.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  aiplatform.googleapis.com
```

---

## Step 2: Create Cloud Storage Buckets

```bash
# Landing zone for raw data
gsutil mb -l $REGION gs://${PROJECT_ID}-landing

# Archive for long-term storage
gsutil mb -l $REGION gs://${PROJECT_ID}-archive

# Set lifecycle policy on landing bucket
cat > lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {"age": 30}
      },
      {
        "action": {"type": "Delete"},
        "condition": {"age": 90}
      }
    ]
  }
}
EOF

gsutil lifecycle set lifecycle.json gs://${PROJECT_ID}-landing
```

---

## Step 3: Create BigQuery Datasets

```bash
# Create datasets
bq mk --dataset \
  --location=$REGION \
  --description="Bronze layer - Raw data" \
  ${PROJECT_ID}:raw_data

bq mk --dataset \
  --location=$REGION \
  --description="Silver layer - Cleaned data" \
  ${PROJECT_ID}:cleaned_data

bq mk --dataset \
  --location=$REGION \
  --description="Gold layer - Analytics" \
  ${PROJECT_ID}:analytics

bq mk --dataset \
  --location=$REGION \
  --description="Reference dimension tables" \
  ${PROJECT_ID}:reference

bq mk --dataset \
  --location=$REGION \
  --description="Monitoring and operations" \
  ${PROJECT_ID}:monitoring

# Create tables from schemas
bq query --use_legacy_sql=false < bigquery/schemas/bronze_layer.sql
```

---

## Step 4: Build and Deploy Extractors

### Build Taxi Extractor
```bash
cd extractors/taxi

# Build container
gcloud builds submit \
  --tag gcr.io/$PROJECT_ID/extractor-taxi \
  --timeout=10m

# Deploy as Cloud Run Job
gcloud run jobs create extractor-taxi \
  --image gcr.io/$PROJECT_ID/extractor-taxi \
  --region $REGION \
  --max-retries 3 \
  --task-timeout 3600 \
  --memory 512Mi \
  --cpu 1 \
  --set-env-vars="PROJECT_ID=$PROJECT_ID"

cd ../..
```

### Build Other Extractors (TNP, COVID, Permits)
```bash
# Repeat for each extractor
for extractor in tnp covid permits; do
  cd extractors/$extractor

  gcloud builds submit --tag gcr.io/$PROJECT_ID/extractor-$extractor

  gcloud run jobs create extractor-$extractor \
    --image gcr.io/$PROJECT_ID/extractor-$extractor \
    --region $REGION \
    --max-retries 3 \
    --task-timeout 3600 \
    --memory 512Mi \
    --cpu 1

  cd ../..
done
```

---

## Step 5: Setup Geospatial Reference Data

### Install Python Dependencies
```bash
cd geospatial/geopandas

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install requirements
pip install -r requirements.txt
```

### Generate Zip Code Boundaries
```bash
# Download shapefile (manual step)
# Visit: https://data.cityofchicago.org/Facilities-Geographic-Boundaries/Boundaries-ZIP-Codes/igwz-8jzy
# Download as Shapefile and extract to ../reference-maps/

# Process and upload to BigQuery
python generate_zip_boundaries.py \
  --project-id $PROJECT_ID \
  --shapefile ../reference-maps/chicago_zip_boundaries.shp
```

---

## Step 6: Configure Cloud Scheduler

### Create Service Account
```bash
# Create service account for Cloud Scheduler
gcloud iam service-accounts create scheduler \
  --display-name="Cloud Scheduler Service Account"

# Grant permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:scheduler@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/run.invoker"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:scheduler@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudscheduler.jobRunner"
```

### Setup Scheduler Jobs
```bash
cd scheduler

# Make script executable
chmod +x daily_extract.sh

# Run setup script
./daily_extract.sh

cd ..
```

---

## Step 7: Setup Monitoring

### Create Budget Alerts
```bash
# Get billing account ID
gcloud billing accounts list

# Create budget (via Cloud Console recommended)
# Or use gcloud command:
gcloud billing budgets create \
  --billing-account=$BILLING_ACCOUNT_ID \
  --display-name="Chicago BI Budget" \
  --budget-amount=60 \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=75 \
  --threshold-rule=percent=90 \
  --threshold-rule=percent=100
```

### Create Log-Based Metrics
```bash
# Create metric for pipeline failures
gcloud logging metrics create pipeline_failures \
  --description="Count of pipeline failures" \
  --log-filter='severity=ERROR AND resource.type="cloud_run_job"'

# Create metric for data quality failures
gcloud logging metrics create quality_check_failures \
  --description="Count of data quality check failures" \
  --log-filter='textPayload:"quality check failed"'
```

---

## Step 8: Test the Pipeline

### Manual Test Run
```bash
# Run taxi extractor manually
gcloud run jobs execute extractor-taxi \
  --region $REGION \
  --wait

# Check logs
gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.job_name=extractor-taxi" \
  --limit 50 \
  --format json
```

### Verify Data in BigQuery
```bash
# Query raw data
bq query --use_legacy_sql=false \
  'SELECT COUNT(*) as row_count
   FROM `'$PROJECT_ID'.raw_data.raw_taxi_trips`'
```

---

## Step 9: Create Looker Studio Dashboards

1. Visit [Looker Studio](https://lookerstudio.google.com/)
2. Create new report
3. Add BigQuery data source:
   - Project: `chicago-bi`
   - Dataset: `analytics`
   - Table: `agg_taxi_daily`
4. Build visualizations
5. Share with stakeholders

---

## Step 10: Ongoing Operations

### Daily Checks
```bash
# Check scheduler job status
gcloud scheduler jobs list --location=$REGION

# Check recent pipeline runs
bq query --use_legacy_sql=false \
  'SELECT * FROM `'$PROJECT_ID'.monitoring.pipeline_runs`
   ORDER BY run_timestamp DESC LIMIT 10'
```

### Cost Monitoring
```bash
# View current month costs
gcloud billing accounts list

# Query cost tracking table
bq query --use_legacy_sql=false \
  'SELECT
     service_name,
     SUM(cost_usd) as total_cost
   FROM `'$PROJECT_ID'.monitoring.cost_tracking`
   WHERE date >= DATE_TRUNC(CURRENT_DATE(), MONTH)
   GROUP BY service_name'
```

---

## Troubleshooting

### Extractor Fails
```bash
# View detailed logs
gcloud logging read \
  "resource.type=cloud_run_job" \
  --limit 100 \
  --format json

# Run locally for debugging
cd extractors/taxi
go run main.go
```

### BigQuery Load Errors
```bash
# Check load job errors
bq ls -j -a

# Get job details
bq show -j <JOB_ID>
```

### Permission Issues
```bash
# List service account permissions
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:scheduler@*"
```

---

## Cleanup (After Project Completion)

### Delete All Resources
```bash
# Delete scheduler jobs
gcloud scheduler jobs delete daily-taxi-extract --location=$REGION --quiet
gcloud scheduler jobs delete daily-tnp-extract --location=$REGION --quiet
gcloud scheduler jobs delete daily-covid-extract --location=$REGION --quiet
gcloud scheduler jobs delete daily-permits-extract --location=$REGION --quiet

# Delete Cloud Run jobs
gcloud run jobs delete extractor-taxi --region=$REGION --quiet
gcloud run jobs delete extractor-tnp --region=$REGION --quiet
gcloud run jobs delete extractor-covid --region=$REGION --quiet
gcloud run jobs delete extractor-permits --region=$REGION --quiet

# Delete BigQuery datasets
bq rm -r -f ${PROJECT_ID}:raw_data
bq rm -r -f ${PROJECT_ID}:cleaned_data
bq rm -r -f ${PROJECT_ID}:analytics
bq rm -r -f ${PROJECT_ID}:reference
bq rm -r -f ${PROJECT_ID}:monitoring

# Delete Cloud Storage buckets
gsutil -m rm -r gs://${PROJECT_ID}-landing
gsutil -m rm -r gs://${PROJECT_ID}-archive

# Delete entire project (nuclear option)
gcloud projects delete $PROJECT_ID
```

---

## Next Steps

1. **Week 2:** Implement transformation queries (Bronze → Silver → Gold)
2. **Week 3:** Add ML forecasting with Vertex AI
3. **Week 4:** Build Looker Studio dashboards and prepare presentation

---

## Support

For issues or questions:
- Check [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Review [GCP Documentation](https://cloud.google.com/docs)
- Contact team members

---

**Last Updated:** October 2025
**Version:** 1.0
