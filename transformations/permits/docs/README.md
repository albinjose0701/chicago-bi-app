# Building Permits Data Pipeline

**Version:** 1.0.0
**Created:** November 21, 2025
**Purpose:** Automated incremental data transformations for building permits
**Strategy:** MERGE-based incremental updates with orchestrated execution

---

## Overview

This pipeline automatically processes building permits data through the data layers:

```
raw_building_permits
    ↓ (01_bronze_permits_incremental.sql)
bronze_building_permits
    ↓ (02_silver_permits_incremental.sql)
silver_permits_enriched
    ↓ (03_gold_permits_aggregates.sql)
gold_permits_roi + gold_loan_targets
```

---

## Key Features

✅ **Incremental Processing** - Only processes new/updated records (last 7 days)
✅ **Idempotent** - Safe to re-run without duplicates
✅ **MERGE-based** - Bronze & Silver use MERGE, Gold uses DELETE + INSERT
✅ **Orchestrated** - Python script runs layers in sequence
✅ **Error Handling** - Stops on failure, logs errors
✅ **Statistics** - Reports record counts and timestamps

---

## Files

| File | Purpose | Strategy |
|------|---------|----------|
| `01_bronze_permits_incremental.sql` | Raw → Bronze | MERGE on `id` |
| `02_silver_permits_incremental.sql` | Bronze → Silver (enriched) | MERGE on `id` |
| `03_gold_permits_aggregates.sql` | Silver → Gold (aggregates) | DELETE + INSERT |
| `run_pipeline.py` | Orchestration script | Runs all 3 SQLs in order |
| `Dockerfile` | Container image | For Cloud Run deployment |
| `requirements.txt` | Python dependencies | google-cloud-bigquery |

---

## Usage

### Local Execution

**Prerequisites:**
- Python 3.9+
- Google Cloud SDK authenticated
- BigQuery permissions (Data Editor)

**Run pipeline:**
```bash
cd /Users/albin/Desktop/chicago-bi-app/transformations/permits
python3 run_pipeline.py
```

**Output:**
- Logs to stdout
- Shows progress for each layer
- Reports statistics after each transformation
- Exit code 0 = success, 1 = failure

---

### Cloud Run Execution

**Deploy as Cloud Run job:**
```bash
# Build and deploy
gcloud builds submit --config=cloudbuild.yaml

# Or manual trigger
gcloud run jobs execute permits-pipeline \
  --region=us-central1 \
  --project=chicago-bi-app-msds-432-476520
```

---

## Incremental Logic

### Bronze Layer (01)
- **Filter:** `extracted_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)`
- **Matches:** Processes records extracted in last 7 days
- **Updates:** Existing records with matching `id`
- **Inserts:** New records not in bronze

### Silver Layer (02)
- **Filter:** `extracted_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)` from bronze
- **Enrichment:** Spatial joins for ZIP code and neighborhood
- **Updates:** Existing records (if coordinates changed)
- **Inserts:** New enriched records

### Gold Layer (03)
- **Strategy:** Full refresh (DELETE + INSERT)
- **Reason:** Small aggregates, fast to rebuild
- **Tables:** `gold_permits_roi` (59 ZIPs), `gold_loan_targets` (58 ZIPs)

---

## Data Flow

### Input: raw_building_permits
- Source: Chicago Data Portal extractor
- Updates: Daily or weekly extraction
- Records: ~200K+ historical, +50-150 new per day

### Output: Multiple layers

**Bronze (bronze_building_permits):**
- Filters: Valid coordinates, date range
- Partitioned: By `issue_date`
- Clustered: By `community_area`

**Silver (silver_permits_enriched):**
- Adds: `zip_code`, `neighborhood`, `permit_year`, `permit_month`
- Partitioned: By `issue_date`
- Clustered: By `community_area`, `permit_type`

**Gold:**
- `gold_permits_roi`: Aggregated metrics by ZIP
- `gold_loan_targets`: Loan eligibility scores by ZIP

---

## Scheduling

### Recommended Schedule

**Option 1: Weekly (Recommended)**
- Run every Monday 3 AM CT (after permits extraction at 2 AM)
- Processes ~336 new permits per week
- Low cost, sufficient for dashboard needs

**Option 2: Daily**
- Run every day 3 AM CT (1 hour after extraction)
- Processes ~48 new permits per day
- Higher cost, maximum freshness

**Implementation:**
```bash
# Cloud Scheduler job (triggers Cloud Run pipeline)
gcloud scheduler jobs create http permits-pipeline-weekly \
  --location=us-central1 \
  --schedule="0 3 * * 1" \
  --time-zone="America/Chicago" \
  --uri="https://us-central1-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/chicago-bi-app-msds-432-476520/jobs/permits-pipeline:run" \
  --http-method=POST \
  --oauth-service-account-email="..." \
  --description="Weekly permits transformation pipeline (Monday 3 AM)"
```

---

## Performance

### Execution Times (Estimated)

| Layer | Records Processed | Time (Incremental) | Time (Full) |
|-------|-------------------|-------------------|-------------|
| Bronze | ~1,366 (2 weeks) | 5-10 seconds | 30-60 seconds |
| Silver | ~1,366 (spatial) | 30-60 seconds | 2-3 minutes |
| Gold | 59 ZIPs | 10-15 seconds | 10-15 seconds |
| **Total** | - | **1-2 minutes** | **3-5 minutes** |

**Cost:** ~$0.01-0.05 per run (BigQuery processing)

---

## Monitoring & Verification

### Check Pipeline Success

**Last execution timestamps:**
```sql
SELECT
  'Bronze' as layer,
  MAX(extracted_at) as last_update,
  COUNT(*) as total_records
FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_building_permits`
UNION ALL
SELECT
  'Silver' as layer,
  MAX(enriched_at) as last_update,
  COUNT(*) as total_records
FROM `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched`
UNION ALL
SELECT
  'Gold - Permits ROI' as layer,
  MAX(created_at) as last_update,
  COUNT(*) as total_records
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_permits_roi`;
```

### Check for Duplicates

**Bronze & Silver should have no duplicates:**
```sql
-- Bronze duplicates check
SELECT
  id,
  COUNT(*) as occurrences
FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_building_permits`
GROUP BY id
HAVING COUNT(*) > 1;

-- Silver duplicates check
SELECT
  id,
  COUNT(*) as occurrences
FROM `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched`
GROUP BY id
HAVING COUNT(*) > 1;
```

Both should return **0 rows** (no duplicates).

---

## Troubleshooting

### Issue: "Table already exists" error
- **Cause:** First run with CREATE TABLE
- **Fix:** Tables auto-create on first run, re-run pipeline

### Issue: No new records processed
- **Cause:** No raw data extracted in last 7 days
- **Fix:** Run extractor first, then pipeline

### Issue: Spatial joins missing ZIPs
- **Cause:** Coordinates outside Chicago or reference data missing
- **Check:** Verify zip_code_boundaries and neighborhood_boundaries exist

### Issue: Gold tables empty
- **Cause:** Silver table empty or filters too restrictive
- **Fix:** Check silver layer has data, review WHERE clauses

---

## Development Notes

### Modifying Incremental Window

To change from 7 days to different window:

**In `01_bronze_permits_incremental.sql` line 51:**
```sql
extracted_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
-- Change 7 to desired days
```

**In `02_silver_permits_incremental.sql` line 79:**
```sql
p.extracted_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
-- Change 7 to match bronze window
```

### Full Refresh (Reprocess All Data)

To force full refresh (not incremental):

**Option A:** Delete layer tables first
```sql
DROP TABLE `chicago-bi-app-msds-432-476520.bronze_data.bronze_building_permits`;
DROP TABLE `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched`;
```
Then run pipeline (will recreate and load all data).

**Option B:** Remove incremental filter from SQLs
- Comment out `extracted_at >= TIMESTAMP_SUB(...)` lines
- Pipeline will process all raw data

---

## Dependencies

**Reference Tables (Must Exist):**
- `reference_data.zip_code_boundaries` - For ZIP spatial joins
- `reference_data.neighborhood_boundaries` - For neighborhood spatial joins
- `reference_data.crosswalk_community_zip` - For loan targets
- `bronze_data.bronze_public_health` - For per capita income
- `silver_data.silver_covid_weekly_historical` - For population

**Source Tables (Must Have Data):**
- `raw_data.raw_building_permits` - From extractor

---

## Future Enhancements

1. **Add data quality checks** - Row count validation, null checks
2. **Email notifications** - On success/failure
3. **Incremental date tracking** - Store last processed date in metadata table
4. **Parallel execution** - Run bronze for multiple date ranges in parallel
5. **Dashboard refresh trigger** - Auto-refresh Looker Studio after pipeline
6. **Backfill utility** - Script to reprocess specific date ranges

---

**Created by:** Claude Code
**Version:** 1.0.0
**Last Updated:** November 21, 2025
