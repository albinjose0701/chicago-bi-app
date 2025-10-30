# Chicago BI App - Updated Week 1 Plan
**Production-Ready Implementation - All Features This Week**

---

## 📋 Your Excellent Questions Answered

### Q1: Write all extraction scripts now?
**Answer: ✅ YES - Absolutely!**

**Reason:**
- Get complete picture of data requirements upfront
- Test all API endpoints and error scenarios
- Identify field mappings and transformations needed
- Deploy once with confidence instead of iterative fixes

**Action:** Write all 4 extractors (taxi, TNP, COVID, permits) with production features

---

### Q2: Finalize data model to extract only required fields?
**Answer: ✅ YES - Critical optimization!**

**Current Problem:**
- Chicago taxi API returns 40+ fields per record
- Many fields unused for your 9 BI requirements
- Extracting everything wastes storage and query costs

**Example - Taxi Trips:**

**Full API Response (40 fields):**
```json
{
  "trip_id": "abc123",
  "taxi_id": "xyz789",
  "trip_start_timestamp": "2025-10-30T08:00:00",
  "trip_end_timestamp": "2025-10-30T08:15:00",
  "trip_seconds": 900,
  "trip_miles": 3.5,
  "pickup_census_tract": "17031840100",
  "pickup_community_area": "8",
  "pickup_centroid_latitude": 41.8781,
  "pickup_centroid_longitude": -87.6298,
  "dropoff_census_tract": "17031320100",
  "dropoff_community_area": "32",
  "dropoff_centroid_latitude": 41.8589,
  "dropoff_centroid_longitude": -87.6251,
  "fare": 12.50,
  "tips": 2.50,
  "tolls": 0,
  "extras": 1.00,
  "trip_total": 16.00,
  "payment_type": "Credit Card",
  "company": "Flash Cab",
  "pickup_centroid_location": "...",
  "dropoff_centroid_location": "...",
  // + 20 more fields we don't need!
}
```

**Optimized Extraction (14 fields for your BI requirements):**
```json
{
  "trip_id": "abc123",
  "trip_start_timestamp": "2025-10-30T08:00:00",
  "trip_end_timestamp": "2025-10-30T08:15:00",
  "trip_seconds": 900,
  "trip_miles": 3.5,
  "pickup_centroid_latitude": 41.8781,
  "pickup_centroid_longitude": -87.6298,
  "dropoff_centroid_latitude": 41.8589,
  "dropoff_centroid_longitude": -87.6251,
  "fare": 12.50,
  "tips": 2.50,
  "trip_total": 16.00,
  "payment_type": "Credit Card",
  "company": "Flash Cab"
}
```

**Savings:**
- Storage: ~40% reduction (40 fields → 14 fields)
- Query cost: ~40% reduction (less data to scan)
- Network: Faster transfers
- **Monthly savings: ~$10-15**

**Action:** Map your 9 BI requirements to minimal required fields

---

### Q3: Socrata app tokens and Secret Manager?
**Answer: ✅ YES - CRITICAL for production!**

**Without App Token:**
- Rate limit: 1,000 requests/hour
- Throttled after ~17 requests/minute
- Can't extract full day of taxi data (requires ~50-100 API calls)

**With App Token:**
- Rate limit: 5,000+ requests/hour
- Can extract complete datasets
- Priority queue for API requests
- Free for academic/research use!

**How to Get Socrata App Token:**
1. Visit: https://data.cityofchicago.org/profile/app_tokens
2. Click "Create New App Token"
3. Fill out:
   - App Name: "Chicago BI Northwestern MSDSP 432"
   - Description: "Academic research project for data analytics"
   - Application URL: GitHub repo URL
4. Copy: App Token (looks like: `aBcD1234EfGh5678`)

**Store in GCP Secret Manager:**
```bash
# Create secret
echo -n "aBcD1234EfGh5678" | gcloud secrets create socrata-app-token \
    --data-file=- \
    --replication-policy="automatic"

# Grant access to service accounts
gcloud secrets add-iam-policy-binding socrata-app-token \
    --member="serviceAccount:cloud-run@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

**Use in Extractor:**
```go
// extractors/taxi/main.go
import (
    secretmanager "cloud.google.com/go/secretmanager/apiv1"
)

func getSocrataToken() string {
    client, _ := secretmanager.NewClient(context.Background())
    req := &secretmanagerpb.AccessSecretVersionRequest{
        Name: "projects/chicago-bi-app-msds-432-476520/secrets/socrata-app-token/versions/latest",
    }
    result, _ := client.AccessSecretVersion(context.Background(), req)
    return string(result.Payload.Data)
}

// Use in API call
url := "https://data.cityofchicago.org/resource/wrvz-psew.json"
req, _ := http.NewRequest("GET", url, nil)
req.Header.Add("X-App-Token", getSocrataToken())  // <-- Add token here
```

**Cost:** $0.06 per 10,000 secret accesses (~$0/month for our usage)

**Action:** Set up Socrata app token and Secret Manager TODAY

---

### Q4: 1-second delays between API calls?
**Answer: ✅ YES - Required for rate limiting!**

**Socrata Rate Limits:**
- With token: ~83 requests/minute sustained (5,000/hour)
- Best practice: 1 request per 1 second = 60 req/min (safe buffer)

**Implementation:**
```go
// extractors/taxi/main.go

type RateLimiter struct {
    lastRequestTime time.Time
    minInterval     time.Duration
}

func NewRateLimiter() *RateLimiter {
    return &RateLimiter{
        lastRequestTime: time.Now(),
        minInterval:     1 * time.Second,  // 1 second between requests
    }
}

func (rl *RateLimiter) Wait() {
    elapsed := time.Since(rl.lastRequestTime)
    if elapsed < rl.minInterval {
        sleepDuration := rl.minInterval - elapsed
        log.Printf("Rate limiting: sleeping %v", sleepDuration)
        time.Sleep(sleepDuration)
    }
    rl.lastRequestTime = time.Now()
}

// Usage in extraction loop
rateLimiter := NewRateLimiter()
for offset := 0; offset < totalRecords; offset += batchSize {
    rateLimiter.Wait()  // <-- Enforce 1-second delay

    data := fetchBatch(offset, batchSize)
    processData(data)
}
```

**Impact on Extraction Time:**
- 100 API calls × 1 second = ~2 minutes total (acceptable!)
- Prevents 429 errors and API bans
- Respectful of shared API resource

**Action:** Implement rate limiter in all extractors

---

### Q5: Exponential backoff for 429 errors?
**Answer: ✅ YES - Essential for reliability!**

**What is Exponential Backoff?**
When API returns 429 (Too Many Requests), wait progressively longer before retry:
- 1st retry: Wait 1 second
- 2nd retry: Wait 2 seconds
- 3rd retry: Wait 4 seconds
- 4th retry: Wait 8 seconds
- 5th retry: Wait 16 seconds

**Implementation:**
```go
// extractors/common/retry.go

type RetryConfig struct {
    MaxRetries     int
    InitialBackoff time.Duration
    MaxBackoff     time.Duration
    BackoffFactor  float64
}

func DefaultRetryConfig() *RetryConfig {
    return &RetryConfig{
        MaxRetries:     5,
        InitialBackoff: 1 * time.Second,
        MaxBackoff:     16 * time.Second,
        BackoffFactor:  2.0,
    }
}

func RetryWithExponentialBackoff(fn func() error, config *RetryConfig) error {
    var lastErr error
    backoff := config.InitialBackoff

    for attempt := 0; attempt <= config.MaxRetries; attempt++ {
        err := fn()

        if err == nil {
            return nil  // Success!
        }

        lastErr = err

        // Check if error is retryable (429, 500, 503)
        if !isRetryable(err) {
            return err  // Don't retry on client errors (400, 401, 403, 404)
        }

        if attempt < config.MaxRetries {
            log.Printf("Attempt %d failed: %v. Retrying in %v...",
                       attempt+1, err, backoff)
            time.Sleep(backoff)

            // Exponential backoff
            backoff = time.Duration(float64(backoff) * config.BackoffFactor)
            if backoff > config.MaxBackoff {
                backoff = config.MaxBackoff
            }
        }
    }

    return fmt.Errorf("max retries exceeded: %w", lastErr)
}

func isRetryable(err error) bool {
    // Check if HTTP status code is retryable
    if httpErr, ok := err.(*HTTPError); ok {
        return httpErr.StatusCode == 429 ||  // Too Many Requests
               httpErr.StatusCode == 500 ||  // Internal Server Error
               httpErr.StatusCode == 503 ||  // Service Unavailable
               httpErr.StatusCode == 504     // Gateway Timeout
    }
    return false
}

// Usage in extractor
err := RetryWithExponentialBackoff(func() error {
    return fetchBatchFromAPI(offset, batchSize)
}, DefaultRetryConfig())

if err != nil {
    log.Fatalf("Failed after retries: %v", err)
}
```

**Retry-After Header Support:**
```go
func RetryWithExponentialBackoff(fn func() (*http.Response, error), config *RetryConfig) error {
    // ... existing code ...

    resp, err := fn()
    if err != nil {
        // ... handle error ...
    }

    if resp.StatusCode == 429 {
        // Check for Retry-After header
        if retryAfter := resp.Header.Get("Retry-After"); retryAfter != "" {
            if seconds, err := strconv.Atoi(retryAfter); err == nil {
                waitDuration := time.Duration(seconds) * time.Second
                log.Printf("429 with Retry-After: %d seconds. Waiting...", seconds)
                time.Sleep(waitDuration)
                continue  // Retry immediately after waiting
            }
        }

        // Otherwise use exponential backoff
        time.Sleep(backoff)
    }
}
```

**Action:** Implement retry logic with exponential backoff in all extractors

---

## 🎯 Updated Week 1 Plan - Do It All NOW!

### Day 1 (Today): Infrastructure + Secrets

**1. Run Infrastructure Setup (5 min)**
```bash
./setup_gcp_infrastructure.sh
./setup_budget_shutdown.sh
```

**2. Get Socrata App Token (5 min)**
- Visit: https://data.cityofchicago.org/profile/app_tokens
- Create token: "Chicago BI Northwestern MSDSP 432"
- Copy token

**3. Store in Secret Manager (2 min)**
```bash
echo -n "YOUR_TOKEN_HERE" | gcloud secrets create socrata-app-token \
    --data-file=- \
    --replication-policy="automatic"

gcloud secrets add-iam-policy-binding socrata-app-token \
    --member="serviceAccount:cloud-run@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

---

### Day 2: Data Model + Extractors

**1. Finalize Data Model (2 hours)**

For each BI requirement, identify minimal required fields:

**BI Requirement 1: COVID-19 Testing Alerts**
- Fields needed: zip_code, week_start, cases_weekly, tests_weekly, positivity_rate, population

**BI Requirement 2: Airport Traffic Patterns**
- Fields needed: trip_start_timestamp, pickup_community_area (O'Hare/Midway), trip_count

... (map all 9 requirements)

**Output:** Document with field mappings

**2. Write Production Extractors (4 hours)**

Create all 4 extractors with:
- ✅ Socrata app token from Secret Manager
- ✅ Rate limiting (1 second between requests)
- ✅ Exponential backoff (1s → 16s)
- ✅ Retry-After header support
- ✅ Field filtering (only required fields)
- ✅ Pagination handling
- ✅ Checkpointing (resume on failure)
- ✅ Logging and metrics

---

### Day 3-4: Data Quality + Validation

**1. Quarantine Bucket (5 min)**
```bash
gsutil mb gs://chicago-bi-app-msds-432-476520-quarantine
```

**2. Manifest Table (10 min)**
```sql
CREATE TABLE landing.file_manifest (...);
```

**3. Great Expectations Setup (3 hours)**
- Install in extractors
- Define expectations for each dataset
- Implement validation workflow
- Configure alerts

---

### Day 5-6: Parquet + Deployment

**1. Dataflow Parquet Conversion (2 hours)**
- Write JSON→Parquet Dataflow job
- Deploy and test

**2. Deploy Extractors (2 hours)**
- Build containers
- Deploy to Cloud Run Jobs
- Test end-to-end

**3. Configure Cloud Scheduler (1 hour)**
- Daily 3 AM jobs
- Link to Cloud Run Jobs

---

### Day 7: Testing + Documentation

**1. End-to-End Testing (3 hours)**
- Run all extractors
- Verify validation
- Check Parquet conversion
- Validate manifest tracking

**2. Documentation (2 hours)**
- Extractor README
- API token setup guide
- Troubleshooting guide

---

## 📊 Field Mapping Exercise - Let's Do This Now!

### Your 9 BI Requirements → Required Fields

I'll help you map the minimal fields needed. For each requirement, identify:
1. Data sources needed
2. Minimal fields to extract
3. Transformations required

**Should we start with mapping BI Requirement 1 (COVID-19 Testing Alerts)?**

---

## 🛠️ Extractor Template with All Production Features

```go
// extractors/taxi/main.go - Production-ready template

package main

import (
    "context"
    "encoding/json"
    "fmt"
    "io"
    "log"
    "net/http"
    "os"
    "strconv"
    "time"

    secretmanager "cloud.google.com/go/secretmanager/apiv1"
    "cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
    "cloud.google.com/go/storage"
)

const (
    baseURL   = "https://data.cityofchicago.org/resource/wrvz-psew.json"
    batchSize = 50000  // Max records per API call
)

type TaxiTrip struct {
    // Only fields needed for BI requirements
    TripID                  string  `json:"trip_id"`
    TripStartTimestamp      string  `json:"trip_start_timestamp"`
    TripEndTimestamp        string  `json:"trip_end_timestamp"`
    TripSeconds             int     `json:"trip_seconds"`
    TripMiles               float64 `json:"trip_miles"`
    PickupCentroidLatitude  float64 `json:"pickup_centroid_latitude"`
    PickupCentroidLongitude float64 `json:"pickup_centroid_longitude"`
    DropoffCentroidLatitude  float64 `json:"dropoff_centroid_latitude"`
    DropoffCentroidLongitude float64 `json:"dropoff_centroid_longitude"`
    Fare                    float64 `json:"fare"`
    Tips                    float64 `json:"tips"`
    TripTotal               float64 `json:"trip_total"`
    PaymentType             string  `json:"payment_type"`
    Company                 string  `json:"company"`
}

type RateLimiter struct {
    lastRequestTime time.Time
    minInterval     time.Duration
}

func NewRateLimiter() *RateLimiter {
    return &RateLimiter{
        lastRequestTime: time.Now(),
        minInterval:     1 * time.Second,
    }
}

func (rl *RateLimiter) Wait() {
    elapsed := time.Since(rl.lastRequestTime)
    if elapsed < rl.minInterval {
        time.Sleep(rl.minInterval - elapsed)
    }
    rl.lastRequestTime = time.Now()
}

func getSocrataToken(ctx context.Context) (string, error) {
    client, err := secretmanager.NewClient(ctx)
    if err != nil {
        return "", err
    }
    defer client.Close()

    req := &secretmanagerpb.AccessSecretVersionRequest{
        Name: "projects/chicago-bi-app-msds-432-476520/secrets/socrata-app-token/versions/latest",
    }

    result, err := client.AccessSecretVersion(ctx, req)
    if err != nil {
        return "", err
    }

    return string(result.Payload.Data), nil
}

func fetchBatchWithRetry(url string, token string, rateLimiter *RateLimiter) ([]TaxiTrip, error) {
    maxRetries := 5
    backoff := 1 * time.Second

    for attempt := 0; attempt <= maxRetries; attempt++ {
        rateLimiter.Wait()  // Rate limiting

        req, err := http.NewRequest("GET", url, nil)
        if err != nil {
            return nil, err
        }

        req.Header.Add("X-App-Token", token)
        req.Header.Add("Accept", "application/json")

        resp, err := http.DefaultClient.Do(req)
        if err != nil {
            log.Printf("Attempt %d: Network error: %v", attempt+1, err)
            if attempt < maxRetries {
                time.Sleep(backoff)
                backoff *= 2
                continue
            }
            return nil, err
        }
        defer resp.Body.Close()

        // Handle 429 with Retry-After
        if resp.StatusCode == 429 {
            if retryAfter := resp.Header.Get("Retry-After"); retryAfter != "" {
                if seconds, err := strconv.Atoi(retryAfter); err == nil {
                    log.Printf("429 - Retry-After: %d seconds", seconds)
                    time.Sleep(time.Duration(seconds) * time.Second)
                    continue
                }
            }
            log.Printf("429 - Exponential backoff: %v", backoff)
            time.Sleep(backoff)
            backoff *= 2
            if backoff > 16*time.Second {
                backoff = 16 * time.Second
            }
            continue
        }

        // Handle other retryable errors
        if resp.StatusCode >= 500 {
            log.Printf("Attempt %d: Server error %d", attempt+1, resp.StatusCode)
            if attempt < maxRetries {
                time.Sleep(backoff)
                backoff *= 2
                continue
            }
            return nil, fmt.Errorf("server error: %d", resp.StatusCode)
        }

        // Success!
        if resp.StatusCode == 200 {
            body, err := io.ReadAll(resp.Body)
            if err != nil {
                return nil, err
            }

            var trips []TaxiTrip
            if err := json.Unmarshal(body, &trips); err != nil {
                return nil, err
            }

            return trips, nil
        }

        // Non-retryable error
        return nil, fmt.Errorf("HTTP %d: %s", resp.StatusCode, resp.Status)
    }

    return nil, fmt.Errorf("max retries exceeded")
}

func main() {
    ctx := context.Background()

    // Get Socrata token
    token, err := getSocrataToken(ctx)
    if err != nil {
        log.Fatalf("Failed to get Socrata token: %v", err)
    }

    // Initialize rate limiter
    rateLimiter := NewRateLimiter()

    // Extract data
    date := os.Getenv("START_DATE")
    query := fmt.Sprintf("%s?$where=date_trunc_ymd(trip_start_timestamp)='%s'&$limit=%d&$offset=",
                         baseURL, date, batchSize)

    offset := 0
    allTrips := []TaxiTrip{}

    for {
        url := query + strconv.Itoa(offset)
        log.Printf("Fetching offset %d...", offset)

        trips, err := fetchBatchWithRetry(url, token, rateLimiter)
        if err != nil {
            log.Fatalf("Failed to fetch batch: %v", err)
        }

        if len(trips) == 0 {
            break
        }

        allTrips = append(allTrips, trips...)
        offset += len(trips)

        log.Printf("Fetched %d trips (total: %d)", len(trips), len(allTrips))

        if len(trips) < batchSize {
            break
        }
    }

    log.Printf("✅ Extraction complete: %d trips", len(allTrips))

    // Write to GCS, create manifest entry, etc.
}
```

---

## ✅ Ready to Proceed?

**Updated Week 1 Deliverables:**
1. ✅ Infrastructure + budget monitoring
2. ✅ Socrata app token + Secret Manager
3. ✅ Data model finalized (minimal fields only)
4. ✅ All 4 extractors with production features:
   - Rate limiting (1 sec delays)
   - Exponential backoff (1s → 16s)
   - Retry-After support
   - Field filtering
5. ✅ Great Expectations validation
6. ✅ Parquet conversion
7. ✅ Manifest tracking
8. ✅ End-to-end testing

**Timeline:** 7 days (aggressive but doable!)

**Should we:**
1. Start with infrastructure setup now?
2. Then work on Socrata app token?
3. Then map BI requirements → minimal fields?
4. Then write production extractors?

**Let's do this! 🚀**
