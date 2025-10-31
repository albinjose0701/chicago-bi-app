# QUICK START: Run Q1 2020 Backfill on Cloud Shell

Follow these steps to start your historical backfill RIGHT NOW.

---

## Step 1: Open Cloud Shell (1 minute)

1. Open your browser and go to: **https://console.cloud.google.com**
2. Log in with your Google account
3. Click the **terminal icon** (>_) in the top-right corner
4. Wait for Cloud Shell to initialize (~30 seconds)

You should see a terminal prompt like:
```
yourname@cloudshell:~ (chicago-bi-app-msds-432-476520)$
```

✅ **Cloud Shell is ready!**

---

## Step 2: Upload Backfill Script (2 minutes)

### Method A: Direct Upload (Easiest)

1. In Cloud Shell, click the **⋮** (three dots) menu in the top-right
2. Select **Upload**
3. Navigate to: `/Users/albin/Desktop/chicago-bi-app/backfill/`
4. Select `quarterly_backfill_q1_2020.sh`
5. Click **Upload**

Wait for upload to complete (file is small, ~2KB)

### Method B: Using Cloud Shell Editor

1. In Cloud Shell, click the **pencil icon** (Open Editor)
2. Create new file: `quarterly_backfill_q1_2020.sh`
3. Copy-paste contents from your local file
4. Save and close editor

---

## Step 3: Prepare the Script (1 minute)

In Cloud Shell terminal, run:

```bash
# Create directory structure
mkdir -p ~/chicago-bi-app/backfill

# Move uploaded script to correct location
mv quarterly_backfill_q1_2020.sh ~/chicago-bi-app/backfill/

# Navigate to directory
cd ~/chicago-bi-app/backfill

# Make script executable
chmod +x quarterly_backfill_q1_2020.sh

# Verify it's there
ls -lh quarterly_backfill_q1_2020.sh
```

You should see:
```
-rwxr-xr-x 1 yourname yourname 5.7K Oct 31 12:34 quarterly_backfill_q1_2020.sh
```

✅ **Script is ready!**

---

## Step 4: Set GCP Project (30 seconds)

```bash
# Set your project
gcloud config set project chicago-bi-app-msds-432-476520

# Verify it's set
gcloud config get-value project
```

Should output:
```
chicago-bi-app-msds-432-476520
```

---

## Step 5: Start Backfill with tmux (1 minute)

**Why tmux?** Prevents script from stopping if your browser closes or Cloud Shell times out.

```bash
# Start tmux session
tmux new -s backfill

# You'll see a green bar at the bottom - that means tmux is running

# Run the backfill script
./quarterly_backfill_q1_2020.sh all
```

You'll see:
```
================================================
Chicago BI App - Q1 2020 Quarterly Backfill
================================================

Quarter: Q1 2020 (Jan 1 - Mar 31)
Partitions: 90 daily partitions
Dataset: all
Project: chicago-bi-app-msds-432-476520

⚠️  WARNING: This will execute Cloud Run jobs for 90 days of data.
   Estimated cost: ~$1.50 (one-time)
   Estimated time: ~30s × 90 = 45 minutes per dataset

Continue with quarterly backfill? (yes/no):
```

**Type `yes` and press Enter**

---

## Step 6: Detach from tmux (optional)

The script is now running! You have two options:

### Option A: Stay and Watch (Recommended for first time)

- Leave the terminal open
- Watch the progress in real-time
- You'll see each date being processed:
  ```
  ℹ️  Progress: 1/90 (taxi)
  ℹ️  Running taxi extraction for 2020-01-01...
  ✅ Completed taxi for 2020-01-01
  ℹ️  Waiting 30 seconds before next extraction...
  ```

### Option B: Detach and Close Browser

- Press **Ctrl+B**, then press **D** (two separate key presses)
- You'll see: `[detached (from session backfill)]`
- The script keeps running even if you close your browser!

To check back later:
```bash
# Reopen Cloud Shell
# Reattach to tmux session
tmux attach -t backfill
```

---

## Step 7: Monitor Progress

### While Running

The script shows:
- Current date being processed
- Progress counter (X/90)
- Success/failure status
- Time until next extraction

Example output:
```
================================================
Starting Backfill Process
================================================

ℹ️  Processing dataset: taxi

ℹ️  Progress: 1/90 (taxi)
ℹ️  Running taxi extraction for 2020-01-01...
✅ Completed taxi for 2020-01-01
ℹ️  Waiting 30 seconds before next extraction...

ℹ️  Progress: 2/90 (taxi)
ℹ️  Running taxi extraction for 2020-01-02...
✅ Completed taxi for 2020-01-02
...
```

### Check Cloud Run Executions (Optional)

Open another browser tab:
1. Go to: https://console.cloud.google.com/run/jobs
2. Click `extractor-taxi`
3. View **Executions** tab
4. See real-time job executions

---

## Step 8: Check Logs (During or After)

### In Cloud Shell

```bash
# View the log file (created automatically)
cat backfill_q1_2020_all_*.log

# Check for failures
grep FAILED backfill_q1_2020_all_*.log

# Count successes
grep SUCCESS backfill_q1_2020_all_*.log | wc -l
```

### Expected Timeline

| Time | Progress | Status |
|------|----------|--------|
| 0:00 | Starting | Pre-flight checks |
| 0:01 | 1/90 | First date (2020-01-01) |
| 0:30 | 2/90 | Second date (2020-01-02) |
| 22:30 | 45/90 | Halfway through |
| 45:00 | 90/90 | Complete! |

**Total time: ~45 minutes**

---

## Step 9: Verify Data (After Completion)

When you see:
```
================================================
Backfill Summary
================================================

Total Executions: 90
Successful: 90
Failed: 0
Log File: backfill_q1_2020_all_20251031_143022.log

✅ Quarterly backfill completed successfully!
```

Run verification:

```bash
# Check partition count (should be 90)
bq query --use_legacy_sql=false \
  "SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as partition_count
   FROM \`chicago-bi.raw_data.raw_taxi_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
```

Expected output:
```
+------------------+
| partition_count  |
+------------------+
|               90 |
+------------------+
```

```bash
# Check total rows
bq query --use_legacy_sql=false \
  "SELECT COUNT(*) as total_trips
   FROM \`chicago-bi.raw_data.raw_taxi_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
```

```bash
# Check sample data
bq query --use_legacy_sql=false \
  "SELECT DATE(trip_start_timestamp) as date, COUNT(*) as trips
   FROM \`chicago-bi.raw_data.raw_taxi_trips\`
   WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'
   GROUP BY date
   ORDER BY date
   LIMIT 10"
```

✅ **Data verification complete!**

---

## Troubleshooting

### Script Says "Cloud Run job not found"

**Fix:**
```bash
# Check if extractor jobs exist
gcloud run jobs list --region=us-central1

# If empty, you need to deploy extractors first
# See: docs/SETUP.md
```

### Script Says "Permission denied"

**Fix:**
```bash
# Make sure script is executable
chmod +x quarterly_backfill_q1_2020.sh
```

### Cloud Shell Times Out

**Fix:**
```bash
# If you used tmux, reattach
tmux attach -t backfill

# If you didn't use tmux, restart the script
./quarterly_backfill_q1_2020.sh all
```

### Want to Stop the Script

**Fix:**
```bash
# If in tmux, press Ctrl+C to stop
# Then exit tmux: type 'exit' and press Enter

# Or kill tmux session
tmux kill-session -t backfill
```

---

## After Backfill is Complete

### 1. Exit tmux

```bash
# Type 'exit' and press Enter
exit
```

### 2. Download the Log File (Optional)

```bash
# Download to your local machine
# In Cloud Shell menu: Download file
# Enter path: ~/chicago-bi-app/backfill/backfill_q1_2020_all_*.log
```

### 3. Next Steps

You're ready to proceed with:
- ✅ **Process to gold layer** (create analytics tables)
- ✅ **Run your analysis** (query Q1 2020 data)
- ✅ **Archive to Coldline** (save storage costs)
- ✅ **Enable daily incremental** (ongoing data)

See: `/docs/DATA_INGESTION_WORKFLOW.md`

---

## Quick Commands Reference

| Task | Command |
|------|---------|
| **Start tmux** | `tmux new -s backfill` |
| **Detach from tmux** | `Ctrl+B` then `D` |
| **Reattach to tmux** | `tmux attach -t backfill` |
| **View log** | `cat backfill_q1_2020_all_*.log` |
| **Check failures** | `grep FAILED backfill_q1_2020_all_*.log` |
| **Kill tmux** | `tmux kill-session -t backfill` |
| **Check BQ data** | `bq query --use_legacy_sql=false "SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) FROM \`chicago-bi.raw_data.raw_taxi_trips\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"` |

---

## Summary Checklist

- [ ] Step 1: Open Cloud Shell
- [ ] Step 2: Upload `quarterly_backfill_q1_2020.sh`
- [ ] Step 3: Make script executable
- [ ] Step 4: Set GCP project
- [ ] Step 5: Start tmux and run script
- [ ] Step 6: Type `yes` to confirm
- [ ] Step 7: Monitor progress (or detach)
- [ ] Step 8: Wait ~45 minutes
- [ ] Step 9: Verify 90 partitions in BigQuery

---

**You're all set! Open Cloud Shell and let's get started!** 🚀

**Estimated total time:** 50 minutes (5 min setup + 45 min running)
**Estimated cost:** $1.08 one-time
**Result:** 90 daily partitions of Q1 2020 taxi trip data in BigQuery
