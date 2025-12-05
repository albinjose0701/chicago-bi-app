# Fix Docker Authentication Error

**Error:**
```
error from registry: Unauthenticated request. Unauthenticated requests do not have
permission "artifactregistry.repositories.uploadArtifacts" on resource
"projects/chicago-bi-app-msds-432-476520/locations/us/repositories/gcr.io"
```

---

## 🎯 Two Solutions (Pick One)

### **Solution 1: Use Cloud Build (EASIEST - Recommended)** ✅

**No Docker authentication needed! Builds in the cloud.**

```bash
cd ~/Desktop/chicago-bi-app/extractors/taxi

# Just run this script - it handles everything!
./deploy_with_cloud_build.sh
```

**Benefits:**
- ✅ No Docker authentication issues
- ✅ No local Docker needed
- ✅ Faster (parallel builds in cloud)
- ✅ Free tier: 120 build-minutes/day

**Time:** 10 minutes (same as before, but no auth hassle!)

---

### **Solution 2: Fix Docker Authentication (If you prefer local builds)**

```bash
cd ~/Desktop/chicago-bi-app/extractors/taxi

# Step 1: Fix Docker authentication
./fix_docker_auth.sh

# Step 2: Re-run original deployment
./deploy_with_auth.sh
```

**When to use:**
- You want to build locally
- You're debugging Docker issues
- You prefer full control

**Time:** 15 minutes (5 min fix + 10 min deploy)

---

## 🚀 Quick Start (Recommended)

Just run this **ONE COMMAND:**

```bash
cd ~/Desktop/chicago-bi-app/extractors/taxi
./deploy_with_cloud_build.sh
```

**That's it!** No Docker authentication headaches.

---

## 📋 What Each Solution Does

### Solution 1: Cloud Build Script

```bash
./deploy_with_cloud_build.sh
```

**Steps:**
1. ✅ Backs up your files
2. ✅ Replaces with authenticated version
3. ✅ Tests Socrata API authentication
4. ✅ **Builds in Cloud Build** (skips local Docker!)
5. ✅ Pushes to Container Registry (automatic)
6. ✅ Updates Cloud Run job
7. ✅ Optionally tests execution

**No Docker authentication needed!**

---

### Solution 2: Docker Auth Fix

```bash
./fix_docker_auth.sh
```

**Steps:**
1. ✅ Enables Artifact Registry API
2. ✅ Configures Docker credential helper
3. ✅ Grants Storage Admin permissions
4. ✅ Tests Docker authentication

**Then run:** `./deploy_with_auth.sh`

---

## 🔍 Why This Error Happened

Docker wasn't configured to authenticate with Google Container Registry (GCR).

**What happens:**
1. Your code builds locally with Docker ✅
2. Docker tries to push to GCR ❌
3. GCR says "Who are you?" → Error!

**Solution 1 (Cloud Build):** Skips local Docker entirely
**Solution 2 (Docker Auth):** Teaches Docker how to authenticate

---

## 💡 Comparison

| Feature | Cloud Build | Local Docker |
|---------|-------------|--------------|
| **Setup** | Zero | Fix auth first |
| **Speed** | Fast (cloud) | Depends on network |
| **Cost** | Free tier | Free |
| **Debugging** | Cloud logs | Local logs |
| **Best For** | Production | Development |

**Recommendation:** Use Cloud Build (Solution 1)

---

## 🆘 If Cloud Build Fails

**Error:** "Cloud Build API not enabled"

**Fix:**
```bash
gcloud services enable cloudbuild.googleapis.com \
  --project=chicago-bi-app-msds-432-476520
```

**Error:** "Permission denied"

**Fix:**
```bash
# Grant yourself permissions
gcloud projects add-iam-policy-binding chicago-bi-app-msds-432-476520 \
  --member="user:$(gcloud config get-value account)" \
  --role="roles/cloudbuild.builds.editor"
```

---

## 🆘 If Docker Auth Fix Fails

**Error:** "gcloud auth configure-docker: command not found"

**Fix:**
```bash
# Update gcloud
gcloud components update
```

**Error:** "Permission denied for storage.admin"

**Fix:**
```bash
# You might need project owner to grant yourself this role
# Ask your project admin or use Cloud Build instead
```

---

## ✅ After Successful Deployment

You should see:

```
================================================
Deployment Complete!
================================================

✅ Authenticated extractor deployed successfully!

Summary:
  • Build Method: Cloud Build
  • Image: gcr.io/chicago-bi-app-msds-432-476520/extractor-taxi:latest
  • Job: extractor-taxi
  • Authentication: ✅ SODA API (5,000+ requests/hour)

Next steps:
  1. Run Q1 2020 backfill:
     cd ~/Desktop/chicago-bi-app/backfill
     ./quarterly_backfill_q1_2020.sh all
```

---

## 🚀 Quick Commands Reference

| Task | Command |
|------|---------|
| **Deploy with Cloud Build** (easiest) | `./deploy_with_cloud_build.sh` |
| **Fix Docker auth** | `./fix_docker_auth.sh` |
| **Deploy with local Docker** | `./deploy_with_auth.sh` |
| **Test authentication** | `curl -u "$KEY_ID:$KEY_SECRET" "https://data.cityofchicago.org/resource/wrvz-psew.json?\$limit=1"` |
| **Check Cloud Run job** | `gcloud run jobs describe extractor-taxi --region=us-central1` |

---

## 🎯 Bottom Line

**Use this command:**
```bash
cd ~/Desktop/chicago-bi-app/extractors/taxi
./deploy_with_cloud_build.sh
```

**It avoids all Docker authentication issues!**

Then proceed with Q1 2020 backfill as planned.

---

**Questions?** Both scripts are safe to run. Cloud Build is easier and recommended! 🚀
