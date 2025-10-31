# Deploy Authenticated Extractor - Quick Guide

**Time Required:** 10-15 minutes
**What It Does:** Updates your taxi extractor to use SODA API authentication (5,000+ requests/hour)

---

## ⚡ Quick Start (3 Commands)

```bash
# Step 1: Navigate to extractor directory
cd ~/Desktop/chicago-bi-app/extractors/taxi

# Step 2: Run deployment script
./deploy_with_auth.sh

# Step 3: Follow prompts
# - Type 'yes' when asked to test
# - Wait for deployment to complete
```

**That's it!** The script handles everything automatically.

---

## 📋 What The Script Does

1. ✅ Backs up your original files (`main.go` → `main_no_auth.go`)
2. ✅ Replaces with authenticated version
3. ✅ Updates Go dependencies
4. ✅ Tests that secrets are accessible
5. ✅ Tests Socrata API authentication
6. ✅ Builds Docker image
7. ✅ Pushes to Container Registry
8. ✅ Updates Cloud Run job
9. ✅ Optionally runs test execution

---

## 🔍 What You'll See

### Successful Output

```
================================================
Deploy Authenticated Taxi Extractor
================================================

================================================
Step 1: Backup Original Files
================================================

✅ Backed up main.go → main_no_auth.go
✅ Backed up go.mod → go_no_auth.mod

================================================
Step 2: Replace with Authenticated Version
================================================

✅ Replaced main.go with authenticated version
✅ Replaced go.mod with updated dependencies

================================================
Step 3: Update Go Dependencies
================================================

ℹ️  Running go mod tidy...
✅ Dependencies updated

================================================
Step 4: Test Authentication
================================================

✅ Secret 'socrata-key-id' exists
✅ Secret 'socrata-key-secret' exists
✅ Authentication test successful! (HTTP 200)
✅ Rate limit: 5,000+ requests/hour enabled

================================================
Step 5: Build Docker Image
================================================

✅ Docker image built successfully

================================================
Step 6: Push to Container Registry
================================================

✅ Image pushed to Container Registry

================================================
Step 7: Update Cloud Run Job
================================================

✅ Cloud Run job updated

================================================
Step 8: Test Execution
================================================

Would you like to test the extractor now? (yes/no)
> yes

✅ Test execution completed

================================================
Deployment Complete!
================================================

✅ Authenticated extractor deployed successfully!

Summary:
  • Image: gcr.io/chicago-bi-app-msds-432-476520/extractor-taxi:latest
  • Job: extractor-taxi
  • Region: us-central1
  • Authentication: ✅ SODA API (5,000+ requests/hour)

Next steps:
  1. Run Q1 2020 backfill:
     cd ~/Desktop/chicago-bi-app/backfill
     ./quarterly_backfill_q1_2020.sh all
```

---

## 🚨 Troubleshooting

### Error: "Secret 'socrata-key-id' NOT found"

**Problem:** Secrets not set up in Secret Manager

**Fix:**
```bash
# You need to create the secrets first
# See: docs/SOCRATA_SECRETS_USAGE.md

# Quick fix (replace with your actual credentials):
echo -n "YOUR_SOCRATA_KEY_ID" | gcloud secrets create socrata-key-id \
  --data-file=- \
  --project=chicago-bi-app-msds-432-476520

echo -n "YOUR_SOCRATA_KEY_SECRET" | gcloud secrets create socrata-key-secret \
  --data-file=- \
  --project=chicago-bi-app-msds-432-476520
```

### Error: "Authentication test failed (HTTP 403)"

**Problem:** Invalid credentials

**Fix:**
1. Check your Socrata API credentials at: https://data.cityofchicago.org/profile/app_tokens
2. Update secrets with correct values
3. Re-run deployment script

### Error: "Docker build failed"

**Problem:** Docker not running or not installed

**Fix:**
```bash
# Check if Docker is running
docker ps

# If not, start Docker Desktop
# Then re-run the deployment script
```

### Error: "main_with_auth.go not found"

**Problem:** Missing authenticated version file

**Fix:**
```bash
# Make sure you're in the correct directory
cd ~/Desktop/chicago-bi-app/extractors/taxi

# Check if file exists
ls -la main_with_auth.go

# If missing, the file should be in this directory
# Check that you pulled the latest code
```

---

## ✅ Verification Checklist

After deployment, verify:

- [ ] **Secrets exist:**
  ```bash
  gcloud secrets list --project=chicago-bi-app-msds-432-476520 | grep socrata
  ```

- [ ] **Authentication works:**
  ```bash
  # Should return HTTP 200
  KEY_ID=$(gcloud secrets versions access latest --secret="socrata-key-id" --project=chicago-bi-app-msds-432-476520)
  KEY_SECRET=$(gcloud secrets versions access latest --secret="socrata-key-secret" --project=chicago-bi-app-msds-432-476520)
  curl -u "$KEY_ID:$KEY_SECRET" "https://data.cityofchicago.org/resource/wrvz-psew.json?\$limit=1"
  ```

- [ ] **Cloud Run job exists:**
  ```bash
  gcloud run jobs describe extractor-taxi --region=us-central1
  ```

- [ ] **Test execution succeeds:**
  ```bash
  gcloud run jobs execute extractor-taxi \
    --region=us-central1 \
    --update-env-vars=START_DATE=2024-01-01,END_DATE=2024-01-01 \
    --wait
  ```

---

## 🎯 After Deployment

### Ready for Q1 2020 Backfill!

Now you can safely run the backfill with authentication:

```bash
cd ~/Desktop/chicago-bi-app/backfill
./quarterly_backfill_q1_2020.sh all
```

**Benefits with authentication:**
- ✅ 5,000+ requests/hour (vs 1,000/day without)
- ✅ Better performance
- ✅ No risk of hitting rate limits
- ✅ Production-ready setup

---

## 📊 What Changed?

### Before (No Authentication)

```go
// Old code
resp, err := http.Get(queryURL)
```

**Rate Limit:** 1,000 requests/day

### After (With Authentication)

```go
// New code
req, err := http.NewRequest("GET", queryURL, nil)
req.SetBasicAuth(keyID, keySecret)  // ← Authentication!
resp, err := client.Do(req)
```

**Rate Limit:** 5,000+ requests/hour 🚀

---

## 📁 Files Modified

| File | Status | Purpose |
|------|--------|---------|
| `main.go` | ✅ Replaced | Now uses authentication |
| `go.mod` | ✅ Updated | Added Secret Manager library |
| `main_no_auth.go` | ✅ Created | Backup of original |
| `go_no_auth.mod` | ✅ Created | Backup of original |

---

## 🔄 Rollback (If Needed)

If something goes wrong, you can easily rollback:

```bash
cd ~/Desktop/chicago-bi-app/extractors/taxi

# Restore original files
cp main_no_auth.go main.go
cp go_no_auth.mod go.mod

# Rebuild and redeploy
./deploy_with_auth.sh
```

---

## 📚 Related Documentation

- **Secrets Setup:** `/docs/SOCRATA_SECRETS_USAGE.md`
- **Authentication Guide:** `/docs/AUTHENTICATION_AND_DATASETS.md`
- **Backfill Guide:** `/QUICKSTART_CLOUD_BACKFILL.md`
- **Full Workflow:** `/docs/DATA_INGESTION_WORKFLOW.md`

---

## 🚀 Ready to Deploy?

```bash
cd ~/Desktop/chicago-bi-app/extractors/taxi
./deploy_with_auth.sh
```

**Time:** 10-15 minutes
**Cost:** $0 (uses existing Cloud Build free tier)
**Result:** Production-ready authenticated extractor!

---

**Questions?** Check the troubleshooting section above or review `/docs/AUTHENTICATION_AND_DATASETS.md`
