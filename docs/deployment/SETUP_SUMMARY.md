# Chicago BI App - GCP Setup Summary

## What Will Be Created

### Script 1: `setup_gcp_infrastructure.sh`

#### ✅ APIs Enabled
- Cloud Run (serverless execution)
- Cloud Build (container building)
- Cloud Scheduler (cron jobs)
- Vertex AI (ML forecasting)
- Compute Engine (required by Cloud Run)
- Artifact Registry (container storage)
- Secret Manager (credentials)

#### ✅ Service Accounts Created
1. **geo-etl@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com**
   - For geospatial data operations
   - Roles: BigQuery Data Editor, Job User, Storage Object Admin

2. **scheduler@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com**
   - For Cloud Scheduler operations
   - Roles: Cloud Run Invoker, Cloud Scheduler Job Runner

3. **cloud-run@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com**
   - For Cloud Run job execution
   - Roles: BigQuery Data Editor, Job User, Storage Object Admin

#### ✅ Cloud Storage Buckets
1. **gs://chicago-bi-app-msds-432-476520-landing**
   - Purpose: Landing zone for raw data extractions
   - Lifecycle: → Nearline after 30 days → Delete after 90 days
   - Region: us-central1

2. **gs://chicago-bi-app-msds-432-476520-archive**
   - Purpose: Long-term archival storage
   - Lifecycle: → Archive after 365 days
   - Region: us-central1

#### ✅ BigQuery Datasets (Empty Containers)
1. **raw_data** - Bronze layer (raw ingested data)
2. **cleaned_data** - Silver layer (cleaned and validated)
3. **analytics** - Gold layer (aggregated metrics)
4. **reference** - Reference and dimension tables
5. **monitoring** - Operational monitoring (empty - using Cloud Operations UI)

**⚠️ NO TABLES CREATED** - You'll define schemas later

---

### Script 2: `setup_budget_shutdown.sh`

#### ✅ Budget Monitoring
- **Total Budget:** $310 USD (from ₹26,000 credits)
- **Alert Thresholds:** 5%, 10%, 20%, 30%, 40%, 50%, 80%
- **Alert Method:** Email notifications + Pub/Sub

#### ✅ Auto-Shutdown at 80%
When budget reaches 80% ($248 used):
1. **Pauses all Cloud Scheduler jobs** (stops new data extractions)
2. **Lets running jobs complete** (no abrupt termination)
3. **Sends email notification**
4. **Cloud Run jobs won't execute** (no scheduler triggers)

**To Resume After Shutdown:**
1. Go to Cloud Console → Cloud Scheduler
2. Select all jobs → Click "Resume"
3. Jobs will start running on schedule again

#### ✅ Service-Wise Monitoring
While the budget is project-wide, Cloud Operations provides service-wise cost breakdowns:
- Navigate to: Cloud Console → Billing → Reports
- Filter by: Service (BigQuery, Cloud Run, Cloud Storage, etc.)
- View: Daily, weekly, or monthly costs by service
- Export: CSV/JSON for detailed analysis

---

## Cost Impact Summary

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| **Infrastructure** | $28.84 | Storage, BigQuery, Cloud Run |
| **Cloud Operations UI** | $0-4 | Likely $0 with free tier |
| **Budget Monitoring** | $0 | Free (built-in) |
| **Auto-Shutdown Function** | $0 | Free tier covers it |
| **TOTAL** | **$28.84-33** | ~10.7 months on $310 credits |

**Budget Utilization Timeline:**
- 5% ($15.50): Week 2-3
- 10% ($31): Month 1
- 20% ($62): Month 2
- 30% ($93): Month 3
- 40% ($124): Month 4
- 50% ($155): Month 5
- 80% ($248): Month 8-9 (AUTO-SHUTDOWN)

---

## What Will NOT Be Created

❌ **BigQuery Tables** - You'll create these after finalizing your data model
❌ **Cloud Run Extractors** - Need to build and deploy separately
❌ **Cloud Scheduler Jobs** - Need to configure after deploying extractors
❌ **Geospatial Reference Data** - Need to upload manually
❌ **Custom Monitoring Tables** - Using Cloud Operations UI instead

---

## Access Cloud Operations UI

After setup, access monitoring dashboards:

**Cloud Monitoring:**
https://console.cloud.google.com/monitoring/dashboards?project=chicago-bi-app-msds-432-476520

**Cloud Logging:**
https://console.cloud.google.com/logs?project=chicago-bi-app-msds-432-476520

**Budget & Billing:**
https://console.cloud.google.com/billing?project=chicago-bi-app-msds-432-476520

**Cost Reports (Service-Wise):**
https://console.cloud.google.com/billing/reports?project=chicago-bi-app-msds-432-476520

---

## Execution Plan

### Step 1: Run Infrastructure Setup
```bash
cd ~/Desktop/chicago-bi-app
./setup_gcp_infrastructure.sh
```
**Duration:** ~2-3 minutes
**Output:** Service accounts, buckets, datasets

### Step 2: Run Budget Setup
```bash
cd ~/Desktop/chicago-bi-app
./setup_budget_shutdown.sh
```
**Duration:** ~3-5 minutes
**Output:** Budget alerts, auto-shutdown function

### Step 3: Verify Setup
```bash
# Check service accounts
gcloud iam service-accounts list

# Check buckets
gsutil ls

# Check datasets
bq ls

# Check budget
gcloud billing budgets list --billing-account=<BILLING_ACCOUNT_ID>
```

---

## Safety Features

✅ **Idempotent Scripts** - Safe to run multiple times (won't duplicate resources)
✅ **Error Handling** - Continues on non-critical errors
✅ **Confirmation Required** - Budget setup requires billing account verification
✅ **No Data Loss** - Auto-shutdown pauses services, doesn't delete data
✅ **Easy Recovery** - Resume services with one click in Cloud Console

---

## Post-Setup Tasks

After running both scripts:

1. ✅ **Verify budget alerts** in Cloud Console
2. ✅ **Set up Cloud Operations dashboards** (automatic)
3. ⏳ **Define your data model** (manual)
4. ⏳ **Create BigQuery tables** (manual - after data model)
5. ⏳ **Build Cloud Run extractors** (manual)
6. ⏳ **Deploy extractors** (manual)
7. ⏳ **Configure Cloud Scheduler** (manual)
8. ⏳ **Upload reference data** (manual)

---

## Rollback Instructions

If you need to undo the setup:

```bash
# Delete service accounts
gcloud iam service-accounts delete geo-etl@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com
gcloud iam service-accounts delete scheduler@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com
gcloud iam service-accounts delete cloud-run@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com

# Delete buckets
gsutil -m rm -r gs://chicago-bi-app-msds-432-476520-landing
gsutil -m rm -r gs://chicago-bi-app-msds-432-476520-archive

# Delete datasets
bq rm -r -f raw_data
bq rm -r -f cleaned_data
bq rm -r -f analytics
bq rm -r -f reference
bq rm -r -f monitoring

# Delete budget (via Cloud Console - easier than CLI)
# Go to: Billing → Budgets & alerts → Delete

# Delete Cloud Function
gcloud functions delete budget-shutdown-function --region=us-central1
```

---

## Ready to Proceed?

Run the scripts in order:
```bash
cd ~/Desktop/chicago-bi-app

# Step 1: Infrastructure
./setup_gcp_infrastructure.sh

# Step 2: Budget Monitoring
./setup_budget_shutdown.sh
```

---

**Questions or Issues?**
- Check script output for detailed error messages
- Review Cloud Console for resource verification
- All scripts are idempotent (safe to re-run)

**Northwestern MSDSP 432 - Phase 2**
**Group 2: Albin Anto Jose, Myetchae Thu, Ansh Gupta, Bickramjit Basu**
