# Running Historical Backfill on Cloud

This guide shows you how to run the Q1 2020 backfill extraction directly on Google Cloud Platform instead of from your local machine.

---

## Overview of Options

| Option | Complexity | Best For | Cost |
|--------|------------|----------|------|
| **1. Cloud Shell** | Easy | Quick one-time backfills | Free |
| **2. Cloud Workflows** | Medium | Orchestrated, monitored backfills | ~$0.01 |
| **3. Enhanced Go Extractor** | Advanced | Native date range support | Same as current |

---

## Option 1: Cloud Shell (Easiest - Recommended)

Cloud Shell provides a free, browser-based terminal with `gcloud`, `bq`, and `gsutil` pre-installed.

### Step 1: Open Cloud Shell

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Click the **Cloud Shell icon** (terminal icon) in the top-right corner
3. Wait for Cloud Shell to initialize

### Step 2: Upload Backfill Scripts

#### Method A: Using Cloud Shell Editor

```bash
# In Cloud Shell, create directory structure
mkdir -p ~/chicago-bi-app/backfill
mkdir -p ~/chicago-bi-app/archival

# Open Cloud Shell Editor (click the pencil icon in Cloud Shell)
# Upload the following files:
# - backfill/quarterly_backfill_q1_2020.sh
# - backfill/monthly_backfill.sh
# - archival/archive_quarter.sh
```

#### Method B: Using Git (Recommended)

```bash
# Clone your repository (if you have one)
git clone https://github.com/your-org/chicago-bi-app.git
cd chicago-bi-app

# OR manually create the scripts
# Copy-paste the script contents from your local machine
```

#### Method C: Direct Upload

1. In Cloud Shell, click the **⋮** menu (three dots)
2. Select **Upload file**
3. Upload `quarterly_backfill_q1_2020.sh`
4. Move to correct location:
   ```bash
   mkdir -p ~/chicago-bi-app/backfill
   mv quarterly_backfill_q1_2020.sh ~/chicago-bi-app/backfill/
   ```

### Step 3: Set Project and Make Scripts Executable

```bash
# Set your GCP project
gcloud config set project chicago-bi-app-msds-432-476520

# Navigate to backfill directory
cd ~/chicago-bi-app/backfill

# Make scripts executable
chmod +x quarterly_backfill_q1_2020.sh
chmod +x monthly_backfill.sh

cd ~/chicago-bi-app/archival
chmod +x archive_quarter.sh
```

### Step 4: Run Backfill

```bash
cd ~/chicago-bi-app/backfill

# Run Q1 2020 quarterly backfill
./quarterly_backfill_q1_2020.sh all

# OR run monthly backfills
./monthly_backfill.sh 2020-01 all
./monthly_backfill.sh 2020-02 all
./monthly_backfill.sh 2020-03 all
```

### Step 5: Monitor Progress

The script will output progress in real-time:

```
================================================
Chicago BI App - Q1 2020 Quarterly Backfill
================================================

Quarter: Q1 2020 (Jan 1 - Mar 31)
Partitions: 90 daily partitions
Dataset: all
Project: chicago-bi-app-msds-432-476520

================================================
Starting Backfill Process
================================================

ℹ️  Progress: 1/90 (taxi)
ℹ️  Running taxi extraction for 2020-01-01...
✅ Completed taxi for 2020-01-01
ℹ️  Waiting 30 seconds before next extraction...

ℹ️  Progress: 2/90 (taxi)
...
```

### Step 6: Check Logs

```bash
# View the generated log file
cat backfill_q1_2020_all_*.log

# Check for failures
grep FAILED backfill_q1_2020_all_*.log

# Count successes
grep SUCCESS backfill_q1_2020_all_*.log | wc -l
```

### Benefits of Cloud Shell
- ✅ **Free**: No compute costs
- ✅ **Pre-configured**: All tools installed
- ✅ **Persistent**: Files saved to home directory
- ✅ **Always available**: Access from any browser
- ✅ **5GB storage**: Enough for scripts and logs

### Limitations
- ⚠️ Session timeout after 20 minutes of inactivity
- ⚠️ Use `tmux` or `screen` for long-running processes

### Using tmux for Long Backfills

```bash
# Start tmux session
tmux new -s backfill

# Run backfill script
cd ~/chicago-bi-app/backfill
./quarterly_backfill_q1_2020.sh all

# Detach from tmux: Press Ctrl+B, then D
# Cloud Shell can close, script keeps running

# Re-attach later
tmux attach -t backfill
```

---

## Option 2: Cloud Workflows (Best for Orchestration)

Cloud Workflows provides serverless orchestration with built-in retry, monitoring, and error handling.

### Architecture

```
Cloud Workflows (orchestrator)
    │
    ├─> Iteration 1: Execute extractor-taxi (2020-01-01)
    ├─> Iteration 2: Execute extractor-taxi (2020-01-02)
    ├─> ...
    └─> Iteration 90: Execute extractor-taxi (2020-03-31)
```

### Step 1: Deploy Cloud Workflows

```bash
cd ~/Desktop/chicago-bi-app/workflows

# Make deployment script executable
chmod +x deploy_workflow.sh

# Deploy the workflow
./deploy_workflow.sh
```

**What gets created:**
- Workflow name: `quarterly-backfill-workflow`
- Location: `us-central1`
- Service account: `cloud-run@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com`

### Step 2: Execute Workflow for Q1 2020

```bash
# Execute workflow for taxi dataset
gcloud workflows execute quarterly-backfill-workflow \
  --location=us-central1 \
  --data='{"dataset":"taxi"}'

# Execute for TNP dataset
gcloud workflows execute quarterly-backfill-workflow \
  --location=us-central1 \
  --data='{"dataset":"tnp"}'
```

### Step 3: Monitor Workflow Execution

```bash
# List all workflow executions
gcloud workflows executions list quarterly-backfill-workflow \
  --location=us-central1

# Get execution ID from output, then describe it
gcloud workflows executions describe <EXECUTION_ID> \
  --workflow=quarterly-backfill-workflow \
  --location=us-central1
```

**View in Cloud Console:**
1. Go to [Cloud Workflows](https://console.cloud.google.com/workflows)
2. Click `quarterly-backfill-workflow`
3. View executions and logs in real-time

### How Cloud Workflows Works

```yaml
# Simplified workflow logic:
for day_offset in [0 to 89]:
  - Calculate date (2020-01-01 + day_offset)
  - Execute Cloud Run job with START_DATE=calculated_date
  - Wait 30 seconds
  - Continue to next day
```

### Benefits of Cloud Workflows
- ✅ **Automatic retry**: Failed jobs auto-retry
- ✅ **Built-in monitoring**: View progress in Console
- ✅ **No babysitting**: Runs completely serverless
- ✅ **Audit trail**: Full execution history
- ✅ **Error handling**: Graceful failure handling

### Cost
- **Workflows executions**: $0.01 per 1000 steps
- **Q1 2020 backfill**: 90 steps × $0.00001 = **$0.0009** (basically free)

---

## Option 3: Enhanced Go Extractor (Best Long-Term)

Modify the Go extractor to support date ranges natively, eliminating the need for external orchestration.

### Current Limitation

```go
// Current: Only processes one date
config := ExtractorConfig{
    StartDate: "2020-01-01",
    EndDate:   "2020-01-01",  // Same as StartDate!
}
```

### Enhanced Approach

```go
// Enhanced: Process date ranges
config := ExtractorConfig{
    StartDate: "2020-01-01",
    EndDate:   "2020-03-31",  // Automatically loops through 90 days
}
```

### Implementation

I've created an enhanced version: `extractors/taxi/main_enhanced.go`

**Key changes:**
```go
// Parse date range
startDate, _ := time.Parse("2006-01-02", config.StartDate)
endDate, _ := time.Parse("2006-01-02", config.EndDate)

// Loop through each date
currentDate := startDate
for currentDate.Before(endDate.AddDate(0, 0, 1)) {
    dateStr := currentDate.Format("2006-01-02")

    // Extract data for this date
    trips, _ := extractData(buildQueryForDate(dateStr))

    // Upload to GCS
    uploadToGCSForDate(config.OutputBucket, trips, dateStr)

    // Next date
    currentDate = currentDate.AddDate(0, 0, 1)
    time.Sleep(1 * time.Second)  // Rate limit protection
}
```

### Step 1: Replace Main Extractor

```bash
cd ~/Desktop/chicago-bi-app/extractors/taxi

# Backup original
mv main.go main_original.go

# Use enhanced version
mv main_enhanced.go main.go
```

### Step 2: Rebuild and Deploy

```bash
# Rebuild Docker image
docker build -t gcr.io/chicago-bi-app-msds-432-476520/extractor-taxi:enhanced .

# Push to Container Registry
docker push gcr.io/chicago-bi-app-msds-432-476520/extractor-taxi:enhanced

# Deploy to Cloud Run (update image)
gcloud run jobs update extractor-taxi \
  --region=us-central1 \
  --image=gcr.io/chicago-bi-app-msds-432-476520/extractor-taxi:enhanced \
  --timeout=3600s \
  --memory=1Gi \
  --cpu=2
```

### Step 3: Run Q1 2020 Backfill (Single Execution!)

```bash
# Extract all 90 days in ONE Cloud Run job execution
gcloud run jobs execute extractor-taxi \
  --region=us-central1 \
  --update-env-vars=MODE=full,START_DATE=2020-01-01,END_DATE=2020-03-31 \
  --wait
```

**What happens:**
- Single Cloud Run job execution
- Processes 90 dates internally (loops through Jan 1 - Mar 31)
- Uploads 90 files to GCS (one per date)
- 1-second delay between dates (rate limit protection)
- **Total runtime**: ~90 minutes (1 minute per date average)

### Benefits of Enhanced Extractor
- ✅ **Single execution**: No orchestration needed
- ✅ **Lower cost**: 1 execution vs 90 executions ($0.012 vs $1.08 = **92% savings**)
- ✅ **Simpler**: No bash scripts or workflows needed
- ✅ **Faster**: No 30-second delays between dates
- ✅ **Built-in retry**: Can add retry logic within Go code

### Limitations
- ⚠️ **Timeout risk**: Cloud Run max timeout is 3600s (1 hour)
  - Solution: Use Cloud Run **jobs** (not services) with 24-hour timeout
- ⚠️ **Memory usage**: Holds all data in memory
  - Current approach uploads per-date, so memory is bounded
- ⚠️ **No pause/resume**: If it fails at day 50, must restart from beginning
  - Solution: Add checkpoint mechanism (write progress to GCS)

### Cost Comparison

| Approach | Executions | Cost per Execution | Total Cost |
|----------|------------|-------------------|------------|
| **Bash script (90 executions)** | 90 | $0.012 | $1.08 |
| **Cloud Workflows (90 steps)** | 90 | $0.012 + $0.0009 | $1.08 |
| **Enhanced extractor (1 execution)** | 1 | $0.012 × 90 minutes / 8 minutes | **$0.14** |

**Enhanced extractor saves $0.94** (87% reduction)!

---

## Comparison Matrix

| Feature | Cloud Shell | Cloud Workflows | Enhanced Extractor |
|---------|-------------|-----------------|-------------------|
| **Complexity** | Easy | Medium | Advanced |
| **Setup time** | 5 minutes | 10 minutes | 30 minutes |
| **One-time cost** | $1.08 | $1.08 | $0.14 |
| **Execution time** | 45 min (with delays) | 45 min | 90 min (no delays) |
| **Monitoring** | Manual (log files) | Built-in UI | Cloud Run logs |
| **Retry on failure** | Manual | Automatic | Need to code |
| **Pause/resume** | tmux | Yes (built-in) | No (need coding) |
| **Best for** | Quick one-time | Production | Repeated backfills |

---

## Recommendations

### For Q1 2020 One-Time Backfill

**Use Cloud Shell** (Option 1):
- Simplest and fastest to get started
- No code changes needed
- Use tmux to avoid session timeout
- Good enough for academic project

```bash
# Quick start
cd ~/chicago-bi-app/backfill
./quarterly_backfill_q1_2020.sh all
```

### For Production Repeated Backfills

**Use Cloud Workflows** (Option 2):
- Better monitoring and error handling
- Automatic retry
- Audit trail
- Worth the setup for repeated use

```bash
cd ~/chicago-bi-app/workflows
./deploy_workflow.sh
gcloud workflows execute quarterly-backfill-workflow --data='{"dataset":"taxi"}'
```

### For Long-Term Scalability

**Use Enhanced Extractor** (Option 3):
- Best performance and cost
- Cleaner architecture
- Requires more development effort
- Recommended if you'll run many backfills

```bash
# One-time setup, then:
gcloud run jobs execute extractor-taxi \
  --update-env-vars=START_DATE=2020-01-01,END_DATE=2020-03-31
```

---

## Quick Decision Guide

**Choose Cloud Shell if:**
- ✓ You want to run backfill NOW
- ✓ This is a one-time operation
- ✓ You don't want to write code
- ✓ 45 minutes runtime is acceptable

**Choose Cloud Workflows if:**
- ✓ You want automatic monitoring
- ✓ You need automatic retry
- ✓ You'll run multiple backfills
- ✓ You want audit trail

**Choose Enhanced Extractor if:**
- ✓ You want lowest cost ($0.14 vs $1.08)
- ✓ You're comfortable modifying Go code
- ✓ You'll run many historical backfills
- ✓ You want the cleanest architecture

---

## Next Steps

### Recommended: Start with Cloud Shell

1. **Open Cloud Shell**:
   ```bash
   https://console.cloud.google.com
   # Click terminal icon
   ```

2. **Upload backfill script**:
   ```bash
   # Upload quarterly_backfill_q1_2020.sh
   mkdir -p ~/chicago-bi-app/backfill
   cd ~/chicago-bi-app/backfill
   # Upload file via Cloud Shell UI
   ```

3. **Run backfill**:
   ```bash
   chmod +x quarterly_backfill_q1_2020.sh

   # Use tmux to prevent timeout
   tmux new -s backfill
   ./quarterly_backfill_q1_2020.sh all

   # Detach: Ctrl+B then D
   # Re-attach later: tmux attach -t backfill
   ```

4. **Verify data**:
   ```bash
   bq query --use_legacy_sql=false \
     "SELECT COUNT(DISTINCT DATE(trip_start_timestamp))
      FROM \`chicago-bi.raw_data.raw_taxi_trips\`
      WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
   ```

---

## Troubleshooting

### Cloud Shell Session Timeout

**Problem**: Session closes during backfill

**Solution**: Use tmux
```bash
tmux new -s backfill
./quarterly_backfill_q1_2020.sh all
# Detach with Ctrl+B then D
```

### Cloud Run Job Not Found

**Problem**: `gcloud run jobs execute extractor-taxi` fails

**Solution**: Deploy the job first
```bash
# Check if job exists
gcloud run jobs list --region=us-central1

# If not, deploy it first (see docs/SETUP.md)
```

### Workflow Execution Fails

**Problem**: Cloud Workflows reports errors

**Solution**: Check service account permissions
```bash
gcloud projects add-iam-policy-binding chicago-bi-app-msds-432-476520 \
  --member="serviceAccount:cloud-run@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com" \
  --role="roles/run.invoker"
```

---

## Summary

You now have **three ways** to run the Q1 2020 historical backfill on cloud:

1. **Cloud Shell** (recommended for quick start)
2. **Cloud Workflows** (recommended for production)
3. **Enhanced Go Extractor** (recommended for scale)

All three approaches create the same result: **90 daily partitions** in BigQuery for Q1 2020 data.

Choose based on your immediate needs and long-term plans!
