# SODA API Authentication & Dataset Configuration

## Overview

This document explains:
1. **Where SODA API authentication is set up**
2. **Where datasets are configured**
3. **How to add authentication to extractors**
4. **How to add new datasets**

---

## 🔐 SODA API Authentication

### Current Setup

✅ **Credentials ARE stored in GCP Secret Manager:**

```bash
# Check if secrets exist
gcloud secrets list --project=chicago-bi-app-msds-432-476520

# Output:
# NAME                 CREATED              REPLICATION_POLICY  LOCATIONS
# socrata-key-id       2025-10-30T...      automatic           -
# socrata-key-secret   2025-10-30T...      automatic           -
```

### Where Secrets Were Created

**File:** `/setup_gcp_infrastructure.sh` (lines vary)

The infrastructure setup script created these secrets and granted permissions:

```bash
# Secret Manager API enabled
gcloud services enable secretmanager.googleapis.com

# Secrets created (you added them manually)
echo -n "YOUR_KEY_ID" | gcloud secrets create socrata-key-id --data-file=-
echo -n "YOUR_KEY_SECRET" | gcloud secrets create socrata-key-secret --data-file=-

# Permissions granted
gcloud secrets add-iam-policy-binding socrata-key-id \
  --member="serviceAccount:cloud-run@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Benefits of Authentication

| Feature | Unauthenticated | Authenticated |
|---------|----------------|---------------|
| **Rate Limit** | 1,000 requests/day | 5,000+ requests/hour |
| **Throttling** | Strict | Lenient |
| **Access** | Read-only public data | Read + potential write |
| **Best For** | Testing | Production |

---

## ⚠️ CRITICAL GAP: Extractor Not Using Authentication!

### Current Extractor Code

**File:** `/extractors/taxi/main.go:97-103`

```go
func extractData(queryURL string) ([]TaxiTrip, error) {
    // ❌ NO AUTHENTICATION!
    resp, err := http.Get(queryURL)
    if err != nil {
        return nil, fmt.Errorf("failed to fetch data: %w", err)
    }
    // ...
}
```

**Problem:** Uses plain `http.Get()` without authentication headers!

### Impact on Q1 2020 Backfill

**Without Authentication:**
- 90 requests (one per day)
- Rate limit: 1,000/day
- Status: ✅ Will work, but uses 9% of daily quota

**With Authentication:**
- 90 requests in 45 minutes
- Rate limit: 5,000+/hour
- Status: ✅✅ Only 1.8% of hourly quota

**Recommendation:** ⚠️ **Add authentication BEFORE running backfill!**

---

## 🔧 How to Add Authentication

### Option 1: Replace Current Extractor (Recommended)

I've created an authenticated version for you:

```bash
cd /Users/albin/Desktop/chicago-bi-app/extractors/taxi

# Backup original
cp main.go main_no_auth.go
cp go.mod go_no_auth.mod

# Use authenticated version
cp main_with_auth.go main.go
cp go_with_auth.mod go.mod

# Update dependencies
go mod tidy
```

### Option 2: Manual Update

Add to your `main.go`:

```go
import (
    secretmanager "cloud.google.com/go/secretmanager/apiv1"
    "cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
)

// Get secret from Secret Manager
func getSecret(ctx context.Context, secretName string) (string, error) {
    client, err := secretmanager.NewClient(ctx)
    if err != nil {
        return "", fmt.Errorf("failed to create client: %v", err)
    }
    defer client.Close()

    req := &secretmanagerpb.AccessSecretVersionRequest{
        Name: fmt.Sprintf("projects/chicago-bi-app-msds-432-476520/secrets/%s/versions/latest", secretName),
    }

    result, err := client.AccessSecretVersion(ctx, req)
    if err != nil {
        return "", fmt.Errorf("failed to access secret: %v", err)
    }

    return string(result.Payload.Data), nil
}

// Make authenticated request
func extractDataWithAuth(queryURL, keyID, keySecret string) ([]TaxiTrip, error) {
    req, err := http.NewRequest("GET", queryURL, nil)
    if err != nil {
        return nil, err
    }

    // Add HTTP Basic Auth
    req.SetBasicAuth(keyID, keySecret)
    req.Header.Add("Accept", "application/json")

    client := &http.Client{Timeout: 120 * time.Second}
    resp, err := client.Do(req)
    // ... rest of code
}
```

### Update `go.mod`

```go
require (
    cloud.google.com/go/storage v1.35.1
    cloud.google.com/go/secretmanager v1.11.1  // ADD THIS LINE
    google.golang.org/api v0.150.0
)
```

---

## 📊 Where Datasets Are Configured

### Current Setup: Hardcoded in Each Extractor

**File:** `/extractors/taxi/main.go:17-18`

```go
const (
    // Hardcoded for taxi dataset
    baseURL = "https://data.cityofchicago.org/resource/wrvz-psew.json"
)
```

### New Setup: Configuration File

**File:** `/config/datasets.json`

I've created a centralized configuration:

```json
{
  "datasets": [
    {
      "name": "taxi",
      "datasetId": "wrvz-psew",
      "baseURL": "https://data.cityofchicago.org/resource/wrvz-psew.json",
      "dateColumn": "trip_start_timestamp",
      "enabled": true
    },
    {
      "name": "tnp",
      "datasetId": "889t-nwn4",
      "baseURL": "https://data.cityofchicago.org/resource/889t-nwn4.json",
      "dateColumn": "issue_date",
      "enabled": true
    }
    // ... more datasets
  ]
}
```

---

## 📋 All Available Datasets

| Name | Dataset ID | API Endpoint | Date Column | Status |
|------|------------|--------------|-------------|--------|
| **Taxi Trips** | `wrvz-psew` | `/resource/wrvz-psew.json` | `trip_start_timestamp` | ✅ Enabled |
| **TNP Permits** | `889t-nwn4` | `/resource/889t-nwn4.json` | `issue_date` | ✅ Enabled |
| **COVID Cases** | `yhhz-zm2v` | `/resource/yhhz-zm2v.json` | `week_start` | ⏸️ Disabled |
| **Building Permits** | `ydr8-5enu` | `/resource/ydr8-5enu.json` | `issue_date` | ⏸️ Disabled |
| **CCVI** | `xhc6-88s9` | `/resource/xhc6-88s9.json` | `week_start` | ⏸️ Disabled |
| **ZIP Boundaries** | `igwz-8jzy` | `/resource/igwz-8jzy.json` | N/A (static) | ⏸️ Disabled |

### Find Dataset IDs

1. Go to [Chicago Data Portal](https://data.cityofchicago.org/)
2. Find your dataset
3. Click **API** tab
4. Look for the API Endpoint: `https://data.cityofchicago.org/resource/XXXX-XXXX.json`
5. The `XXXX-XXXX` is your dataset ID

**Example:**
- URL: `https://data.cityofchicago.org/Transportation/Taxi-Trips/wrvz-psew`
- Dataset ID: `wrvz-psew`
- API Endpoint: `https://data.cityofchicago.org/resource/wrvz-psew.json`

---

## 🚀 Adding a New Dataset

### Step 1: Add to Configuration File

Edit `/config/datasets.json`:

```json
{
  "name": "new_dataset",
  "displayName": "New Dataset",
  "datasetId": "xxxx-xxxx",
  "baseURL": "https://data.cityofchicago.org/resource/xxxx-xxxx.json",
  "dateColumn": "date_field_name",
  "primaryKey": "id",
  "enabled": true,
  "description": "Description of the dataset"
}
```

### Step 2: Create Extractor

```bash
# Copy taxi extractor as template
cp -r extractors/taxi extractors/new_dataset

# Update the code
cd extractors/new_dataset

# Edit main.go:
# - Change baseURL to new dataset
# - Update struct definitions for new dataset fields
# - Update dateColumn in queries
```

### Step 3: Create BigQuery Schema

Edit `/bigquery/schemas/bronze_layer.sql`:

```sql
CREATE TABLE IF NOT EXISTS `chicago-bi.raw_data.raw_new_dataset`
(
  -- Define fields based on dataset schema
  id STRING NOT NULL,
  date_field DATE,
  -- ... other fields

  -- Metadata
  _ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  _source_file STRING
)
PARTITION BY date_field
OPTIONS(
  description = "Raw new dataset data",
  require_partition_filter = TRUE
);
```

### Step 4: Deploy Extractor

```bash
# Build and deploy to Cloud Run
gcloud run jobs create extractor-new-dataset \
  --image=gcr.io/chicago-bi-app-msds-432-476520/extractor-new-dataset:latest \
  --region=us-central1 \
  --service-account=cloud-run@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com
```

---

## 🔍 Testing Authentication

### Quick Test Script

```bash
#!/bin/bash
# test_auth.sh

PROJECT_ID="chicago-bi-app-msds-432-476520"

# Get credentials
KEY_ID=$(gcloud secrets versions access latest --secret="socrata-key-id" --project=$PROJECT_ID)
KEY_SECRET=$(gcloud secrets versions access latest --secret="socrata-key-secret" --project=$PROJECT_ID)

# Test API call
echo "Testing Socrata API with authentication..."
RESPONSE=$(curl -s -w "\n%{http_code}" -u "$KEY_ID:$KEY_SECRET" \
  "https://data.cityofchicago.org/resource/wrvz-psew.json?\$limit=1")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ Authentication successful! (HTTP $HTTP_CODE)"
  echo "✅ Rate limit: 5,000+ requests/hour enabled"
else
  echo "❌ Authentication failed (HTTP $HTTP_CODE)"
fi
```

**Run test:**
```bash
chmod +x test_auth.sh
./test_auth.sh
```

---

## 🔄 Deployment Checklist

Before running Q1 2020 backfill, ensure:

- [ ] ✅ Secrets exist in Secret Manager
  ```bash
  gcloud secrets list --project=chicago-bi-app-msds-432-476520
  ```

- [ ] ✅ Service account has permission
  ```bash
  gcloud secrets get-iam-policy socrata-key-id \
    --project=chicago-bi-app-msds-432-476520
  ```

- [ ] ✅ Extractor uses authentication
  - Check if `main_with_auth.go` is deployed
  - Look for `SetBasicAuth()` in code

- [ ] ✅ Test authentication works
  ```bash
  ./test_auth.sh
  ```

- [ ] ✅ Deploy updated extractor
  ```bash
  # Rebuild with authentication
  docker build -t gcr.io/chicago-bi-app-msds-432-476520/extractor-taxi:latest .
  docker push ...
  gcloud run jobs update extractor-taxi --image=...
  ```

---

## 📚 References

### Documentation
- [Socrata SODA API Docs](https://dev.socrata.com/docs/endpoints.html)
- [Socrata Authentication](https://dev.socrata.com/docs/authentication.html)
- [GCP Secret Manager](https://cloud.google.com/secret-manager/docs)

### Related Files
- `/docs/SOCRATA_SECRETS_USAGE.md` - Detailed secret usage guide
- `/config/datasets.json` - Dataset configuration
- `/extractors/taxi/main_with_auth.go` - Authenticated extractor template
- `/README.md:453-458` - Dataset list

---

## Summary

### ✅ What's Set Up

- [x] SODA API credentials in Secret Manager
- [x] Service account permissions
- [x] Dataset configuration file
- [x] Authenticated extractor template

### ⚠️ What Needs to Be Done

- [ ] **Replace `main.go` with `main_with_auth.go`**
- [ ] **Update `go.mod` dependencies**
- [ ] **Rebuild and redeploy extractor**
- [ ] **Test authentication**
- [ ] **Run Q1 2020 backfill**

**Estimated time:** 10-15 minutes to update and deploy

---

**Next Step:** Replace the extractor code and redeploy before running the backfill!
