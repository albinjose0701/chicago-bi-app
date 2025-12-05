# TNP Backfill - Unattended Mode Guide

## Quick Start

```bash
# From project root
cd backfill
./start_backfill_unattended.sh
```

This will:
- ✅ Run all pre-flight checks
- ✅ Keep your system awake (caffeinate)
- ✅ Handle network interruptions automatically
- ✅ Resume from where you left off (2020-01-10)
- ✅ Process 81 remaining dates (~6-7 hours)

---

## What Happens During the Run

### System Stay-Awake
- Uses `caffeinate` to prevent sleep
- System stays awake even if you:
  - Close the laptop lid (NOT RECOMMENDED - may affect WiFi)
  - Leave it idle for hours
  - Step away

### Network Resilience
The script automatically handles:
- Power backup switches causing network drops
- Brief WiFi interruptions
- ISP outages (will wait and retry)

**Recovery strategy:**
1. Detects network failure
2. Pings 8.8.8.8 every 10 seconds to check connectivity
3. Once network is back, waits 5 seconds for stabilization
4. Retries the failed operation
5. Continues from where it left off

### Progress Tracking
Two files are created:
1. **Log file**: `resume_tnp_resilient_YYYYMMDD_HHMMSS.log`
   - Complete timestamped log of all activity
   - Shows which dates completed/failed
   - Records row counts

2. **Progress file**: `tnp_progress.txt`
   - Simple CSV: date, row_count, timestamp
   - One line per successful date
   - Easy to parse programmatically

---

## Monitoring from Another Terminal

### Watch live progress:
```bash
# From project root
cd backfill
tail -f resume_tnp_resilient_*.log
```

### Check how many dates are done:
```bash
bq query --use_legacy_sql=false \
  "SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as completed_dates
   FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_tnp_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
```

### See last completed date:
```bash
bq query --use_legacy_sql=false \
  "SELECT MAX(DATE(trip_start_timestamp)) as last_date
   FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_tnp_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
```

### Check progress file:
```bash
tail backfill/docs/tnp_progress.txt
```

---

## Estimated Timeline

| Dates | Time (approx) |
|-------|---------------|
| 10 dates | ~50 minutes |
| 20 dates | ~1.7 hours |
| 40 dates | ~3.3 hours |
| 81 dates (all) | ~6.75 hours |

**Note:** Times assume ~5 minutes per date on average. TNP dates vary from 200k-300k trips/day.

---

## If Something Goes Wrong

### System Shutdown / Crash
**No problem!** Just re-run the same command:
```bash
./start_backfill_unattended.sh
```

The script will:
- Check which dates already exist in BigQuery
- Skip completed dates (saves time)
- Resume processing missing dates only

### Network Down for Extended Period
The script will:
- Keep checking network every 10 seconds
- Wait indefinitely for network to return
- Resume automatically when network is back
- You'll see: "Network check attempt X... (will keep trying)"

### Manual Cancellation (Ctrl+C)
Safe to cancel anytime. To resume:
```bash
./start_backfill_unattended.sh
```

It will pick up where it left off.

### Script Reports Failures
At the end, if some dates failed, the summary shows:
```
Failed Dates:
  - 2020-02-14
  - 2020-03-05
```

**To retry just failed dates:**
```bash
# Option 1: Re-run the script (will skip successful dates)
./start_backfill_unattended.sh

# Option 2: Manual retry
gcloud run jobs execute extractor-tnp \
  --update-env-vars="START_DATE=2020-02-14" \
  --region=us-central1 --wait
```

---

## After Completion

### Verify Full Dataset
```bash
bq query --use_legacy_sql=false "
SELECT
  COUNT(DISTINCT DATE(trip_start_timestamp)) as total_dates,
  MIN(DATE(trip_start_timestamp)) as first_date,
  MAX(DATE(trip_start_timestamp)) as last_date,
  COUNT(*) as total_trips,
  SUM(CASE WHEN pickup_community_area IS NOT NULL THEN 1 ELSE 0 END) as with_geo
FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_tnp_trips\`
WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'
"
```

**Expected results:**
- `total_dates`: **90**
- `first_date`: **2020-01-01**
- `last_date`: **2020-03-31**
- `total_trips`: **~20-25 million**
- `with_geo`: **>90%** of total_trips

### Check for Missing Dates
```bash
# Generate list of expected dates vs actual dates
bq query --use_legacy_sql=false "
WITH expected AS (
  SELECT date
  FROM UNNEST(GENERATE_DATE_ARRAY('2020-01-01', '2020-03-31')) AS date
),
actual AS (
  SELECT DISTINCT DATE(trip_start_timestamp) as date
  FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_tnp_trips\`
  WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'
)
SELECT expected.date as missing_date
FROM expected
LEFT JOIN actual ON expected.date = actual.date
WHERE actual.date IS NULL
ORDER BY expected.date
"
```

If any dates are missing, re-run the script or manually extract them.

---

## Performance Tips

### If System is Running Slow
The backfill is CPU and network intensive. If your Mac is sluggish:
- Close unnecessary applications
- Disable Time Machine during the run
- Ensure good WiFi signal
- Consider running overnight

### If You Need to Use Your Computer
**Option 1**: Let it run in background
- The process is mostly waiting for Cloud Run
- CPU usage is low except during BigQuery queries
- You can work normally

**Option 2**: Use `screen` or `tmux` (advanced)
```bash
# Start in screen session
screen -S backfill
./start_backfill_unattended.sh

# Detach: Ctrl+A, then D
# Reattach later: screen -r backfill
```

---

## Files Created

| File | Purpose | Keep? |
|------|---------|-------|
| `resume_tnp_resilient_*.log` | Complete activity log | Yes (for audit) |
| `tnp_progress.txt` | Date/row summary | Yes (for verification) |
| `extraction_output.tmp` | Temporary Cloud Run output | No (auto-overwritten) |

---

## Troubleshooting

### "Cloud Run execution failed after 10 network retries"
- Check if your API keys are still valid
- Verify Cloud Run job exists: `gcloud run jobs describe extractor-tnp --region=us-central1`
- Check Cloud Run logs for specific errors

### "Verification failed after 5 attempts"
- Data extracted but BigQuery load might be delayed
- Wait 1 minute and check manually:
  ```bash
  bq query "SELECT COUNT(*) FROM raw_tnp_trips WHERE DATE(trip_start_timestamp)='YYYY-MM-DD'"
  ```

### "bq command not found"
- Google Cloud SDK not in PATH
- Fix:
  ```bash
  export PATH="$PATH:$HOME/google-cloud-sdk/bin"
  ```

### Script stuck on "Waiting for network to stabilize..."
- Your internet is actually down
- Check: `ping 8.8.8.8`
- Script will auto-resume when network returns
- Or cancel (Ctrl+C) and investigate network issue

---

## Cost Estimate

**Q1 2020 TNP Backfill (81 remaining dates):**
- Cloud Run execution: ~$2-3
- BigQuery loading: Free (within quota)
- BigQuery storage: ~$0.50/month for ~15M rows
- **Total one-time cost: ~$2-3**

Current GCP credits: ₹26,000 (~$310 USD) - plenty remaining!

---

## Contact / Issues

If you encounter issues not covered here:
1. Check the log file for detailed errors
2. Search Cloud Run logs:
   ```bash
   gcloud logging read 'resource.type="cloud_run_job" AND resource.labels.job_name="extractor-tnp"' --limit 50
   ```
3. Verify your GCP quotas haven't been exceeded

---

## Summary Checklist

Before leaving your computer:

- [ ] System connected to power (AC adapter)
- [ ] Network connection stable
- [ ] No scheduled system updates/restarts
- [ ] `./start_backfill_unattended.sh` running
- [ ] Initial few dates completing successfully
- [ ] Log file being created and updated

You're all set! The script will handle everything from here. ✅
