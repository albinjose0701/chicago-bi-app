# Building Permits Pipeline - Complete Automation Guide

**Version:** v2.21.0
**Created:** November 21, 2025
**Status:** Production Ready ✅

---

## Overview

This document describes the complete automated pipeline for building permits data:

1. **Extraction** (Cloud Run job) - Fetches new permits from Chicago Data Portal
2. **Transformation** (Cloud Run job) - Processes through Bronze → Silver → Gold layers
3. **Scheduling** (Cloud Scheduler) - Runs weekly on Mondays
4. **Dashboard Refresh** (Looker Studio) - Automatic with caching

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AUTOMATED PIPELINE                          │
└─────────────────────────────────────────────────────────────────────┘

Monday 2:00 AM CT (8:00 AM UTC)
    ↓
┌──────────────────────┐
│  EXTRACTOR Job       │  ← Existing Cloud Run job
│  (permits-extractor) │     Fetches new permits from portal
└──────────────────────┘     Writes to raw_building_permits
    ↓
Monday 3:00 AM CT (9:00 AM UTC)
    ↓
┌──────────────────────┐
│  PIPELINE Job        │  ← This pipeline
│  (permits-pipeline)  │     Bronze: Quality filtering + deduplication
└──────────────────────┘     Silver: Spatial enrichment (ZIP, neighborhood)
    ↓                        Gold: Aggregates (ROI, loan targets)
┌──────────────────────┐
│  BigQuery Tables     │
│  - bronze_permits    │
│  - silver_permits    │
│  - gold_permits_roi  │
│  - gold_loan_targets │
└──────────────────────┘
    ↓
Looker Studio Dashboards (auto-refresh every 12 hours)
```

---

## Deployment Instructions

### Prerequisites

1. **GCP Permissions:**
   - Cloud Run Admin
   - Cloud Scheduler Admin
   - Container Registry Admin
   - BigQuery Data Editor
   - Service Account User

2. **Service Account:**
   - Email: `chicago-bi-app@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com`
   - Roles: BigQuery Data Editor, BigQuery Job User

3. **Existing Resources:**
   - BigQuery dataset: `raw_data`, `bronze_data`, `silver_data`, `gold_data`
   - Reference tables: `zip_code_boundaries`, `neighborhood_boundaries`, etc.

### Step 1: Deploy Pipeline to Cloud Run

From the `transformations/permits` directory:

```bash
# From project root
cd transformations/permits

# Option A: Automated deployment (recommended)
./deploy.sh

# Option B: Manual deployment
gcloud builds submit --config=cloudbuild.yaml --project=chicago-bi-app-msds-432-476520
```

This will:
- ✅ Build Docker container with Python + BigQuery client
- ✅ Push to Container Registry
- ✅ Create/update Cloud Run job
- ✅ Create Cloud Scheduler for weekly execution (Monday 3 AM CT)
- ✅ Optionally run a test execution

**Expected output:**
```
✓ Container built and pushed
✓ Cloud Run job ready: permits-pipeline
✓ Scheduler configured: Every Monday at 3 AM CT
✓ Test execution completed (if selected)
```

### Step 2: Configure Extractor Schedule (Existing)

The permits extractor should already be scheduled, but verify:

```bash
# Check existing extractor scheduler
gcloud scheduler jobs describe permits-extractor-weekly \
  --location=us-central1 \
  --project=chicago-bi-app-msds-432-476520

# If not scheduled, create it
gcloud scheduler jobs create http permits-extractor-weekly \
  --location=us-central1 \
  --schedule="0 8 * * 1" \
  --time-zone="America/Chicago" \
  --uri="https://us-central1-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/chicago-bi-app-msds-432-476520/jobs/permits-extractor:run" \
  --http-method=POST \
  --oauth-service-account-email=chicago-bi-app@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com \
  --description="Weekly building permits extraction (every Monday at 2 AM CT)"
```

**Schedule Summary:**
- **Extractor:** Monday 2:00 AM CT (8:00 AM UTC)
- **Pipeline:** Monday 3:00 AM CT (9:00 AM UTC)
- **Gap:** 1 hour allows extractor to complete

### Step 3: Verify Automation

```bash
# 1. List all schedulers
gcloud scheduler jobs list --location=us-central1 --project=chicago-bi-app-msds-432-476520

# 2. View next scheduled run
gcloud scheduler jobs describe permits-pipeline-weekly \
  --location=us-central1 \
  --project=chicago-bi-app-msds-432-476520 \
  --format="value(schedule,scheduleTime)"

# 3. Manual test execution
gcloud run jobs execute permits-pipeline \
  --region=us-central1 \
  --project=chicago-bi-app-msds-432-476520 \
  --wait

# 4. View execution logs
gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.job_name=permits-pipeline" \
  --limit=50 \
  --project=chicago-bi-app-msds-432-476520 \
  --format=json
```

---

## Pipeline Details

### SQL Transformations

**1. Bronze Layer** (`01_bronze_permits_incremental.sql`)
- **Strategy:** MERGE on primary key (`id`)
- **Input:** `raw_data.raw_building_permits`
- **Output:** `bronze_data.bronze_building_permits`
- **Processing:**
  - Filters permits issued in last 30 days
  - Validates coordinates (Chicago bounds)
  - Deduplicates on `id`
- **Execution time:** ~10-15 seconds
- **Records processed:** ~3,910 (incremental)

**2. Silver Layer** (`02_silver_permits_incremental.sql`)
- **Strategy:** MERGE with spatial enrichment
- **Input:** `bronze_data.bronze_building_permits`
- **Output:** `silver_data.silver_permits_enriched`
- **Processing:**
  - Spatial join to `zip_code_boundaries` (ST_WITHIN)
  - Spatial join to `neighborhood_boundaries`
  - Derives permit_year, permit_month
- **Execution time:** ~45-60 seconds
- **Records processed:** Same as Bronze input

**3. Gold Layer** (`03_gold_permits_aggregates.sql`)
- **Strategy:** DELETE + INSERT (full refresh)
- **Input:** `silver_data.silver_permits_enriched`
- **Outputs:**
  - `gold_data.gold_permits_roi` (59 ZIPs)
  - `gold_data.gold_loan_targets` (58 ZIPs)
- **Processing:**
  - Aggregates permits by ZIP
  - Calculates loan eligibility indices
  - Joins socioeconomic data
- **Execution time:** ~15-20 seconds
- **Records:** 59-60 ZIPs (small, fast)

**Total Pipeline Time:** ~2 minutes (incremental) or ~6 minutes (full refresh)

### Incremental Logic

**How it works:**

```sql
-- Bronze: Process permits from last 30 days
MERGE bronze_data.bronze_building_permits AS target
USING (
  SELECT * FROM raw_data.raw_building_permits
  WHERE issue_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    OR NOT EXISTS (SELECT 1 FROM bronze_data.bronze_building_permits LIMIT 1)
) AS source
ON target.id = source.id
WHEN MATCHED THEN UPDATE SET ...
WHEN NOT MATCHED THEN INSERT ...
```

**Why 30 days?**
- Covers weekly schedule + buffer (4 weeks)
- Accounts for delayed permit postings
- Handles edge cases (holidays, system delays)
- MERGE prevents duplicates (safe to overlap)

**First run behavior:**
- If Bronze table is empty: Processes ALL raw records
- If Bronze exists: Only processes last 30 days
- Silver/Gold: Same incremental logic

---

## Monitoring & Troubleshooting

### Check Pipeline Status

```bash
# View last execution
gcloud run jobs executions list \
  --job=permits-pipeline \
  --region=us-central1 \
  --project=chicago-bi-app-msds-432-476520 \
  --limit=5

# View specific execution logs
EXECUTION_NAME="permits-pipeline-xxxxx"  # From above command
gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.execution_name=$EXECUTION_NAME" \
  --project=chicago-bi-app-msds-432-476520 \
  --format=json
```

### Common Issues

#### Issue 1: No new records processed
**Symptom:** Pipeline logs show "0 rows affected"
**Cause:** No permits issued in last 30 days (unlikely) or extractor didn't run
**Fix:**
```bash
# Check if extractor ran
gcloud logging read "resource.type=cloud_run_job AND resource.labels.job_name=permits-extractor" \
  --limit=10 --project=chicago-bi-app-msds-432-476520

# Manually trigger extractor
gcloud run jobs execute permits-extractor \
  --region=us-central1 --project=chicago-bi-app-msds-432-476520
```

#### Issue 2: Spatial join fails (NULL ZIP codes)
**Symptom:** Silver layer shows high `missing_zip` count
**Cause:** Coordinates outside Chicago or geometry table empty
**Fix:**
```sql
-- Check geometry tables
SELECT COUNT(*) FROM `chicago-bi-app-msds-432-476520.reference_data.zip_code_boundaries`;
-- Should return 60+

-- Check recent permits with NULL ZIPs
SELECT id, latitude, longitude, zip_code
FROM `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched`
WHERE zip_code IS NULL
  AND issue_date >= '2025-11-01'
LIMIT 10;
```

#### Issue 3: Pipeline timeout (>10 minutes)
**Symptom:** Execution fails with timeout error
**Cause:** Processing too many records or slow queries
**Fix:**
```bash
# Increase timeout (if needed)
gcloud run jobs update permits-pipeline \
  --region=us-central1 \
  --task-timeout=20m \
  --project=chicago-bi-app-msds-432-476520
```

#### Issue 4: Permission denied
**Symptom:** "Access Denied: Table chicago-bi-app-msds-432-476520:bronze_data.bronze_building_permits"
**Cause:** Service account lacks BigQuery permissions
**Fix:**
```bash
# Grant BigQuery Data Editor role
gcloud projects add-iam-policy-binding chicago-bi-app-msds-432-476520 \
  --member="serviceAccount:chicago-bi-app@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"
```

### Data Quality Checks

After each execution, verify:

```sql
-- 1. Check layer completeness
SELECT
  'Raw' as layer,
  COUNT(*) as records,
  MAX(issue_date) as newest_permit
FROM `chicago-bi-app-msds-432-476520.raw_data.raw_building_permits`
WHERE issue_date >= '2020-01-01'

UNION ALL

SELECT
  'Bronze' as layer,
  COUNT(*) as records,
  MAX(issue_date) as newest_permit
FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_building_permits`

UNION ALL

SELECT
  'Silver' as layer,
  COUNT(*) as records,
  MAX(issue_date) as newest_permit
FROM `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched`;

-- 2. Check for missing ZIPs
SELECT
  COUNT(*) as total_permits,
  COUNTIF(zip_code IS NULL) as missing_zip,
  ROUND(COUNTIF(zip_code IS NULL) / COUNT(*) * 100, 2) as missing_pct
FROM `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched`
WHERE issue_date >= '2025-01-01';

-- 3. Check Gold aggregates freshness
SELECT
  'Permits ROI' as table_name,
  COUNT(*) as zip_codes,
  MAX(last_updated) as last_update
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_permits_roi`

UNION ALL

SELECT
  'Loan Targets' as table_name,
  COUNT(*) as zip_codes,
  MAX(last_updated) as last_update
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_loan_targets`;
```

---

## Cost Estimates

### Per Execution
- **Cloud Run:** ~$0.01 (1 CPU, 1 GB RAM, 2-6 min)
- **BigQuery processing:** ~$0.02-0.05 (incremental)
- **Container Registry:** ~$0.01/month (storage)
- **Cloud Scheduler:** $0.10/month (1 job)
- **Total per run:** ~$0.03-0.06

### Weekly Schedule (52 runs/year)
- **Cloud Run:** ~$0.52/year
- **BigQuery:** ~$1.04-2.60/year
- **Scheduler:** ~$1.20/year
- **Total:** ~$2.76-4.32/year

**Very low cost!** ✅

---

## Maintenance

### Weekly Tasks (Automated ✅)
- ✅ Monday 2 AM: Extract new permits
- ✅ Monday 3 AM: Transform to Bronze/Silver/Gold
- ✅ Dashboards refresh automatically (see Looker Studio section below)

### Monthly Tasks (Manual)
- Review execution logs for errors
- Check data quality metrics
- Verify dashboard freshness

### Quarterly Tasks (Manual)
- Review cost reports
- Optimize queries if needed
- Update documentation

---

## Future Enhancements

### Short-term (v2.22.0)
1. **Email alerts** on pipeline failures
2. **Slack notifications** for weekly summaries
3. **Data quality dashboard** (automated checks)

### Medium-term (v2.23.0)
1. **Incremental extraction** (fix extractor to capture ALL new records)
2. **Change data capture** (track permit status changes)
3. **Historical backfill** (automated gap detection)

### Long-term (v3.0.0)
1. **Real-time streaming** (Pub/Sub + Dataflow)
2. **ML predictions** (permit approval time forecasting)
3. **Advanced monitoring** (Datadog integration)

---

## Related Files

**Pipeline Code:**
- `run_pipeline.py` - Python orchestration script
- `01_bronze_permits_incremental.sql` - Bronze layer transformation
- `02_silver_permits_incremental.sql` - Silver layer enrichment
- `03_gold_permits_aggregates.sql` - Gold layer aggregation

**Deployment:**
- `Dockerfile` - Container definition
- `cloudbuild.yaml` - Build configuration
- `deploy.sh` - Automated deployment script
- `requirements.txt` - Python dependencies

**Documentation:**
- `README.md` - Quick start guide
- `AUTOMATION_GUIDE.md` - This file (comprehensive automation)

---

## Support

**Questions?** Contact project owner or check:
- BigQuery Console: https://console.cloud.google.com/bigquery
- Cloud Run Jobs: https://console.cloud.google.com/run/jobs
- Cloud Scheduler: https://console.cloud.google.com/cloudscheduler

**Logs:**
```bash
gcloud logging read "resource.type=cloud_run_job" \
  --project=chicago-bi-app-msds-432-476520 \
  --limit=50
```

---

**Last Updated:** November 21, 2025
**Version:** v2.21.0
**Status:** Production Ready ✅
