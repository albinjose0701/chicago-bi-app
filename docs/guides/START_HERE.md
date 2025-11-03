# START HERE: Complete Q1 2020 Backfill Setup

---
**Document:** START_HERE - Q1 2020 Backfill Setup
**Version:** 2.0.0
**Document Type:** Quick Start Guide
**Date:** 2025-10-31
**Status:** Final
**Authors:** Group 2 - MSDS 432
**Related Docs:** DEPLOYMENT_GUIDE.md v2.0.0, README.md v2.0
---

**Total Time:** ~90-120 minutes (30 min setup + 60-90 min backfill)
**Cost:** ~$3-4 one-time
**Result:** 180 daily partitions of Q1 2020 data (90 taxi + 90 TNP) in BigQuery

**New in v2.0:** Support for both Taxi (wrvz-psew) and TNP (m6dm-c72p) datasets

---

## 📋 Complete Checklist

### Phase 1: Deploy Authenticated Extractor (15 minutes)

- [ ] **Step 1:** Navigate to extractor directory
  ```bash
  cd ~/Desktop/chicago-bi-app/extractors/taxi
  ```

- [ ] **Step 2:** Run deployment script
  ```bash
  ./deploy_with_auth.sh
  ```

- [ ] **Step 3:** Verify deployment successful
  - Look for: `✅ Authenticated extractor deployed successfully!`

**Documentation:** See `DEPLOY_AUTHENTICATED_EXTRACTOR.md` for details

---

### Phase 2: Run Q1 2020 Backfill (45 minutes)

**Option A: Run on Cloud Shell (Recommended)**

- [ ] **Step 1:** Open Cloud Shell at https://console.cloud.google.com
- [ ] **Step 2:** Upload backfill script
  - Upload: `backfill/quarterly_backfill_q1_2020.sh`
  - Or: Use the deployment instructions below
- [ ] **Step 3:** Run backfill
  ```bash
  cd ~/chicago-bi-app/backfill
  chmod +x quarterly_backfill_q1_2020.sh

  # Use tmux to prevent timeout
  tmux new -s backfill
  ./quarterly_backfill_q1_2020.sh all

  # Detach: Ctrl+B then D
  ```

**Documentation:** See `QUICKSTART_CLOUD_BACKFILL.md` for details

**Option B: Run Locally**

- [ ] **Step 1:** Navigate to backfill directory
  ```bash
  cd ~/Desktop/chicago-bi-app/backfill
  ```

- [ ] **Step 2:** Run backfill script
  ```bash
  ./quarterly_backfill_q1_2020.sh all
  ```

---

### Phase 3: Verify Data (5 minutes)

- [ ] **Check partition count:**
  ```bash
  bq query --use_legacy_sql=false \
    "SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) as partitions
     FROM \`chicago-bi.raw_data.raw_taxi_trips\`
     WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
  ```

  Expected: `90`

- [ ] **Check row count:**
  ```bash
  bq query --use_legacy_sql=false \
    "SELECT COUNT(*) as total_trips
     FROM \`chicago-bi.raw_data.raw_taxi_trips\`
     WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
  ```

- [ ] **View sample data:**
  ```bash
  bq query --use_legacy_sql=false \
    "SELECT DATE(trip_start_timestamp) as date, COUNT(*) as trips
     FROM \`chicago-bi.raw_data.raw_taxi_trips\`
     WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-01-10'
     GROUP BY date
     ORDER BY date"
  ```

---

## 🗂️ Key Files Reference

| File | Purpose |
|------|---------|
| **THIS FILE** | Master checklist (you are here) |
| `DEPLOY_AUTHENTICATED_EXTRACTOR.md` | Deploy extractor with auth |
| `QUICKSTART_CLOUD_BACKFILL.md` | Run backfill on Cloud Shell |
| `docs/DATA_INGESTION_WORKFLOW.md` | Complete workflow guide |
| `docs/AUTHENTICATION_AND_DATASETS.md` | Auth setup explained |
| `docs/RUN_BACKFILL_ON_CLOUD.md` | All 3 cloud options |

---

## 🎯 Quick Decision Matrix

### Where to Deploy Extractor?

**Local Machine (Current):**
- ✅ Fastest for development
- ✅ No additional setup
- ⚠️ Requires Docker installed

**Cloud Shell:**
- ✅ No Docker needed
- ✅ All tools pre-installed
- ⚠️ Slightly slower uploads

**Recommendation:** Deploy locally if Docker is installed, otherwise use Cloud Shell

---

### Where to Run Backfill?

**Cloud Shell (Recommended):**
- ✅ Free compute
- ✅ Can close browser (tmux)
- ✅ Faster network to GCP
- ⚠️ Need to upload script

**Local Machine:**
- ✅ No upload needed
- ✅ Familiar environment
- ⚠️ Can't close terminal
- ⚠️ Uses your internet

**Recommendation:** Use Cloud Shell with tmux

---

## 🚀 The Fastest Path (TL;DR)

If you just want to get started ASAP:

```bash
# 1. Deploy authenticated extractor (15 min)
cd ~/Desktop/chicago-bi-app/extractors/taxi
./deploy_with_auth.sh

# 2. Run backfill on Cloud Shell (45 min)
# - Open https://console.cloud.google.com
# - Click terminal icon
# - Upload quarterly_backfill_q1_2020.sh
# - Run it with tmux

# 3. Verify data (5 min)
bq query --use_legacy_sql=false "SELECT COUNT(DISTINCT DATE(trip_start_timestamp)) FROM \`chicago-bi.raw_data.raw_taxi_trips\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
```

---

## 📊 What You'll Have After Completion

### In BigQuery

- ✅ 90 daily partitions (2020-01-01 to 2020-03-31)
- ✅ Millions of taxi trip records
- ✅ Ready for gold layer processing
- ✅ Ready for analysis

### Cost Impact

- **One-time:** $1.50 (backfill execution)
- **Monthly:** +$0.40 (20GB active storage)
- **After archive:** +$0.08/month (80% savings)

### Next Steps

1. Process to gold layer (analytics tables)
2. Build dashboards in Looker Studio
3. Run your analysis
4. Archive to Coldline (save costs)
5. Enable daily incremental updates

---

## 🛟 Need Help?

### Common Issues

**"Secret not found"**
→ See `docs/SOCRATA_SECRETS_USAGE.md`

**"Docker build failed"**
→ Make sure Docker Desktop is running

**"Cloud Shell timeout"**
→ Use tmux (instructions in `QUICKSTART_CLOUD_BACKFILL.md`)

**"Authentication failed"**
→ Check Socrata API credentials at https://data.cityofchicago.org/profile/app_tokens

---

## ✅ Pre-Flight Checklist

Before starting, ensure you have:

- [ ] GCP project created (`chicago-bi-app-msds-432-476520`)
- [ ] Socrata API credentials in Secret Manager
- [ ] Docker installed (if deploying locally)
- [ ] `gcloud` CLI authenticated
- [ ] BigQuery datasets created (bronze layer)
- [ ] ~1 hour of time available

---

## 🎯 Your Current Status

Based on our conversation, you have:

- ✅ GCP infrastructure set up
- ✅ Socrata credentials in Secret Manager
- ✅ BigQuery schemas defined
- ✅ Backfill scripts ready
- ✅ Authenticated extractor code ready
- ⏳ **NEXT:** Deploy authenticated extractor
- ⏳ **THEN:** Run Q1 2020 backfill

---

## 🚀 Ready to Start?

**Path 1: Complete Setup (Recommended)**
```bash
# 1. Read deployment guide
open ~/Desktop/chicago-bi-app/DEPLOY_AUTHENTICATED_EXTRACTOR.md

# 2. Deploy extractor
cd ~/Desktop/chicago-bi-app/extractors/taxi
./deploy_with_auth.sh

# 3. Read backfill guide
open ~/Desktop/chicago-bi-app/QUICKSTART_CLOUD_BACKFILL.md

# 4. Run backfill (on Cloud Shell)
```

**Path 2: Quick & Dirty (Skip reading)**
```bash
cd ~/Desktop/chicago-bi-app/extractors/taxi
./deploy_with_auth.sh
# Then follow prompts
```

---

**You're all set! Pick a path and let's get that Q1 2020 data! 🚀**

---

**Northwestern MSDS 432 - Phase 2**
**Group 2: Albin Anto Jose, Myetchae Thu, Ansh Gupta, Bickramjit Basu**
