# Complete Deployment Guide
## Taxi & TNP Trips - Q1 2020 Historical Backfill

---
**Document:** Chicago BI App - Deployment Guide
**Version:** 2.0.0
**Document Type:** Tutorial/Guide
**Date:** 2025-10-31
**Status:** Final
**Supersedes:** v1.0.0 (taxi-only deployment)
**Authors:** Group 2 - MSDS 432
**Project:** Chicago BI App - MSDS 432
**Datasets:** Taxi Trips (wrvz-psew) + TNP Trips (m6dm-c72p)
**Related Docs:** START_HERE.md, README.md v2.0, CHANGELOG.md
---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.0.0 | 2025-10-31 | Group 2 | Added TNP trips deployment, dual-dataset support |
| 1.0.0 | 2025-10-30 | Group 2 | Initial deployment guide (taxi only) |

---

## 📋 Overview

This guide walks you through deploying both extractors and running the Q1 2020 historical backfill for taxi and TNP (rideshare) trip data.

**What You'll Deploy:**
1. **Taxi Trips Extractor** - Traditional taxi trips (wrvz-psew)
2. **TNP Trips Extractor** - Rideshare trips from Uber/Lyft (m6dm-c72p)
3. **BigQuery Tables** - Storage for both datasets
4. **Q1 2020 Backfill** - 90 days × 2 datasets = 180 daily extractions

**Total Time:** ~90-120 minutes
**Cost:** ~$3-4 (one-time)

---

## 🎯 Prerequisites

Before starting, ensure you have:

- [x] GCP project: `chicago-bi-app-msds-432-476520`
- [x] Socrata API credentials in Secret Manager
  - `socrata-key-id`
  - `socrata-key-secret`
- [x] Docker Desktop running
- [x] `gcloud` CLI authenticated
- [x] Landing bucket: `chicago-bi-app-msds-432-476520-landing`

**Verify Credentials:**
```bash
gcloud secrets describe socrata-key-id --project=chicago-bi-app-msds-432-476520
gcloud secrets describe socrata-key-secret --project=chicago-bi-app-msds-432-476520
```

---

## 🚀 Step-by-Step Deployment

### Phase 1: Deploy BigQuery Schemas (5 minutes)

Create the tables to store the data:

```bash
cd ~/Desktop/chicago-bi-app/bigquery/schemas
./deploy_schemas.sh
```

**What this creates:**
- `raw_data.raw_taxi_trips` - Taxi trip data table
- `raw_data.raw_tnp_trips` - TNP rideshare trip data table

**Verify:**
```bash
bq ls chicago-bi-app-msds-432-476520:raw_data
bq show chicago-bi-app-msds-432-476520:raw_data.raw_taxi_trips
bq show chicago-bi-app-msds-432-476520:raw_data.raw_tnp_trips
```

---

### Phase 2: Deploy Taxi Extractor (15 minutes)

Deploy the taxi trips extractor:

```bash
cd ~/Desktop/chicago-bi-app/extractors/taxi
./deploy_with_auth.sh
```

**What this does:**
1. Verifies Socrata API credentials
2. Tests authentication with wrvz-psew dataset
3. Builds Docker image
4. Pushes to Container Registry
5. Creates/updates Cloud Run job: `extractor-taxi`
6. Optionally runs a test extraction

**When prompted to test:**
- Choose `yes` to verify it works
- It will extract data for yesterday's date (or a historical date)

**Verify:**
```bash
gcloud run jobs describe extractor-taxi \
  --region=us-central1 \
  --project=chicago-bi-app-msds-432-476520
```

---

### Phase 3: Deploy TNP Extractor (15 minutes)

Deploy the TNP trips extractor:

```bash
cd ~/Desktop/chicago-bi-app/extractors/tnp
./deploy_with_auth.sh
```

**What this does:**
1. Verifies Socrata API credentials
2. Tests authentication with m6dm-c72p dataset
3. Builds Docker image
4. Pushes to Container Registry
5. Creates/updates Cloud Run job: `extractor-tnp`
6. Optionally runs a test extraction

**When prompted to test:**
- Choose `yes` to verify it works
- It will extract data for 2020-01-15 (known good date)

**Verify:**
```bash
gcloud run jobs describe extractor-tnp \
  --region=us-central1 \
  --project=chicago-bi-app-msds-432-476520
```

---

### Phase 4: Run Q1 2020 Backfill (60-90 minutes)

#### Option A: Run on Cloud Shell (Recommended)

**Why Cloud Shell?**
- Free compute
- Can close browser (uses tmux)
- Faster network to GCP
- No impact on local machine

**Steps:**

1. **Open Cloud Shell:**
   - Go to https://console.cloud.google.com
   - Click the terminal icon (top right)

2. **Clone repository (if needed):**
   ```bash
   git clone https://github.com/YOUR_USERNAME/chicago-bi-app.git
   cd chicago-bi-app/backfill
   ```

3. **Run backfill with tmux:**
   ```bash
   # Start tmux session
   tmux new -s backfill

   # Run backfill for both datasets
   ./quarterly_backfill_q1_2020.sh all

   # Detach from tmux: Ctrl+B then D
   # Reattach later: tmux attach -t backfill
   ```

#### Option B: Run Locally

**Steps:**

```bash
cd ~/Desktop/chicago-bi-app/backfill
./quarterly_backfill_q1_2020.sh all
```

**⚠️ Warning:** Do NOT close your terminal during execution (90-120 minutes)

#### Backfill Progress

**What happens:**
- Processes 90 dates for each dataset (Jan 1 - Mar 31, 2020)
- Total: 180 daily extractions
- 30 seconds delay between each extraction
- Creates log file: `backfill_q1_2020_all_YYYYMMDD_HHMMSS.log`

**Expected output:**
```
================================================
Chicago BI App - Q1 2020 Quarterly Backfill
================================================

Quarter: Q1 2020 (Jan 1 - Mar 31)
Partitions: 90 daily partitions
Dataset: all

================================================
Processing dataset: taxi
================================================

ℹ️  Progress: 1/90 (taxi)
ℹ️  Running taxi extraction for 2020-01-01...
✅ Completed taxi for 2020-01-01
ℹ️  Waiting 30 seconds before next extraction...

[... continues for all 90 dates ...]

================================================
Processing dataset: tnp
================================================

[... processes 90 more dates ...]

================================================
Backfill Summary
================================================
Total Executions: 180
Successful: 180
Failed: 0
```

---

### Phase 5: Verify Data (10 minutes)

After the backfill completes, verify the data loaded correctly:

#### Check Taxi Trips

```bash
# Count partitions
bq query --use_legacy_sql=false \
  "SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as partitions
   FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
```
**Expected:** 90 partitions

```bash
# Count total trips
bq query --use_legacy_sql=false \
  "SELECT COUNT(*) as total_trips
   FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
```
**Expected:** ~3-5 million trips

```bash
# View sample data
bq query --use_legacy_sql=false \
  "SELECT DATE(trip_start_timestamp) as date, COUNT(*) as trips
   FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-01-10'
   GROUP BY date
   ORDER BY date"
```

#### Check TNP Trips

```bash
# Count partitions
bq query --use_legacy_sql=false \
  "SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as partitions
   FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_tnp_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
```
**Expected:** 90 partitions

```bash
# Count total trips
bq query --use_legacy_sql=false \
  "SELECT COUNT(*) as total_trips
   FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_tnp_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
```
**Expected:** ~10-15 million trips (rideshare > taxi)

```bash
# Compare taxi vs TNP volume
bq query --use_legacy_sql=false \
  "SELECT
    'Taxi' as type, COUNT(*) as trips
   FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'
   UNION ALL
   SELECT
    'TNP' as type, COUNT(*) as trips
   FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_tnp_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
```

---

## 🛠️ Troubleshooting

### Issue: "Secret not found"
**Solution:**
```bash
# Check secrets exist
gcloud secrets list --project=chicago-bi-app-msds-432-476520

# If missing, create them:
echo "YOUR_KEY_ID" | gcloud secrets create socrata-key-id \
  --data-file=- \
  --project=chicago-bi-app-msds-432-476520

echo "YOUR_KEY_SECRET" | gcloud secrets create socrata-key-secret \
  --data-file=- \
  --project=chicago-bi-app-msds-432-476520
```

### Issue: "Docker build failed"
**Solution:**
- Ensure Docker Desktop is running
- Restart Docker Desktop
- Run `docker ps` to verify

### Issue: "Authentication failed" (HTTP 403)
**Solution:**
```bash
# Test credentials manually
KEY_ID=$(gcloud secrets versions access latest --secret=socrata-key-id --project=chicago-bi-app-msds-432-476520)
KEY_SECRET=$(gcloud secrets versions access latest --secret=socrata-key-secret --project=chicago-bi-app-msds-432-476520)

# Test taxi dataset
curl -u "$KEY_ID:$KEY_SECRET" "https://data.cityofchicago.org/resource/wrvz-psew.json?\$limit=1"

# Test TNP dataset
curl -u "$KEY_ID:$KEY_SECRET" "https://data.cityofchicago.org/resource/m6dm-c72p.json?\$limit=1"
```

### Issue: "Cloud Shell timeout"
**Solution:**
- Use tmux (see Phase 4, Option A)
- Detach with `Ctrl+B` then `D`
- Reattach with `tmux attach -t backfill`

### Issue: "Job execution failed"
**Solution:**
```bash
# Check Cloud Run logs
gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.job_name=extractor-taxi" \
  --limit=50 \
  --project=chicago-bi-app-msds-432-476520

gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.job_name=extractor-tnp" \
  --limit=50 \
  --project=chicago-bi-app-msds-432-476520
```

### Issue: "No data in BigQuery"
**Solution:**
1. Check if data is in Cloud Storage:
   ```bash
   gsutil ls gs://chicago-bi-app-msds-432-476520-landing/taxi/2020-01-01/
   gsutil ls gs://chicago-bi-app-msds-432-476520-landing/tnp/2020-01-01/
   ```

2. Load manually from GCS to BigQuery:
   ```bash
   bq load --source_format=NEWLINE_DELIMITED_JSON \
     --autodetect \
     chicago-bi-app-msds-432-476520:raw_data.raw_taxi_trips \
     gs://chicago-bi-app-msds-432-476520-landing/taxi/2020-01-01/*.json
   ```

---

## 📊 What You'll Have After Completion

### In Cloud Storage
- ✅ 90 taxi data files: `gs://.../taxi/YYYY-MM-DD/data.json`
- ✅ 90 TNP data files: `gs://.../tnp/YYYY-MM-DD/data.json`
- ✅ ~10-20 GB total storage

### In BigQuery
- ✅ 180 daily partitions (90 taxi + 90 TNP)
- ✅ ~15-20 million trip records
- ✅ Ready for silver/gold layer processing
- ✅ Ready for analysis and dashboards

### Cost Impact
- **One-time:** $3-4 (backfill execution)
- **Monthly:** +$0.60 storage (30GB active)
- **After archive:** +$0.12/month (80% savings with Coldline)

---

## 📈 Next Steps

After completing the backfill:

1. **Process to Silver Layer**
   - Clean and validate data
   - Enrich with geospatial joins
   - Add zip code mappings

2. **Create Gold Layer**
   - Pre-aggregate analytics metrics
   - Create materialized views
   - Build dashboard-ready tables

3. **Build Dashboards**
   - Looker Studio visualizations
   - Compare taxi vs TNP trends
   - Analyze Q1 2020 (pre-COVID baseline)

4. **Archive Historical Data**
   - Move to Coldline storage
   - Save 80% on storage costs
   - Retain for compliance

5. **Enable Incremental Updates**
   - Schedule daily extractions
   - Keep data fresh
   - Monitor for new data

---

## 📁 File Reference

| File | Purpose |
|------|---------|
| `extractors/taxi/main.go` | Taxi trips extractor (wrvz-psew) |
| `extractors/taxi/deploy_with_auth.sh` | Deploy taxi extractor |
| `extractors/tnp/main.go` | TNP trips extractor (m6dm-c72p) |
| `extractors/tnp/deploy_with_auth.sh` | Deploy TNP extractor |
| `bigquery/schemas/bronze_layer.sql` | Table DDL definitions |
| `bigquery/schemas/deploy_schemas.sh` | Create BigQuery tables |
| `backfill/quarterly_backfill_q1_2020.sh` | Q1 2020 backfill script |

---

## 🎯 Quick Reference Commands

**Deploy Everything:**
```bash
# 1. Deploy schemas
cd ~/Desktop/chicago-bi-app/bigquery/schemas && ./deploy_schemas.sh

# 2. Deploy taxi extractor
cd ~/Desktop/chicago-bi-app/extractors/taxi && ./deploy_with_auth.sh

# 3. Deploy TNP extractor
cd ~/Desktop/chicago-bi-app/extractors/tnp && ./deploy_with_auth.sh

# 4. Run backfill
cd ~/Desktop/chicago-bi-app/backfill && ./quarterly_backfill_q1_2020.sh all
```

**Monitor Progress:**
```bash
# Check running jobs
gcloud run jobs executions list \
  --region=us-central1 \
  --project=chicago-bi-app-msds-432-476520

# View logs
gcloud logging tail "resource.type=cloud_run_job" \
  --project=chicago-bi-app-msds-432-476520
```

**Verify Data:**
```bash
# Quick check
bq query --use_legacy_sql=false \
  "SELECT 'Taxi' as dataset, COUNT(*) as rows FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'
   UNION ALL
   SELECT 'TNP' as dataset, COUNT(*) as rows FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_tnp_trips\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
```

---

## ✅ Completion Checklist

- [ ] BigQuery schemas deployed
- [ ] Taxi extractor deployed and tested
- [ ] TNP extractor deployed and tested
- [ ] Q1 2020 backfill completed (180/180 successful)
- [ ] Data verified in BigQuery (90 partitions each)
- [ ] Row counts look reasonable (millions of trips)
- [ ] No errors in Cloud Run logs
- [ ] Backfill log file reviewed

---

**Northwestern MSDS 432 - Group 2**
**Albin Anto Jose, Myetchae Thu, Ansh Gupta, Bickramjit Basu**
