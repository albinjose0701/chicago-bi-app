# 2023 Taxi Backfill - Quick Start Guide

## Overview

**TAXI ONLY MODE** - TNP data is not available for 2023 onwards.

This backfill uses **ULTRA-OPTIMIZED 2s delays** (2.5x faster than 2022, 12x faster than initial 2020 implementation).

## What Was Created

### Quarterly Scripts (4 files)
- `quarterly_backfill_q1_2023_taxi_only.sh` - Q1 2023 (Jan 1 - Mar 31, 90 days)
- `quarterly_backfill_q2_2023_taxi_only.sh` - Q2 2023 (Apr 1 - Jun 30, 91 days)
- `quarterly_backfill_q3_2023_taxi_only.sh` - Q3 2023 (Jul 1 - Sep 30, 92 days)
- `quarterly_backfill_q4_2023_taxi_only.sh` - Q4 2023 (Oct 1 - Dec 31, 92 days)

### Master Launcher
- `start_2023_full_year_taxi_backfill.sh` - Launches all 4 quarters in parallel

## Key Features

✅ **TAXI ONLY** - No TNP extraction (not available for 2023+)
✅ **2s delays** - Ultra-optimized for fastest safe execution
✅ **4-way parallel** - All quarters run simultaneously
✅ **Network resilient** - Survives network interruptions
✅ **Caffeinated** - System won't sleep during execution
✅ **Idempotent** - Safe to re-run, skips existing dates
✅ **BigQuery verified** - Confirms data after each extraction

## Performance Estimates

### With 2s delays (ULTRA-OPTIMIZED):
- **Per extraction:** ~1-2 minutes
- **Per quarter (sequential):** ~3-4 hours
- **Full year (4-way parallel):** ~2-3 hours total

### Comparison with previous optimizations:
- 2020 Q2 (30s delays): ~8-10 hours per quarter
- 2020 Q3/Q4 (10s delays): ~5-7 hours per quarter
- 2022 (5s delays): ~3-5 hours per quarter
- **2023 (2s delays): ~2-3 hours per quarter** 🚀

## Quick Start

### Option 1: Run Full Year (Recommended)

```bash
cd ~/Desktop/chicago-bi-app/backfill
./start_2023_full_year_taxi_backfill.sh
```

This will:
1. Run 8 pre-flight checks
2. Ask for confirmation
3. Launch all 4 quarters in parallel with caffeinate
4. Complete in ~2-3 hours

### Option 2: Run Individual Quarter

```bash
cd ~/Desktop/chicago-bi-app/backfill
caffeinate -s -i ./quarterly_backfill_q1_2023_taxi_only.sh
```

Replace `q1` with `q2`, `q3`, or `q4` as needed.

## Pre-flight Checks

The master launcher performs 8 checks before starting:

1. ✅ Network connectivity (ping 8.8.8.8)
2. ✅ GCP authentication (active account)
3. ✅ Project ID (correct project set)
4. ✅ Cloud Run jobs (extractor-taxi exists)
5. ✅ BigQuery tables (raw_taxi_trips exists)
6. ✅ Power status (AC or 80%+ battery)
7. ✅ Disk space (>5GB free)
8. ✅ Script files (all 4 quarterly scripts present)

## Expected Data Volume (2023)

Based on post-pandemic recovery trends from 2022:

| Quarter | Expected Taxi Trips | Estimated Time |
|---------|---------------------|----------------|
| Q1 2023 | ~1.2M - 1.5M | 2-3 hours |
| Q2 2023 | ~1.8M - 2.2M | 3-4 hours |
| Q3 2023 | ~1.8M - 2.2M | 3-4 hours |
| Q4 2023 | ~1.7M - 2.0M | 3-4 hours |
| **Total** | **~6.5M - 7.9M trips** | **2-3 hours (parallel)** |

## Monitoring Progress

### Check running processes:
```bash
ps aux | grep quarterly_backfill_q
```

### View live logs:
```bash
# Q1
tail -f backfill_q1_2023_taxi_only_*.log

# Q2
tail -f backfill_q2_2023_taxi_only_*.log

# Q3
tail -f backfill_q3_2023_taxi_only_*.log

# Q4
tail -f backfill_q4_2023_taxi_only_*.log
```

### Check progress files:
```bash
cat q1_2023_taxi_progress.txt
cat q2_2023_taxi_progress.txt
cat q3_2023_taxi_progress.txt
cat q4_2023_taxi_progress.txt
```

### View parallel execution info:
```bash
cat 2023_parallel_taxi_backfill_info.txt
```

## Verification

### After completion, verify in BigQuery:

```bash
# Total trips and dates for 2023
bq query --use_legacy_sql=false "
SELECT
  COUNT(*) as total_trips,
  COUNT(DISTINCT DATE(trip_start_timestamp)) as dates_loaded,
  MIN(DATE(trip_start_timestamp)) as first_date,
  MAX(DATE(trip_start_timestamp)) as last_date
FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips\`
WHERE EXTRACT(YEAR FROM trip_start_timestamp) = 2023
"

# Check for missing dates
bq query --use_legacy_sql=false "
WITH date_range AS (
  SELECT date
  FROM UNNEST(GENERATE_DATE_ARRAY('2023-01-01', '2023-12-31')) AS date
),
actual_dates AS (
  SELECT DISTINCT DATE(trip_start_timestamp) as actual_date
  FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips\`
  WHERE EXTRACT(YEAR FROM trip_start_timestamp) = 2023
)
SELECT d.date as missing_date
FROM date_range d
LEFT JOIN actual_dates a ON d.date = a.actual_date
WHERE a.actual_date IS NULL
ORDER BY d.date
"
```

## API Rate Limit Usage

### Socrata API Limit: 5,000 requests/hour (with app token)

### 2023 Usage @ 2s delays, 4 parallel:
- **Extractions per hour:** ~450 (all 4 combined)
- **API requests per extraction:** ~1-5 (taxi has less pagination than TNP)
- **Total API requests/hour:** ~450-2,250
- **Percentage of limit:** 9-45%
- **Status:** ✅ SAFE - Well within limits

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

## After 2023 Completes

### Next Steps:
1. ✅ Verify all 365 dates in BigQuery
2. ✅ Check data quality metrics
3. ✅ Update session context documentation
4. 🔜 Explore 2024 schema changes together
5. 🔜 Adjust extractor code for 2024+ if needed
6. 🔜 Run 2024 and 2025 backfills

### 2024+ Schema Changes:
- **Note:** The taxi dataset schema changed in 2024
- **Action Required:** Need to explore the API and adjust Go extractor code
- **Recommendation:** Do this collaboratively before running 2024 backfill

## Performance History

| Period | Delay | Execution Method | Time per Year |
|--------|-------|------------------|---------------|
| Q2 2020 | 30s | Sequential | ~40 hours |
| Q3/Q4 2020 | 10s | 2-way parallel | ~10 hours |
| 2021 | 5s | 4-way parallel | ~8 hours |
| 2022 | 5s | 4-way parallel | ~7.5 hours |
| **2023** | **2s** | **4-way parallel** | **~2-3 hours** ⚡ |

**Total Optimization: 93% faster than initial implementation!**

## Files Generated

After running, you'll have:
- `backfill_q1_2023_taxi_only_TIMESTAMP.log` - Q1 execution log
- `backfill_q2_2023_taxi_only_TIMESTAMP.log` - Q2 execution log
- `backfill_q3_2023_taxi_only_TIMESTAMP.log` - Q3 execution log
- `backfill_q4_2023_taxi_only_TIMESTAMP.log` - Q4 execution log
- `q1_2023_taxi_progress.txt` - Q1 CSV progress (date, rows, timestamp)
- `q2_2023_taxi_progress.txt` - Q2 CSV progress
- `q3_2023_taxi_progress.txt` - Q3 CSV progress
- `q4_2023_taxi_progress.txt` - Q4 CSV progress
- `2023_full_year_taxi_backfill_TIMESTAMP.log` - Master log
- `2023_parallel_taxi_backfill_info.txt` - Process IDs and completion times

---

**Ready to run!** Execute `./start_2023_full_year_taxi_backfill.sh` when you're ready to start the 2023 taxi backfill.

**Estimated completion:** 2-3 hours for full year 🚀
