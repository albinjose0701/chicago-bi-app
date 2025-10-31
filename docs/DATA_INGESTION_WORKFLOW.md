# Chicago BI App - Complete Data Ingestion Workflow

**Northwestern MSDS 432 - Phase 2**

This document describes the complete data ingestion strategy combining historical backfills with incremental daily updates.

---

## Overview

### Strategy Summary

1. **Historical Backfills**: Process quarterly or monthly batches for historical data
2. **Gold Layer Processing**: Transform raw data into analytics-ready tables
3. **Manual Archival**: Export processed data to GCS Coldline after analysis
4. **Incremental Updates**: Daily extraction with monthly archiving for ongoing data

### Key Benefits

- ✅ **Cost-Efficient**: Only pay for active data in BigQuery, archive historical data cheaply
- ✅ **Flexible**: Use quarterly batches for speed, monthly for granular control
- ✅ **Manual Control**: You decide when to archive, no auto-deletion surprises
- ✅ **Scalable**: Daily partitions make incremental updates seamless

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    HISTORICAL BACKFILL                      │
│   (Quarterly or Monthly Batches - One-Time)                 │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              BRONZE LAYER (BigQuery)                        │
│  • Daily partitions (90 for quarter, 28-31 for month)      │
│  • No auto-expiration (manual control)                      │
│  • Example: 2020-01-01, 2020-01-02, ..., 2020-03-31        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│         SILVER LAYER (Cleaned & Enriched)                   │
│  • Geospatial enrichment (zip codes, distances)             │
│  • Data quality checks                                      │
│  • Business logic applied                                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              GOLD LAYER (Analytics Ready)                   │
│  • Pre-aggregated metrics                                   │
│  • Dashboard-optimized tables                               │
│  • Analysis complete ✅                                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│         MANUAL ARCHIVAL (After Analysis)                    │
│  • Export to GCS Coldline (Parquet format)                  │
│  • Delete BigQuery partitions to save costs                 │
│  • Cost: $0.004/GB/month (vs $0.02/GB in BigQuery)         │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           INCREMENTAL DAILY UPDATES                         │
│  • Daily Cloud Scheduler triggers                           │
│  • Process to gold layer automatically                      │
│  • Archive monthly (optional)                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Detailed Workflows

### 1. Historical Quarterly Backfill (Q1 2020 Example)

**Use Case**: Fast historical data ingestion for an entire quarter

#### Step 1: Run Quarterly Backfill

```bash
cd ~/Desktop/chicago-bi-app/backfill

# Make script executable
chmod +x quarterly_backfill_q1_2020.sh

# Run for all datasets (taxi + TNP)
./quarterly_backfill_q1_2020.sh all

# OR run for specific dataset
./quarterly_backfill_q1_2020.sh taxi
```

**What happens:**
- Executes Cloud Run job for 90 dates (Jan 1 - Mar 31, 2020)
- Each execution ingests 1 day of data
- 30-second delay between runs to avoid rate limits
- Creates log file: `backfill_q1_2020_all_YYYYMMDD_HHMMSS.log`

**Cost**: ~$1.50 one-time (90 executions × $0.012 per run)

**Time**: ~45 minutes per dataset (90 days × 30 seconds)

#### Step 2: Verify Data Ingestion

```bash
# Check partition count (should be 90 for Q1)
bq query --use_legacy_sql=false \
  "SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as partition_count
   FROM \`chicago-bi.raw_data.raw_taxi_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"

# Check row count per day
bq query --use_legacy_sql=false \
  "SELECT DATE(trip_start_timestamp) AS date, COUNT(*) as trips
   FROM \`chicago-bi.raw_data.raw_taxi_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'
   GROUP BY date
   ORDER BY date"
```

**Expected output:**
```
partition_count: 90
```

---

### 2. Historical Monthly Backfill (Flexible)

**Use Case**: Granular control for specific months

#### Run Monthly Backfill

```bash
cd ~/Desktop/chicago-bi-app/backfill

# Make script executable
chmod +x monthly_backfill.sh

# January 2020
./monthly_backfill.sh 2020-01 all

# February 2020
./monthly_backfill.sh 2020-02 all

# March 2020
./monthly_backfill.sh 2020-03 all
```

**What happens:**
- Executes Cloud Run job for 28-31 dates (depending on month)
- Same process as quarterly, but for a single month
- Creates log file: `backfill_2020-01_all_YYYYMMDD_HHMMSS.log`

**Cost**: ~$0.40-0.60 per month (30 executions × $0.012)

**Time**: ~15 minutes per dataset per month

---

### 3. Process to Gold Layer

After backfilling data to bronze layer, process it to gold layer for analysis.

#### Create Gold Layer Tables

Example gold layer table (you'll customize based on your analysis needs):

```sql
-- Create aggregated daily metrics table
CREATE TABLE IF NOT EXISTS `chicago-bi.analytics.daily_trip_metrics`
(
  date DATE NOT NULL,
  total_trips INT64,
  total_revenue FLOAT64,
  avg_trip_miles FLOAT64,
  avg_fare FLOAT64,
  unique_taxis INT64,

  -- By payment type
  cash_trips INT64,
  credit_trips INT64,
  mobile_trips INT64,

  -- Geospatial metrics
  top_pickup_area STRING,
  top_dropoff_area STRING
)
PARTITION BY date
CLUSTER BY date
OPTIONS(
  description = "Daily aggregated taxi trip metrics for dashboards"
);

-- Insert aggregated data for Q1 2020
INSERT INTO `chicago-bi.analytics.daily_trip_metrics`
SELECT
  DATE(trip_start_timestamp) as date,
  COUNT(*) as total_trips,
  SUM(trip_total) as total_revenue,
  AVG(trip_miles) as avg_trip_miles,
  AVG(fare) as avg_fare,
  COUNT(DISTINCT taxi_id) as unique_taxis,

  COUNTIF(payment_type = 'Cash') as cash_trips,
  COUNTIF(payment_type = 'Credit Card') as credit_trips,
  COUNTIF(payment_type = 'Mobile') as mobile_trips,

  -- Geospatial aggregation (example)
  (SELECT pickup_community_area FROM UNNEST([pickup_community_area])
   GROUP BY pickup_community_area ORDER BY COUNT(*) DESC LIMIT 1) as top_pickup_area,
  (SELECT dropoff_community_area FROM UNNEST([dropoff_community_area])
   GROUP BY dropoff_community_area ORDER BY COUNT(*) DESC LIMIT 1) as top_dropoff_area

FROM `chicago-bi.raw_data.raw_taxi_trips`
WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'
GROUP BY date
ORDER BY date;
```

#### Verify Gold Layer

```bash
# Check gold layer data
bq query --use_legacy_sql=false \
  "SELECT date, total_trips, total_revenue
   FROM \`chicago-bi.analytics.daily_trip_metrics\`
   WHERE date BETWEEN '2020-01-01' AND '2020-03-31'
   ORDER BY date LIMIT 10"
```

---

### 4. Manual Archival (After Analysis)

After completing your analysis, archive historical data to save costs.

#### Archive Quarter to GCS Coldline

```bash
cd ~/Desktop/chicago-bi-app/archival

# Make script executable
chmod +x archive_quarter.sh

# Archive Q1 2020 (all layers: bronze, silver, gold)
./archive_quarter.sh 2020-Q1 all

# OR archive specific layer
./archive_quarter.sh 2020-Q1 bronze
```

**What happens:**
1. Exports BigQuery data to GCS in Parquet format (10x compression)
2. Sets storage class to Coldline ($0.004/GB/month)
3. Creates archive at: `gs://chicago-bi-archive/raw_data/raw_taxi_trips/2020-Q1/*.parquet`

**Cost savings:**
- BigQuery active storage: $0.02/GB/month
- GCS Coldline: $0.004/GB/month
- **Savings: 80% reduction** ($0.016/GB/month saved)

Example for 20GB Q1 data:
- Before archival: 20GB × $0.02 = $0.40/month
- After archival: 20GB × $0.004 = $0.08/month
- **Monthly savings: $0.32**

#### Verify Archive

```bash
# List archived files
gsutil ls -lh gs://chicago-bi-app-msds-432-476520-archive/raw_data/raw_taxi_trips/2020-Q1/

# Check total size
gsutil du -sh gs://chicago-bi-app-msds-432-476520-archive/raw_data/raw_taxi_trips/2020-Q1/
```

#### OPTIONAL: Delete BigQuery Partitions

**⚠️ WARNING**: Only do this AFTER verifying archive is complete!

```bash
# Delete archived partitions to save BigQuery storage costs
bq query --use_legacy_sql=false \
  "DELETE FROM \`chicago-bi.raw_data.raw_taxi_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
```

#### Restore from Archive (If Needed)

```bash
# Restore archived data back to BigQuery
bq load \
  --source_format=PARQUET \
  --replace \
  chicago-bi:raw_data.raw_taxi_trips \
  gs://chicago-bi-app-msds-432-476520-archive/raw_data/raw_taxi_trips/2020-Q1/*.parquet
```

---

### 5. Incremental Daily Updates

After historical backfill is complete, enable daily incremental updates.

#### Setup Daily Scheduler

```bash
cd ~/Desktop/chicago-bi-app/scheduler

# Deploy daily extraction scheduler
./daily_extract.sh

# This creates Cloud Scheduler jobs:
# - daily-taxi-extract (runs at 8 AM UTC = 3 AM Central)
# - daily-tnp-extract
# - daily-covid-extract
# - daily-permits-extract
```

**What happens:**
- Cloud Scheduler triggers Cloud Run job daily
- Extracts yesterday's data (MODE=incremental)
- Loads to bronze layer (creates new daily partition)
- Automatically processes to gold layer (optional - you can add this)

#### Monitor Daily Runs

```bash
# Check recent executions
gcloud run jobs executions list \
  --job=extractor-taxi \
  --region=us-central1 \
  --limit=10

# View logs
gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.job_name=extractor-taxi" \
  --limit=50 \
  --format=json
```

#### Monthly Archival for Incremental Data

After each month of incremental updates, optionally archive:

```bash
# End of each month, archive that month
./archive_quarter.sh 2025-Q4 bronze  # Or use archive_month.sh if you create it
```

---

## Cost Breakdown

### One-Time Historical Backfill (Q1 2020)

| Component | Calculation | Cost |
|-----------|-------------|------|
| Cloud Run executions | 90 days × $0.012 | $1.08 |
| BigQuery storage (during processing) | 20GB × $0.02 × 1 month | $0.40 |
| Cloud Storage (landing, auto-deleted) | 3GB × $0.023 × 1 month | $0.07 |
| **TOTAL ONE-TIME** | | **$1.55** |

### Ongoing Monthly Costs

| Component | Calculation | Cost |
|-----------|-------------|------|
| Daily Cloud Run (30 executions) | 30 × $0.012 | $0.36 |
| BigQuery active data (30 days) | 20GB × $0.02 | $0.40 |
| Archived data (Coldline) | 20GB × $0.004 | $0.08 |
| Cloud Scheduler | 1 job × $0.10 | $0.10 |
| **TOTAL MONTHLY (with archive)** | | **$0.94** |

### Budget Impact

- Total credits: **$310**
- Baseline monthly: **$28.84**
- With Q1 2020 backfill + archive: **$28.84 + $0.94 = $29.78/month**
- **Credits duration: $310 ÷ $29.78 = 10.4 months** (still within budget!)

---

## Best Practices

### 1. Daily Partitioning Strategy

✅ **DO:**
- Use daily partitions: `PARTITION BY DATE(trip_start_timestamp)`
- This creates 90 partitions for Q1 (one per day)
- Allows granular querying and efficient archival

❌ **DON'T:**
- Use monthly partitions (loses granularity)
- Skip partitioning (expensive queries)

### 2. Manual Archival Timing

✅ **DO:**
- Archive AFTER completing all analysis
- Verify archive before deleting BigQuery partitions
- Keep gold layer in BigQuery for dashboards

❌ **DON'T:**
- Archive before analysis is complete
- Delete BigQuery data without verification
- Archive gold layer (keep for dashboards)

### 3. Quarterly vs Monthly Backfills

**Use Quarterly when:**
- Need fast historical ingestion (one script execution)
- Processing multiple quarters
- Team coordination on quarter boundaries

**Use Monthly when:**
- Need granular control per month
- Testing incremental backfills
- Budget constraints (spread cost across months)

### 4. Incremental Updates

✅ **DO:**
- Enable daily scheduler after historical backfill
- Monitor Cloud Run execution success rate
- Set up Cloud Monitoring alerts for failures

❌ **DON'T:**
- Run backfill and incremental simultaneously (duplication risk)
- Forget to enable scheduler after backfill
- Archive current month's data (keep active for queries)

---

## Troubleshooting

### Backfill Script Fails

**Symptom:** Script exits with errors

**Solutions:**
1. Check Cloud Run job exists:
   ```bash
   gcloud run jobs list --region=us-central1
   ```

2. Check service account permissions:
   ```bash
   gcloud projects get-iam-policy chicago-bi-app-msds-432-476520 \
     --flatten="bindings[].members" \
     --filter="bindings.members:cloud-run@*"
   ```

3. Check API rate limits:
   - Chicago Data Portal: 1000 requests/hour with app token
   - Add longer delay: Edit `DELAY_SECONDS=60` in backfill script

### Missing Partitions

**Symptom:** Partition count < expected (e.g., 85 instead of 90)

**Solutions:**
1. Check backfill log file:
   ```bash
   cat backfill_q1_2020_all_*.log | grep FAILED
   ```

2. Re-run failed dates:
   ```bash
   ./monthly_backfill.sh 2020-01 taxi  # Re-run specific month
   ```

3. Verify data exists in Chicago Data Portal for that date

### Archive Export Fails

**Symptom:** `bq extract` command fails

**Solutions:**
1. Check BigQuery partition exists:
   ```bash
   bq query --use_legacy_sql=false \
     "SELECT COUNT(*) FROM \`chicago-bi.raw_data.raw_taxi_trips\`
      WHERE DATE(trip_start_timestamp) = '2020-01-15'"
   ```

2. Check GCS bucket permissions:
   ```bash
   gsutil iam get gs://chicago-bi-app-msds-432-476520-archive
   ```

3. Use temporary table approach (script does this automatically)

---

## Summary

### Complete Workflow Checklist

- [ ] **1. Historical Backfill**
  - [ ] Run quarterly or monthly backfill script
  - [ ] Verify partition count matches expected (90 for quarter, 28-31 for month)
  - [ ] Check row counts per day

- [ ] **2. Process to Gold Layer**
  - [ ] Create gold layer table schemas
  - [ ] Run aggregation queries
  - [ ] Verify gold layer data quality

- [ ] **3. Analysis & Dashboards**
  - [ ] Connect Looker Studio to gold layer
  - [ ] Build dashboards
  - [ ] Complete analysis

- [ ] **4. Manual Archival**
  - [ ] Export quarter/month to GCS Coldline
  - [ ] Verify archive files exist
  - [ ] OPTIONAL: Delete BigQuery partitions

- [ ] **5. Enable Incremental Updates**
  - [ ] Deploy Cloud Scheduler jobs
  - [ ] Monitor daily executions
  - [ ] Set up failure alerts

### Key Files Reference

| Script | Purpose | Location |
|--------|---------|----------|
| `quarterly_backfill_q1_2020.sh` | Q1 2020 backfill (90 days) | `/backfill/` |
| `monthly_backfill.sh` | Flexible monthly backfill | `/backfill/` |
| `archive_quarter.sh` | Export to GCS Coldline | `/archival/` |
| `daily_extract.sh` | Setup daily scheduler | `/scheduler/` |
| `bronze_layer.sql` | Bronze table schemas | `/bigquery/schemas/` |

---

**Questions or Issues?**
- Review script logs in current directory
- Check Cloud Console for service status
- All scripts are idempotent (safe to re-run)

**Northwestern MSDS 432 - Phase 2**
**Group 2: Albin Anto Jose, Myetchae Thu, Ansh Gupta, Bickramjit Basu**
