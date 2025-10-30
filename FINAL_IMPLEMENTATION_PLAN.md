# Chicago BI App - Final Implementation Plan
**Quick Review Before Execution**

---

## 📋 What We're Building

**Project:** Cloud-native data lakehouse for Chicago BI analytics on GCP
**Budget:** $310 USD (₹26,000 credits)
**Timeline:** 4 weeks
**Expected Runtime:** 24 months (2 years) on credits

---

## 🎯 Architecture Decisions Made

### ✅ Confirmed Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| **Orchestration** | Cloud Scheduler (not Composer) | Saves $25-40/month |
| **Geospatial** | BigQuery Geography + GeoPandas | No Cloud SQL needed |
| **Monitoring** | Cloud Operations UI | No custom BigQuery tables |
| **File Format** | JSON → Parquet (Week 2) | 55% cost savings |
| **Data Quality** | Great Expectations | Professional practice |
| **Lineage Tracking** | Manifest table | Full audit trail |
| **Budget Alerts** | 5%, 10%, 20%, 30%, 40%, 50%, 80% | Multi-level warnings |
| **Auto-Shutdown** | At 80% budget | Prevents overspend |
| **BI Engine** | Skip it | Too expensive ($30/month) |
| **Table Schemas** | Define later | You're finalizing data model |

---

## 🚀 Implementation Phases

### Phase 1: Infrastructure Setup (TODAY - 10 minutes)

**Script 1: `setup_gcp_infrastructure.sh` (2-3 min)**

Creates:
- ✅ 7 APIs enabled (Cloud Run, BigQuery, Cloud Scheduler, etc.)
- ✅ 3 service accounts with IAM roles:
  - `geo-etl@...` - For geospatial operations
  - `scheduler@...` - For Cloud Scheduler triggers
  - `cloud-run@...` - For Cloud Run job execution
- ✅ 2 Cloud Storage buckets:
  - `gs://chicago-bi-app-msds-432-476520-landing` (7-day lifecycle)
  - `gs://chicago-bi-app-msds-432-476520-archive` (long-term storage)
- ✅ 5 empty BigQuery datasets (NO tables/schemas):
  - `raw_data` (Bronze layer)
  - `cleaned_data` (Silver layer)
  - `analytics` (Gold layer)
  - `reference` (Dimension tables)
  - `monitoring` (Operational metrics)

Does NOT create:
- ❌ Any table schemas (waiting for your data model)
- ❌ Cloud Run extractors (build/deploy separately)
- ❌ Cloud Scheduler jobs (configure after extractors)

**Script 2: `setup_budget_shutdown.sh` (3-5 min)**

Creates:
- ✅ Budget with 7 alert thresholds
- ✅ Pub/Sub topic for budget notifications
- ✅ Cloud Function for auto-shutdown at 80%
- ✅ Email alerts at each threshold

Auto-shutdown behavior:
- At 80% ($248 of $310): Pauses all Cloud Scheduler jobs
- Running jobs complete gracefully
- Email notification sent
- Easy resume: One click in Cloud Console

---

### Phase 2: Core ETL (Week 1)

**What you'll build:**
- Go extractors (JSON output initially)
- Deploy to Cloud Run Jobs
- Configure Cloud Scheduler (daily 3 AM)
- First test extraction

**Cost:** $0 (using free tier)

---

### Phase 3: Data Quality & Validation (Week 2)

**Production features to add:**

1. **Quarantine Bucket**
   ```bash
   gsutil mb gs://chicago-bi-app-msds-432-476520-quarantine
   ```

2. **Manifest Table**
   ```sql
   CREATE TABLE landing.file_manifest (
     file_uri STRING,
     dataset STRING,
     partition_date DATE,
     row_count INT64,
     validation_status STRING,
     loaded_to_bronze BOOL
   ) PARTITION BY partition_date;
   ```

3. **Great Expectations Validation**
   - Install in extractors: `pip install great-expectations`
   - Define expectations for each dataset
   - Validation-before-bronze workflow
   - Failed data → quarantine + alert

4. **Dataflow JSON→Parquet Conversion**
   - Converts JSON to Parquet in-flight
   - 10x compression, 90% query cost savings
   - Runs automatically after extraction

**Cost:** ~$3/month (Dataflow + validation)

---

### Phase 4: Optimization & Production (Week 3)

**Tasks:**
- Define table schemas (your data model finalized)
- Create BigQuery tables
- Implement Bronze→Silver→Gold transformations
- Set up materialized views (free caching)
- Upload geospatial reference data
- Configure Cloud Operations dashboards

**Cost:** Same as Week 2

---

### Phase 5: Testing & Presentation (Week 4)

**Tasks:**
- End-to-end testing
- Data quality documentation
- Performance tuning
- Looker Studio dashboards
- Presentation preparation

**Cost:** Same as Week 2

---

## 💰 Final Cost Breakdown

### Monthly Costs (Production Configuration)

| Component | Week 1 | Week 2-4 | Notes |
|-----------|--------|----------|-------|
| **BigQuery Storage** | $2.07 | $0.50 | Parquet = 10x compression |
| **BigQuery Queries** | $18.75 | $5.00 | Parquet = 10x less scanning |
| **Cloud Storage** | $4.60 | $1.00 | Faster deletion (7-day lifecycle) |
| **Cloud Run** | $1.62 | $1.62 | Extractor execution |
| **Cloud Scheduler** | $0.30 | $0.30 | Daily cron jobs |
| **Cloud Build** | $1.50 | $1.50 | Container builds |
| **Cloud Operations** | $0-4 | $0-4 | Monitoring (likely $0) |
| **Dataflow** | $0 | $2.00 | JSON→Parquet conversion |
| **Great Expectations** | $0 | $1.00 | Data validation |
| **TOTAL** | **$28.84-33** | **$12.92-17** | **55% savings!** |

### Credits Duration

- **Week 1 architecture:** 10.7 months
- **Production architecture:** 24 months (2 years!)
- **Reason:** Parquet compression + validation efficiency

---

## 📊 Key Metrics & Monitoring

### Budget Alerts Timeline

| Threshold | Amount | Expected Date | Action |
|-----------|--------|---------------|--------|
| 5% | $15.50 | Week 2-3 | Email notification |
| 10% | $31.00 | Month 1 | Email notification |
| 20% | $62.00 | Month 2 | Email notification |
| 30% | $93.00 | Month 3 | Email notification |
| 40% | $124.00 | Month 4 | Email notification |
| 50% | $155.00 | Month 5 | Email notification |
| 80% | $248.00 | Month 8-9 | **AUTO-SHUTDOWN** |

### Cloud Operations Dashboards

Access after setup:
- **Monitoring:** https://console.cloud.google.com/monitoring/dashboards?project=chicago-bi-app-msds-432-476520
- **Logging:** https://console.cloud.google.com/logs?project=chicago-bi-app-msds-432-476520
- **Billing:** https://console.cloud.google.com/billing/reports?project=chicago-bi-app-msds-432-476520

**Key Alerts:**
- Pipeline failures (target: 99.5% success)
- Data freshness (<24 hours)
- Query performance (p95 <5 seconds)
- Validation failures (>5% rejection rate)

---

## 🛡️ Data Quality Framework

### Validation Checks (Great Expectations)

For each dataset, validate:
1. ✅ **Schema conformance** - Columns match expected schema
2. ✅ **Row count** - Matches manifest (±1% tolerance)
3. ✅ **Non-null fields** - trip_id, timestamps, coordinates
4. ✅ **Value ranges** - fare > 0, trip_miles between 0-500
5. ✅ **Data types** - Timestamps valid, numbers numeric
6. ✅ **Uniqueness** - trip_id is unique
7. ✅ **Checksums** - SHA256 matches for data integrity

### Quarantine Workflow

```
Landing → Validation → {Pass: Bronze, Fail: Quarantine}
                    ↓
              Cloud Monitoring Alert
                    ↓
              Manual Review (30-day retention)
```

---

## 📈 Data Lineage

### Manifest Table Tracks

Every file processed:
- ✅ Source URI and metadata (size, rows, checksum)
- ✅ Extraction details (timestamp, version, duration)
- ✅ Validation results (passed/failed checks)
- ✅ Bronze load status (success, job ID, rows loaded)
- ✅ Quarantine status (if failed, why)

### Lineage Queries Available

```sql
-- Data freshness by dataset
SELECT dataset, MAX(partition_date), HOURS_SINCE_UPDATE
FROM landing.file_manifest GROUP BY dataset;

-- Validation success rate
SELECT dataset,
       100.0 * SUM(validation_passed) / COUNT(*) AS success_rate
FROM landing.file_manifest GROUP BY dataset;

-- Missing dates
SELECT date FROM expected_dates
WHERE date NOT IN (SELECT partition_date FROM manifest);
```

---

## 🎓 Academic Project Value

### What Makes This Production-Ready?

1. ✅ **Enterprise data quality** - Great Expectations validation
2. ✅ **Full audit trail** - Manifest tracking and lineage
3. ✅ **Cost optimization** - 55% savings via Parquet
4. ✅ **Automated monitoring** - Cloud Operations integration
5. ✅ **Budget controls** - Multi-level alerts + auto-shutdown
6. ✅ **Data governance** - Quarantine workflow for bad data
7. ✅ **Scalability** - Handles 150K → 150M rows seamlessly

### Portfolio Highlights

- "Implemented medallion lakehouse architecture on GCP"
- "Reduced data costs 55% via columnar storage optimization"
- "Built automated data quality framework with Great Expectations"
- "Established full data lineage from source to dashboard"
- "Configured multi-tier budget monitoring with auto-shutdown"
- "Designed for 186M row scale with 7-year retention capability"

---

## ⚠️ Important Notes

### What's NOT in Today's Setup

1. ❌ **Table schemas** - You're finalizing data model (create in Week 2-3)
2. ❌ **Extractors** - Build separately after infrastructure ready
3. ❌ **Parquet conversion** - Add in Week 2 (start with JSON for speed)
4. ❌ **Great Expectations** - Add in Week 2 (validation layer)
5. ❌ **Cloud Scheduler jobs** - Configure after extractors deployed

### Safety Features

- ✅ **Idempotent scripts** - Safe to run multiple times
- ✅ **No data loss** - Auto-shutdown pauses, doesn't delete
- ✅ **Easy rollback** - Simple commands provided
- ✅ **No destructive actions** - Only creates, never deletes existing resources

### Resume After Auto-Shutdown

If auto-shutdown triggers at 80%:
1. Go to Cloud Console → Cloud Scheduler
2. Select all jobs
3. Click "Resume"
4. Jobs restart on schedule

---

## 📝 Execution Checklist

### Pre-Flight Checks

- [ ] GCP project created: `chicago-bi-app-msds-432-476520` ✅
- [ ] Billing account linked ✅
- [ ] Authenticated with gcloud: `albinjose.msds.nu@gmail.com` ✅
- [ ] Service account exists: `geo-etl@...` ✅
- [ ] BigQuery API enabled ✅
- [ ] Located in correct directory: `~/Desktop/chicago-bi-app`

### What Will Happen

**Step 1: Infrastructure Setup (2-3 min)**
```bash
./setup_gcp_infrastructure.sh
```
- Enables 7 APIs
- Creates 3 service accounts
- Creates 2 storage buckets
- Creates 5 empty datasets
- Configures IAM permissions

**Expected output:**
```
✅ Active project set to chicago-bi-app-msds-432-476520
✅ All required APIs enabled
✅ Created service accounts: geo-etl, scheduler, cloud-run
✅ Created buckets: landing, archive
✅ Created datasets: raw_data, cleaned_data, analytics, reference, monitoring
✅ GCP Infrastructure setup completed successfully!
```

**Step 2: Budget Setup (3-5 min)**
```bash
./setup_budget_shutdown.sh
```
- Retrieves billing account ID
- Creates budget with 7 alert thresholds
- Deploys Cloud Function for auto-shutdown
- Configures Pub/Sub topic
- Sets up email notifications

**Expected output:**
```
✅ Billing Account ID: <YOUR_BILLING_ACCOUNT>
✅ Required APIs enabled
✅ Created topic: budget-alerts
✅ Budget alerts configured
✅ Auto-shutdown Cloud Function deployed
✅ Permissions configured
✅ Budget monitoring and auto-shutdown configured!
```

**Step 3: Verification (1 min)**
```bash
# Check service accounts
gcloud iam service-accounts list

# Check buckets
gsutil ls

# Check datasets
bq ls

# Check Cloud Operations UI
open https://console.cloud.google.com/monitoring
```

---

## 🚦 Decision Points

### Do you want to proceed with:

1. ✅ **Infrastructure setup** (no table schemas) → YES
2. ✅ **Budget monitoring** (7 alerts + auto-shutdown) → YES
3. ✅ **Cloud Operations UI** (not custom tables) → YES
4. ✅ **Production features in Week 2** (Parquet, Great Expectations) → YES
5. ✅ **24-month credit duration** (vs 10.7 months) → YES

### Any changes needed?

- Change budget thresholds? (currently 5%, 10%, 20%, 30%, 40%, 50%, 80%)
- Different auto-shutdown percentage? (currently 80%)
- Different service account names?
- Different bucket names?
- Skip any components?

---

## ⏱️ Time Estimate

- **Read this document:** 5 minutes
- **Run infrastructure setup:** 2-3 minutes
- **Run budget setup:** 3-5 minutes
- **Verify in Cloud Console:** 2 minutes
- **TOTAL:** ~15 minutes

---

## 🎯 Ready to Execute?

**If everything looks good, we'll proceed with:**
```bash
cd ~/Desktop/chicago-bi-app
./setup_gcp_infrastructure.sh
./setup_budget_shutdown.sh
```

**Any questions or changes before we start?**

---

**Last Updated:** October 30, 2025
**Northwestern MSDSP 432 - Phase 2**
**Group 2: Albin Anto Jose, Myetchae Thu, Ansh Gupta, Bickramjit Basu**
