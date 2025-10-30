# Socrata API Secrets - Usage Guide

**Created:** October 30, 2025
**Status:** ✅ Secrets stored in GCP Secret Manager

---

## 📋 What Was Set Up

### Secrets Created
✅ **socrata-key-id** - Socrata API Key ID
✅ **socrata-key-secret** - Socrata API Key Secret

### Permissions Granted
✅ Cloud Run service account (`cloud-run@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com`) has `secretAccessor` role

### Benefits
- 🚀 **5,000+ API requests/hour** (vs 1,000 without authentication)
- 🔐 **Secure storage** - Never hardcode credentials in code
- ✅ **Read + Write access** - Full API capabilities (if needed)

---

## 🔐 How to Use Secrets in Your Extractors

### Option 1: Go Extractor (Recommended)

```go
package main

import (
    "context"
    "fmt"
    "log"
    "net/http"

    secretmanager "cloud.google.com/go/secretmanager/apiv1"
    "cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
)

const (
    projectID = "chicago-bi-app-msds-432-476520"
)

// Get secret from Secret Manager
func getSecret(ctx context.Context, secretName string) (string, error) {
    client, err := secretmanager.NewClient(ctx)
    if err != nil {
        return "", fmt.Errorf("failed to create client: %v", err)
    }
    defer client.Close()

    req := &secretmanagerpb.AccessSecretVersionRequest{
        Name: fmt.Sprintf("projects/%s/secrets/%s/versions/latest", projectID, secretName),
    }

    result, err := client.AccessSecretVersion(ctx, req)
    if err != nil {
        return "", fmt.Errorf("failed to access secret: %v", err)
    }

    return string(result.Payload.Data), nil
}

// Socrata API client with authentication
func makeSocrataRequest(url string) (*http.Response, error) {
    ctx := context.Background()

    // Retrieve credentials from Secret Manager
    keyID, err := getSecret(ctx, "socrata-key-id")
    if err != nil {
        return nil, err
    }

    keySecret, err := getSecret(ctx, "socrata-key-secret")
    if err != nil {
        return nil, err
    }

    // Create HTTP request with Basic Auth
    req, err := http.NewRequest("GET", url, nil)
    if err != nil {
        return nil, err
    }

    // Add HTTP Basic Authentication
    req.SetBasicAuth(keyID, keySecret)
    req.Header.Add("Accept", "application/json")

    // Make the request
    client := &http.Client{}
    return client.Do(req)
}

func main() {
    // Example: Fetch Chicago taxi data
    url := "https://data.cityofchicago.org/resource/wrvz-psew.json?$limit=100"

    resp, err := makeSocrataRequest(url)
    if err != nil {
        log.Fatalf("Request failed: %v", err)
    }
    defer resp.Body.Close()

    log.Printf("Status: %d", resp.StatusCode)
    // Process response...
}
```

**Add to go.mod:**
```go
require (
    cloud.google.com/go/secretmanager v1.11.1
)
```

---

### Option 2: Python Extractor

```python
from google.cloud import secretmanager
import requests
from requests.auth import HTTPBasicAuth

PROJECT_ID = "chicago-bi-app-msds-432-476520"

def get_secret(secret_name):
    """Retrieve secret from GCP Secret Manager"""
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{PROJECT_ID}/secrets/{secret_name}/versions/latest"
    response = client.access_secret_version(request={"name": name})
    return response.payload.data.decode("UTF-8")

def fetch_socrata_data(url, params=None):
    """Fetch data from Socrata API with authentication"""
    # Get credentials from Secret Manager
    key_id = get_secret("socrata-key-id")
    key_secret = get_secret("socrata-key-secret")

    # Make authenticated request
    response = requests.get(
        url,
        params=params,
        auth=HTTPBasicAuth(key_id, key_secret),
        headers={"Accept": "application/json"}
    )

    response.raise_for_status()
    return response.json()

# Example usage
if __name__ == "__main__":
    url = "https://data.cityofchicago.org/resource/wrvz-psew.json"
    params = {"$limit": 100}

    data = fetch_socrata_data(url, params)
    print(f"Fetched {len(data)} records")
```

**Install dependencies:**
```bash
pip install google-cloud-secret-manager requests
```

---

### Option 3: Command Line (For Testing)

```bash
# Retrieve Key ID
gcloud secrets versions access latest \
    --secret="socrata-key-id" \
    --project=chicago-bi-app-msds-432-476520

# Retrieve Key Secret
gcloud secrets versions access latest \
    --secret="socrata-key-secret" \
    --project=chicago-bi-app-msds-432-476520

# Test API call with curl
KEY_ID=$(gcloud secrets versions access latest --secret="socrata-key-id" --project=chicago-bi-app-msds-432-476520)
KEY_SECRET=$(gcloud secrets versions access latest --secret="socrata-key-secret" --project=chicago-bi-app-msds-432-476520)

curl -u "$KEY_ID:$KEY_SECRET" \
    "https://data.cityofchicago.org/resource/wrvz-psew.json?\$limit=5"
```

---

## 💰 Secret Manager Costs

### Pricing
- **Active secret versions:** $0.06 per secret per month
- **Secret access operations:** $0.03 per 10,000 operations
- **Free tier:** 6 active secrets + 10,000 operations per month

### Your Usage
- **Secrets:** 2 (socrata-key-id, socrata-key-secret)
- **Monthly cost:** ~$0.12 (within free tier!)
- **Access operations:** ~1,000-2,000/month (within free tier!)
- **Expected cost:** **$0/month** 🎉

---

## 🔄 Secret Management Commands

### List Secrets
```bash
gcloud secrets list --project=chicago-bi-app-msds-432-476520
```

### View Secret Metadata
```bash
gcloud secrets describe socrata-key-id --project=chicago-bi-app-msds-432-476520
```

### Update/Rotate Secret (Add New Version)
```bash
# Update Key ID
echo -n "NEW_KEY_ID" | gcloud secrets versions add socrata-key-id \
    --data-file=- \
    --project=chicago-bi-app-msds-432-476520

# Update Key Secret
echo -n "NEW_KEY_SECRET" | gcloud secrets versions add socrata-key-secret \
    --data-file=- \
    --project=chicago-bi-app-msds-432-476520
```

### View Secret Versions
```bash
gcloud secrets versions list socrata-key-id --project=chicago-bi-app-msds-432-476520
```

### Delete Secret (If Needed)
```bash
# ⚠️ WARNING: This permanently deletes the secret!
gcloud secrets delete socrata-key-id --project=chicago-bi-app-msds-432-476520
```

---

## 🛡️ Security Best Practices

### ✅ DO:
- ✅ Use Secret Manager for all credentials
- ✅ Grant minimal IAM permissions (`secretAccessor` only)
- ✅ Rotate secrets periodically (every 90 days recommended)
- ✅ Use `--data-file=-` to avoid shell history
- ✅ Enable audit logging for secret access

### ❌ DON'T:
- ❌ Hardcode credentials in source code
- ❌ Commit secrets to Git
- ❌ Log secret values
- ❌ Share secrets via email/Slack
- ❌ Use environment variables for secrets (use Secret Manager instead)

---

## 🧪 Testing Your Setup

### Quick Test Script
```bash
#!/bin/bash
# test_socrata_auth.sh

PROJECT_ID="chicago-bi-app-msds-432-476520"

echo "Testing Socrata API authentication..."

# Get credentials
KEY_ID=$(gcloud secrets versions access latest --secret="socrata-key-id" --project=$PROJECT_ID)
KEY_SECRET=$(gcloud secrets versions access latest --secret="socrata-key-secret" --project=$PROJECT_ID)

# Test API call
RESPONSE=$(curl -s -w "\n%{http_code}" -u "$KEY_ID:$KEY_SECRET" \
    "https://data.cityofchicago.org/resource/wrvz-psew.json?\$limit=1")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Authentication successful! (HTTP $HTTP_CODE)"
    echo "✅ Socrata API is accessible with your credentials"
else
    echo "❌ Authentication failed (HTTP $HTTP_CODE)"
    echo "Response: $(echo "$RESPONSE" | head -n-1)"
fi
```

**Run the test:**
```bash
chmod +x test_socrata_auth.sh
./test_socrata_auth.sh
```

---

## 📚 Additional Resources

### Secret Manager Documentation
- [Secret Manager Quickstart](https://cloud.google.com/secret-manager/docs/quickstart)
- [Best Practices](https://cloud.google.com/secret-manager/docs/best-practices)
- [Client Libraries](https://cloud.google.com/secret-manager/docs/reference/libraries)

### Socrata API Documentation
- [SODA API Docs](https://dev.socrata.com/docs/endpoints.html)
- [Authentication](https://dev.socrata.com/docs/authentication.html)
- [SoQL Query Language](https://dev.socrata.com/docs/queries/)
- [Chicago Data Portal](https://data.cityofchicago.org/)

---

## 🚀 Next Steps

Now that your secrets are configured:

1. ✅ Update your extractor code to use Secret Manager (see examples above)
2. ✅ Test authentication with a simple API call
3. ✅ Build your production extractors
4. ✅ Deploy to Cloud Run Jobs
5. ✅ Monitor secret access in Cloud Operations

---

**Setup completed successfully! 🎉**
Your Socrata credentials are securely stored and ready to use.
