# Testing Guide - Understanding Extraction Times & Test Dates

## ⏱️ Expected Extraction Times

### Per-Day Extraction Time

**For Q1 2020 (Pre-COVID, high volume):**
- **Typical day:** 1-2 minutes
- **Weekend:** 30-60 seconds (lower volume)
- **Weekday:** 1.5-2.5 minutes (higher volume)

**Breakdown:**
```
API Request:      5-10 seconds
Data Download:    20-40 seconds (depends on trip count)
GCS Upload:       5-15 seconds
Total:            30-65 seconds average
```

**Expected trip counts per day (Q1 2020):**
- **Weekday:** 40,000-60,000 trips
- **Weekend:** 20,000-35,000 trips
- **Holiday:** 10,000-20,000 trips

---

## 📅 Why the Test Uses Yesterday's Date

### The Default Test Behavior

When `deploy_with_cloud_build.sh` asks to test, it uses **yesterday's date** as a **connectivity test**:

```bash
YESTERDAY=$(date -v-1d +%Y-%m-%d)  # e.g., 2025-10-30
```

### What This Tests

**NOT** a data validation test - it's testing:
1. ✅ Can Cloud Run job start?
2. ✅ Can it authenticate to Secret Manager?
3. ✅ Can it call Chicago Data Portal API?
4. ✅ Does API return HTTP 200? (even if 0 records)
5. ✅ Can it write to GCS?
6. ✅ Does it complete without crashing?

### Expected Result for Yesterday

**You'll see:**
```
Extracted 0 trips
```

**This is NORMAL and OK!** Because:
- Chicago taxi data: **2013-2023** (dataset range)
- Yesterday (2025): **No data exists**
- API returns: `[]` (empty array, HTTP 200 ✅)
- Extraction "succeeds" with 0 records

**The test passes if:**
- ✅ No errors
- ✅ HTTP 200 from API
- ✅ Job completes successfully
- ✅ No authentication failures

---

## 🎯 Better Test: Use Known Good Date

### Problem with Yesterday

```
START_DATE=2025-10-30  # ❌ No data - outside dataset range!
Result: 0 trips extracted
```

### Solution: Test with 2020-01-15

```
START_DATE=2020-01-15  # ✅ Middle of Q1 2020, lots of data!
Result: ~45,000 trips extracted
```

### Run Better Test

I've created a test script that uses a **known good date**:

```bash
cd ~/Desktop/chicago-bi-app/extractors/taxi
./test_single_date.sh
```

**This tests:**
- Date: **2020-01-15** (Wednesday in Q1 2020)
- Expected: **40,000-60,000 trips**
- Time: **~1-2 minutes**

**Output:**
```
================================================
Test Taxi Extractor with Known Good Date
================================================

Test Date: 2020-01-15
Expected: 40,000-60,000 trips (pre-COVID Wednesday)

ℹ️  Running extraction...

[Cloud Run job executes...]

✅ Test execution completed!
✅ Found 48,523 trips in BigQuery for 2020-01-15
✅ Test PASSED - Data successfully extracted and loaded!
```

---

## 📊 Dataset Date Ranges (Reference)

| Dataset | Date Range | Current Status |
|---------|------------|----------------|
| **Taxi Trips** | 2013-01-01 to 2023-12-31 | Historical |
| **TNP Permits** | 2018-01-01 to 2022-12-31 | Historical |
| **COVID Cases** | 2020-03-01 to 2023-06-30 | Historical |
| **Building Permits** | 2006-01-01 to 2024-09-30 | Updated monthly |

**Today's date:** 2025-10-31 (no data in most datasets!)

---

## 🔍 How to Verify Test Results

### Option 1: Check Cloud Run Logs

```bash
gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.job_name=extractor-taxi" \
  --limit=50 \
  --format=json
```

**Look for:**
```
"Extracted 0 trips"        # If testing yesterday
"Extracted 45000 trips"    # If testing 2020-01-15
```

### Option 2: Check BigQuery

```bash
bq query --use_legacy_sql=false \
  "SELECT DATE(trip_start_timestamp) as date, COUNT(*) as trips
   FROM \`chicago-bi.raw_data.raw_taxi_trips\`
   WHERE DATE(trip_start_timestamp) = '2020-01-15'"
```

**Expected output:**
```
+------------+-------+
|    date    | trips |
+------------+-------+
| 2020-01-15 | 48523 |
+------------+-------+
```

### Option 3: Check GCS Landing Zone

```bash
gsutil ls -lh gs://chicago-bi-app-msds-432-476520-landing/taxi/2020-01-15/
```

**Expected output:**
```
  12.5 MiB  2025-10-31T12:34:56Z  gs://.../taxi/2020-01-15/data.json
```

---

## 🎯 Recommendations

### During Initial Deployment

When `deploy_with_cloud_build.sh` asks:
```
Would you like to test the extractor now? (yes/no)
>
```

**Option 1: Skip it** (type `no`)
- Reason: Test uses yesterday (no data)
- Then run better test manually:
  ```bash
  ./test_single_date.sh
  ```

**Option 2: Run it anyway** (type `yes`)
- Will complete in ~10 seconds (0 trips)
- Verifies connectivity
- Then run better test:
  ```bash
  ./test_single_date.sh
  ```

### Before Q1 2020 Backfill

**Always test with one known good date first:**

```bash
# Test one day from your target range
./test_single_date.sh

# If successful, run full backfill
cd ../backfill
./quarterly_backfill_q1_2020.sh all
```

---

## 📈 Q1 2020 Backfill Estimates

### Total Time Estimate

**90 days × 1.5 minutes/day = ~135 minutes = 2.25 hours**

But with 30-second delays:
**90 days × (1.5 min + 0.5 min delay) = ~180 minutes = 3 hours**

**Actual backfill script uses:** 30-second delays
**Total estimated time:** **~3 hours** for 90 days

**Breakdown:**
- Jan 2020 (31 days): ~62 minutes
- Feb 2020 (29 days): ~58 minutes
- Mar 2020 (31 days): ~62 minutes
- **Total: ~3 hours**

### Data Volume Estimate

**Q1 2020 total:**
- **~3.5-4.5 million trips**
- **~15-20 GB JSON data**
- **~2-3 GB Parquet** (after compression)

---

## 🆘 What to Do If Test Fails

### 0 Trips Extracted (Using Yesterday)

**Status:** ✅ **NORMAL** - Not a failure!

**Why:** No data exists for future dates

**Action:** Run better test with 2020-01-15:
```bash
./test_single_date.sh
```

### Authentication Error (HTTP 401/403)

**Status:** ❌ **FAILURE**

**Fix:**
```bash
# Check secrets exist
gcloud secrets list --project=chicago-bi-app-msds-432-476520

# Test API manually
KEY_ID=$(gcloud secrets versions access latest --secret="socrata-key-id")
KEY_SECRET=$(gcloud secrets versions access latest --secret="socrata-key-secret")
curl -u "$KEY_ID:$KEY_SECRET" "https://data.cityofchicago.org/resource/wrvz-psew.json?\$limit=1"
```

### Timeout (>5 minutes for one day)

**Status:** ⚠️ **SLOW**

**Possible causes:**
- Slow network
- Chicago API slow
- Very high trip volume day

**Action:** Wait longer, or check logs:
```bash
gcloud run jobs executions list --job=extractor-taxi --region=us-central1
```

---

## ✅ Success Indicators

**Test passed if you see:**

1. ✅ Job completes (not stuck or error)
2. ✅ No authentication errors
3. ✅ Either:
   - 0 trips (if using yesterday - connectivity OK)
   - 40,000+ trips (if using 2020-01-15 - DATA OK!)

**Ready for backfill if:**
- ✅ Test with 2020-01-15 shows actual data
- ✅ Data appears in BigQuery
- ✅ No errors in logs

---

## 🚀 Next Steps

1. **Deploy extractor:**
   ```bash
   ./deploy_with_cloud_build.sh
   ```

2. **When asked to test, type `no`** (skip yesterday test)

3. **Run better test:**
   ```bash
   ./test_single_date.sh
   ```

4. **If test passes, run Q1 2020 backfill:**
   ```bash
   cd ../backfill
   ./quarterly_backfill_q1_2020.sh all
   ```

---

**Summary:** Yesterday's test = connectivity check (0 trips OK). For real data test, use `./test_single_date.sh` with 2020-01-15!
