# Building Permits & COVID-19 Backfill Scripts

**Created:** November 5, 2025
**Version:** 1.0.0
**Status:** Production Ready ✅

---

## 📋 Overview

This directory contains network-resilient, caffeinated backfill scripts for loading historical data for:
1. **Building Permits** (2020-2025)
2. **COVID-19 Cases by ZIP Code** (March 2020 - May 2024)

Both scripts feature:
- ⚡ **Ultra-optimized performance** - 2 second delays between API calls
- 🔀 **Parallel execution** - 7-8 workers running concurrently
- 🛡️ **Network resilience** - Automatic retry and recovery
- ☕ **Caffeinated** - System kept awake during execution
- 📊 **Progress tracking** - Real-time logs and progress files
- ✅ **Data verification** - BigQuery validation after each extraction

---

## 📁 Script Files

### Building Permits Backfill
**File:** `permits_backfill_2020_2025.sh`
**Purpose:** Extract all building permit data from 2020-01-01 to 2025-11-05
**Dataset:** ydr8-5enu
**Workers:** 7 parallel processes
**Estimated Time:** 15-20 minutes
**Total Dates:** ~2,162 days
**Expected Records:** ~365,000 permits

### COVID-19 Backfill
**File:** `covid_backfill_2020_2024.sh`
**Purpose:** Extract all COVID-19 weekly data from March 2020 to May 2024
**Dataset:** yhhz-zm2v
**Workers:** 8 parallel processes
**Estimated Time:** 5-10 minutes
**Total Weeks:** ~220 weeks
**Expected Records:** ~13,000 records (59 ZIP codes × 220 weeks)

---

## 🚀 Quick Start

### Prerequisites

1. **GCP Authentication:**
   ```bash
   gcloud auth login
   gcloud config set project chicago-bi-app-msds-432-476520
   ```

2. **Verify Cloud Run Jobs:**
   ```bash
   gcloud run jobs describe extractor-permits --region=us-central1
   gcloud run jobs describe extractor-covid --region=us-central1
   ```

3. **Verify BigQuery Tables:**
   ```bash
   bq show raw_data.raw_building_permits
   bq show raw_data.raw_covid19_cases_by_zip
   ```

4. **Power Requirement:**
   - Connect to AC power (recommended)
   - OR ensure battery is 70%+ charged

### Run Building Permits Backfill

```bash
cd /Users/albin/Desktop/chicago-bi-app/backfill
./permits_backfill_2020_2025.sh
```

When prompted, type `yes` to confirm and start.

### Run COVID-19 Backfill

```bash
cd /Users/albin/Desktop/chicago-bi-app/backfill
./covid_backfill_2020_2024.sh
```

When prompted, type `yes` to confirm and start.

---

## 🔍 How It Works

### Parallel Execution Model

Both scripts use a **worker-based parallel execution model**:

1. **Date/Week Division:**
   - Total date/week range is divided equally among workers
   - Each worker gets an independent subset to process
   - Workers run completely in parallel

2. **Worker Independence:**
   - Each worker has its own log file
   - Each worker has its own progress file
   - Workers don't interfere with each other

3. **Caffeinate Protection:**
   - Each worker runs with `caffeinate -s -i`
   - Prevents system sleep during execution
   - Protects against network disconnections

### Data Flow Per Worker

```
1. Check if date/week exists in BigQuery (skip if exists)
   ↓
2. Wait for network availability
   ↓
3. Execute Cloud Run job with START_DATE parameter
   ↓
4. Wait for job completion (with --wait flag)
   ↓
5. Sleep 3 seconds for BigQuery consistency
   ↓
6. Verify data in BigQuery
   ↓
7. Log success/failure to progress file
   ↓
8. Sleep 2 seconds before next extraction
   ↓
9. Repeat for next date/week
```

### Network Resilience Features

- **Automatic network checks** before each extraction
- **Wait and retry** if network is unavailable (30s intervals)
- **BigQuery verification** after each extraction
- **Progress tracking** - can resume from last successful date/week
- **Independent workers** - if one fails, others continue

---

## 📊 Monitoring Progress

### During Execution

**View all worker logs in real-time:**
```bash
# Permits
tail -f permits_worker_*.log

# COVID-19
tail -f covid_worker_*.log
```

**Check worker processes:**
```bash
ps aux | grep permits_backfill
ps aux | grep covid_backfill
```

**Monitor progress files:**
```bash
# Permits
tail -f permits_worker_*_progress.txt

# COVID-19
tail -f covid_worker_*_progress.txt
```

### After Completion

**Permits verification:**
```bash
bq query --use_legacy_sql=false '
SELECT
  COUNT(*) as total_permits,
  MIN(DATE(issue_date)) as first_date,
  MAX(DATE(issue_date)) as last_date,
  COUNT(DISTINCT DATE(issue_date)) as unique_dates
FROM `chicago-bi-app-msds-432-476520.raw_data.raw_building_permits`
'
```

**COVID-19 verification:**
```bash
bq query --use_legacy_sql=false '
SELECT
  COUNT(*) as total_records,
  MIN(DATE(week_start)) as first_week,
  MAX(DATE(week_start)) as last_week,
  COUNT(DISTINCT DATE(week_start)) as unique_weeks,
  COUNT(DISTINCT zip_code) as unique_zips
FROM `chicago-bi-app-msds-432-476520.raw_data.raw_covid19_cases_by_zip`
'
```

---

## 📝 Log Files

### Master Logs
- `permits_backfill_master_YYYYMMDD_HHMMSS.log` - Overall execution log
- `covid_backfill_master_YYYYMMDD_HHMMSS.log` - Overall execution log

### Worker Logs
- `permits_worker_1_YYYYMMDD_HHMMSS.log` through `permits_worker_7_*.log`
- `covid_worker_1_YYYYMMDD_HHMMSS.log` through `covid_worker_8_*.log`

### Progress Files (CSV Format)
- `permits_worker_1_progress.txt` - `date,permits_count,timestamp`
- `covid_worker_1_progress.txt` - `week_start,records_count,timestamp`

**Progress file format:**
```csv
date,permits_count,timestamp
2020-01-01,156,2025-11-05T19:30:00Z
2020-01-02,0,2025-11-05T19:30:05Z [ZERO]
2020-01-03,234,2025-11-05T19:30:10Z
2020-01-04,189,2025-11-05T19:30:15Z [SKIPPED]
```

Status indicators:
- **No indicator** - Successful new extraction
- **[SKIPPED]** - Data already existed, skipped
- **[ZERO]** - Extraction successful but 0 records (no data for that date)
- **[FAILED]** - Extraction failed

---

## ⚠️ Troubleshooting

### Script Won't Start

**Problem:** `Permission denied`
```bash
# Solution: Make script executable
chmod +x permits_backfill_2020_2025.sh
chmod +x covid_backfill_2020_2024.sh
```

**Problem:** `Cloud Run job not found`
```bash
# Solution: Check if jobs exist
gcloud run jobs list --region=us-central1

# If missing, deploy extractors first
cd /Users/albin/Desktop/chicago-bi-app/extractors/permits
gcloud builds submit --config cloudbuild.yaml
```

### Network Issues

**Problem:** "Network unavailable" messages
```bash
# The script will automatically wait and retry
# Check your internet connection
ping -c 5 8.8.8.8

# Check VPN if applicable
# Restart WiFi if needed
```

### Worker Failures

**Problem:** Some workers failed
```bash
# 1. Check individual worker logs
cat permits_worker_3_*.log | grep FAILED

# 2. Check which dates/weeks failed
cat permits_worker_3_progress.txt | grep FAILED

# 3. Manual re-run for specific date
gcloud run jobs execute extractor-permits \
  --region=us-central1 \
  --update-env-vars="START_DATE=2020-03-15" \
  --wait

# 4. Verify in BigQuery
bq query --use_legacy_sql=false "
SELECT COUNT(*) FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_building_permits\`
WHERE DATE(issue_date) = '2020-03-15'
"
```

### Resume From Checkpoint

Both scripts automatically skip dates/weeks that already exist in BigQuery, so you can safely re-run them:

```bash
# Re-run permits backfill (will skip existing dates)
./permits_backfill_2020_2025.sh

# Re-run COVID backfill (will skip existing weeks)
./covid_backfill_2020_2024.sh
```

---

## 🎯 Performance Expectations

### Building Permits

| Metric | Value |
|--------|-------|
| Total Days | ~2,162 |
| Workers | 7 |
| Days per Worker | ~309 |
| Time per Day | ~5 seconds (2s delay + 3s verification) |
| Time per Worker | ~25 minutes |
| Total Time (parallel) | ~15-20 minutes |
| Expected Permits | ~365,000 |

### COVID-19

| Metric | Value |
|--------|-------|
| Total Weeks | ~220 |
| Workers | 8 |
| Weeks per Worker | ~27-28 |
| Time per Week | ~5 seconds (2s delay + 3s verification) |
| Time per Worker | ~2-3 minutes |
| Total Time (parallel) | ~5-10 minutes |
| Expected Records | ~13,000 (59 ZIPs × 220 weeks) |

---

## 🔧 Configuration Options

### Modify Parallel Workers

Edit the script files to change the number of parallel workers:

```bash
# In permits_backfill_2020_2025.sh
PARALLEL_WORKERS=7  # Change to 5, 8, 10, etc.

# In covid_backfill_2020_2024.sh
PARALLEL_WORKERS=8  # Change to 6, 10, 12, etc.
```

**Recommendations:**
- **Fewer workers (4-5):** More conservative, lower API load
- **More workers (10-12):** Faster completion, higher API load
- **Optimal (7-8):** Balanced performance and stability

### Modify Delay Between Calls

```bash
# In both scripts
DELAY_SECONDS=2  # Change to 1, 3, 5, etc.
```

**Recommendations:**
- **1 second:** Maximum speed, may hit rate limits
- **2 seconds:** Optimal balance (current setting)
- **5 seconds:** Conservative, guaranteed no rate limits

### Modify Date Ranges

```bash
# Permits backfill
START_DATE="2020-01-01"  # Change start date
END_DATE="2025-11-05"    # Change end date

# COVID backfill
START_DATE="2020-03-01"  # First Sunday in March 2020
END_DATE="2024-05-19"    # Last week in May 2024
```

---

## 📈 Expected Results

### Building Permits

After successful completion:
- **Total permits:** ~365,000
- **Date range:** 2020-01-01 to 2025-11-05
- **Unique dates:** ~2,162
- **Average permits/day:** ~169
- **Geographic coverage:** 100% (all records have coordinates)

**Sample query:**
```sql
SELECT
  EXTRACT(YEAR FROM issue_date) as year,
  COUNT(*) as permits,
  AVG(total_fee) as avg_fee,
  COUNT(DISTINCT community_area) as areas
FROM `chicago-bi-app-msds-432-476520.raw_data.raw_building_permits`
GROUP BY year
ORDER BY year
```

### COVID-19

After successful completion:
- **Total records:** ~13,000
- **Unique weeks:** ~220
- **Unique ZIP codes:** 59
- **Records per week:** ~59 (one per ZIP)
- **Privacy suppression:** Counts <5 appear as NULL

**Sample query:**
```sql
SELECT
  zip_code,
  SUM(cases_weekly) as total_cases,
  SUM(deaths_weekly) as total_deaths,
  AVG(population) as avg_population
FROM `chicago-bi-app-msds-432-476520.raw_data.raw_covid19_cases_by_zip`
WHERE cases_weekly IS NOT NULL
GROUP BY zip_code
ORDER BY total_cases DESC
LIMIT 10
```

---

## 🎉 Success Criteria

### Building Permits ✅
- [ ] All 7 workers completed successfully
- [ ] ~365,000 permits loaded
- [ ] Date range: 2020-01-01 to 2025-11-05
- [ ] No FAILED entries in progress files
- [ ] Geographic data 100% populated

### COVID-19 ✅
- [ ] All 8 workers completed successfully
- [ ] ~13,000 records loaded
- [ ] Week range: 2020-03-01 to 2024-05-19
- [ ] ~220 unique weeks
- [ ] 59 ZIP codes represented

---

## 📚 Related Documentation

- **Extractors README:**
  - `/Users/albin/Desktop/chicago-bi-app/extractors/permits/README.md`
  - `/Users/albin/Desktop/chicago-bi-app/extractors/covid/README.md`

- **Session Context:**
  - `/Users/albin/Desktop/session-contexts/v2.8.0_SESSION_2025-11-05_PERMITS_COVID_EXTRACTORS.md`

- **Version Index:**
  - `/Users/albin/Desktop/session-contexts/VERSION_INDEX.md`

---

## 🚦 Next Steps After Backfill

1. **Verify Data Quality:**
   ```bash
   # Check for gaps in dates
   # Check for reasonable record counts
   # Verify geographic data completeness
   ```

2. **Update Session Context:**
   - Create v2.9.0 session context file
   - Document backfill results
   - Update VERSION_INDEX.md

3. **Create Analytics Views:**
   - Silver layer transformations
   - Aggregated tables (monthly, by type, by area)
   - Combined views with taxi/TNP data

4. **Build Dashboards:**
   - Permit trends visualization
   - COVID timeline analysis
   - Geographic heat maps

5. **Schedule Incremental Updates:**
   - Daily permit extractions
   - No COVID updates (historical only)

---

**Created:** November 5, 2025
**Author:** Claude Code
**Version:** 1.0.0
**Status:** Production Ready ✅

*Network-resilient, caffeinated, and ready to rock! ☕⚡*
