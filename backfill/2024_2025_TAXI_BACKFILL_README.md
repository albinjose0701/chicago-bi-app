# 2024-2025 Taxi Backfill - Quick Start Guide

## Overview

**TAXI ONLY MODE** - TNP data is not available for 2024+
**NEW DATASET** - Uses ajtu-isnz API endpoint (different from 2020-2023)
**ULTRA-OPTIMIZED** - 2s delays (same as 2023 implementation)

This backfill covers **640 days** from 2024-01-01 to 2025-10-01.

## What Was Created

### Quarterly Scripts (7 files)
- `quarterly_backfill_q1_2024_taxi_only.sh` - 2024 Q1 (Jan 1 - Mar 31, 91 days)
- `quarterly_backfill_q2_2024_taxi_only.sh` - 2024 Q2 (Apr 1 - Jun 30, 91 days)
- `quarterly_backfill_q3_2024_taxi_only.sh` - 2024 Q3 (Jul 1 - Sep 30, 92 days)
- `quarterly_backfill_q4_2024_taxi_only.sh` - 2024 Q4 (Oct 1 - Dec 31, 92 days)
- `quarterly_backfill_q1_2025_taxi_only.sh` - 2025 Q1 (Jan 1 - Mar 31, 90 days)
- `quarterly_backfill_q2_2025_taxi_only.sh` - 2025 Q2 (Apr 1 - Jun 30, 91 days)
- `quarterly_backfill_q3_2025_taxi_only.sh` - 2025 Q3 (Jul 1 - Oct 1, 93 days)

### Master Launcher
- `start_2024_2025_full_taxi_backfill.sh` - Launches all 7 quarters in parallel

## Key Features

✅ **TAXI ONLY** - No TNP extraction (not available for 2024+)
✅ **NEW DATASET** - Uses ajtu-isnz endpoint (auto-selected by v2.3.0)
✅ **2s delays** - Ultra-optimized for fastest safe execution
✅ **7-way parallel** - All quarters run simultaneously
✅ **Network resilient** - Survives network interruptions
✅ **Caffeinated** - System won't sleep during execution
✅ **Idempotent** - Safe to re-run, skips existing dates
✅ **BigQuery verified** - Confirms data after each extraction

## Performance Estimates

### With 2s delays (ULTRA-OPTIMIZED):
- **Per extraction:** ~1-2 minutes
- **Per quarter (sequential):** ~3-4 hours
- **Full period (7-way parallel):** ~3-4 hours total

### Comparison with 2023:
- 2023: 365 days in ~3 hours (4-way parallel)
- 2024-2025: 640 days in ~3-4 hours (7-way parallel)
- **Efficiency:** 1.75x more days in similar time!

## Code Changes (v2.3.0)

The extractor now automatically selects the correct API endpoint:
- **2020-2023 data:** Uses `wrvz-psew` dataset
- **2024+ data:** Uses `ajtu-isnz` dataset

This is handled dynamically based on the extraction date - no manual configuration needed!

## Quick Start

### Option 1: Run Full Period (Recommended)

```bash
cd ~/Desktop/chicago-bi-app/backfill
./start_2024_2025_full_taxi_backfill.sh
```

This will:
1. Run 8 pre-flight checks
2. Ask for confirmation
3. Launch all 7 quarters in parallel with caffeinate
4. Complete in ~3-4 hours

### Option 2: Run Individual Quarter

```bash
cd ~/Desktop/chicago-bi-app/backfill
caffeinate -s -i ./quarterly_backfill_q1_2024_taxi_only.sh
```

Replace `q1_2024` with the desired quarter.

## Pre-flight Checks

The master launcher performs 8 checks before starting:

1. ✅ Network connectivity (ping 8.8.8.8)
2. ✅ GCP authentication (active account)
3. ✅ Project ID (correct project set)
4. ✅ Cloud Run jobs (extractor-taxi exists with v2.3.0)
5. ✅ BigQuery tables (raw_taxi_trips exists)
6. ✅ Power status (AC or 80%+ battery)
7. ✅ Disk space (>5GB free)
8. ✅ Script files (all 7 quarterly scripts present)

## Expected Data Volume (2024-2025)

Based on 2024-01-01 test extraction (9,511 trips):

| Period | Days | Expected Trips | Estimated Time |
|--------|------|----------------|----------------|
| 2024 Q1 | 91 | ~870K | 3-4 hours |
| 2024 Q2 | 91 | ~870K | 3-4 hours |
| 2024 Q3 | 92 | ~880K | 3-4 hours |
| 2024 Q4 | 92 | ~880K | 3-4 hours |
| 2025 Q1 | 90 | ~860K | 3-4 hours |
| 2025 Q2 | 91 | ~870K | 3-4 hours |
| 2025 Q3 | 93 | ~890K | 3-4 hours |
| **Total** | **640 days** | **~6.1M trips** | **3-4 hours (parallel)** |

## Monitoring Progress

### Check running processes:
```bash
ps aux | grep quarterly_backfill
```

### View live logs:
```bash
# All logs
tail -f backfill_q*_202*_taxi_only_*.log

# Specific quarter
tail -f backfill_q1_2024_taxi_only_*.log
```

### Check progress files:
```bash
cat q1_2024_taxi_progress.txt
cat q2_2024_taxi_progress.txt
cat q3_2024_taxi_progress.txt
cat q4_2024_taxi_progress.txt
cat q1_2025_taxi_progress.txt
cat q2_2025_taxi_progress.txt
cat q3_2025_taxi_progress.txt
```

### View parallel execution info:
```bash
cat 2024_2025_parallel_taxi_backfill_info.txt
```

## Verification

### After completion, verify in BigQuery:

```bash
# Total trips and dates for 2024-2025
bq query --use_legacy_sql=false "
SELECT
  COUNT(*) as total_trips,
  COUNT(DISTINCT DATE(trip_start_timestamp)) as dates_loaded,
  MIN(DATE(trip_start_timestamp)) as first_date,
  MAX(DATE(trip_start_timestamp)) as last_date
FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips\`
WHERE DATE(trip_start_timestamp) BETWEEN '2024-01-01' AND '2025-10-01'
"

# Check for missing dates
bq query --use_legacy_sql=false "
WITH date_range AS (
  SELECT date
  FROM UNNEST(GENERATE_DATE_ARRAY('2024-01-01', '2025-10-01')) AS date
),
actual_dates AS (
  SELECT DISTINCT DATE(trip_start_timestamp) as actual_date
  FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips\`
  WHERE DATE(trip_start_timestamp) BETWEEN '2024-01-01' AND '2025-10-01'
)
SELECT d.date as missing_date
FROM date_range d
LEFT JOIN actual_dates a ON d.date = a.actual_date
WHERE a.actual_date IS NULL
ORDER BY d.date
"

# Year-by-year summary
bq query --use_legacy_sql=false "
SELECT
  EXTRACT(YEAR FROM trip_start_timestamp) as year,
  COUNT(*) as trips,
  COUNT(DISTINCT DATE(trip_start_timestamp)) as dates
FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips\`
WHERE EXTRACT(YEAR FROM trip_start_timestamp) IN (2024, 2025)
GROUP BY year
ORDER BY year
"
```

## API Rate Limit Usage

### Socrata API Limit: 5,000 requests/hour (with app token)

### 2024-2025 Usage @ 2s delays, 7 parallel:
- **Extractions per hour:** ~787 (all 7 combined)
- **API requests per extraction:** ~1-5 (taxi has less pagination than TNP)
- **Total API requests/hour:** ~787-3,935
- **Percentage of limit:** 16-79%
- **Status:** ✅ SAFE - Within limits, but higher than 2023

**Note:** 7-way parallel is more aggressive than 2023's 4-way. Monitor for rate limiting.

## Troubleshooting

### If a process fails:
1. Check the individual quarter log file
2. Identify the failed date
3. Verify BigQuery data for that date
4. Re-run just that quarter (idempotent - will skip completed dates)

### If network drops:
- The scripts will automatically wait for network recovery
- Progress is saved after each successful extraction
- Safe to re-run after network restores

### If system sleeps:
- Ensure caffeinate is running (should be automatic)
- Check power settings
- Connect to AC power for long runs

### If you see rate limiting:
- The extractor has built-in retry logic
- Failed extractions will be retried automatically
- If persistent, consider reducing parallelism (run fewer quarters at once)

## After 2024-2025 Completes

### Next Steps:
1. ✅ Verify all 640 dates in BigQuery
2. ✅ Check data quality metrics
3. ✅ Update session context documentation
4. ✅ Compare volume trends vs 2023
5. 🔜 Set up incremental daily updates for new 2025 data
6. 🔜 Plan data model updates for new schema fields

## Project Status After Completion

**Historical Data:**
- 2020-2022: Complete (1,096 days, 185M trips - Taxi + TNP)
- 2023: Complete (365 days, 6.5M trips - Taxi only)
- 2024-2025: Complete (640 days, ~6.1M trips - Taxi only)

**Total Coverage:**
- **2,101 days** of Chicago taxi data
- **~197.6M total trips** (27.6M Taxi + 170M TNP)
- **5 years, 9 months** of coverage (Jan 2020 - Oct 2025)

## Performance History

| Period | Delay | Parallel | Days | Time | Days/Hour |
|--------|-------|----------|------|------|-----------|
| Q2 2020 | 30s | Sequential | 91 | ~10h | 9 |
| Q3/Q4 2020 | 10s | 2-way | 184 | ~5h | 37 |
| 2021 | 5s | 4-way | 365 | ~8h | 46 |
| 2022 | 5s | 4-way | 365 | ~7.5h | 49 |
| 2023 | 2s | 4-way | 365 | ~3h | 122 |
| **2024-25** | **2s** | **7-way** | **640** | **~3-4h** | **~180** ⚡ |

**Total Optimization: 95% faster than initial implementation!**

## Files Generated

After running, you'll have:
- `backfill_q1_2024_taxi_only_TIMESTAMP.log` - 2024 Q1 execution log
- `backfill_q2_2024_taxi_only_TIMESTAMP.log` - 2024 Q2 execution log
- `backfill_q3_2024_taxi_only_TIMESTAMP.log` - 2024 Q3 execution log
- `backfill_q4_2024_taxi_only_TIMESTAMP.log` - 2024 Q4 execution log
- `backfill_q1_2025_taxi_only_TIMESTAMP.log` - 2025 Q1 execution log
- `backfill_q2_2025_taxi_only_TIMESTAMP.log` - 2025 Q2 execution log
- `backfill_q3_2025_taxi_only_TIMESTAMP.log` - 2025 Q3 execution log
- `q1_2024_taxi_progress.txt` - 2024 Q1 CSV progress (date, rows, timestamp)
- `q2_2024_taxi_progress.txt` - 2024 Q2 CSV progress
- `q3_2024_taxi_progress.txt` - 2024 Q3 CSV progress
- `q4_2024_taxi_progress.txt` - 2024 Q4 CSV progress
- `q1_2025_taxi_progress.txt` - 2025 Q1 CSV progress
- `q2_2025_taxi_progress.txt` - 2025 Q2 CSV progress
- `q3_2025_taxi_progress.txt` - 2025 Q3 CSV progress
- `2024_2025_full_taxi_backfill_TIMESTAMP.log` - Master log
- `2024_2025_parallel_taxi_backfill_info.txt` - Process IDs and completion times

---

**Ready to run!** Execute `./start_2024_2025_full_taxi_backfill.sh` when you're ready to start the 2024-2025 taxi backfill.

**Estimated completion:** 3-4 hours for full 640 days 🚀
