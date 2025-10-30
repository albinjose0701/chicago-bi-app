# Great Expectations & Data Lineage - Explained Simply

**For Chicago BI App Project**

---

## What is Great Expectations?

**Simple Definition:**
Great Expectations is a **data quality testing framework** that lets you write "expectations" (rules) about what your data should look like, then automatically checks if your data meets those rules.

**Think of it like unit tests for your data instead of code.**

---

## Great Expectations in Action

### Without Great Expectations ❌

**Scenario:** Bad taxi data arrives from Chicago API

```json
{
  "trip_id": null,           // ❌ Missing trip ID
  "fare": -50.00,            // ❌ Negative fare?!
  "trip_miles": 9999999,     // ❌ Impossible distance
  "payment_type": "Bitcoin", // ❌ Invalid payment type
  "trip_start_timestamp": "invalid-date"  // ❌ Bad date format
}
```

**What happens:**
1. Bad data loads to BigQuery bronze layer
2. Transformation fails with cryptic errors
3. Dashboard shows wrong numbers
4. You spend hours debugging
5. Manual cleanup required

---

### With Great Expectations ✅

**You define rules upfront:**

```python
import great_expectations as gx

# Create expectations (rules) for taxi data
expectations = [
    # Rule 1: trip_id must never be null
    gx.expect_column_values_to_not_be_null("trip_id"),

    # Rule 2: fare must be between $0 and $1000
    gx.expect_column_values_to_be_between("fare", min_value=0, max_value=1000),

    # Rule 3: trip_miles must be between 0 and 500 miles
    gx.expect_column_values_to_be_between("trip_miles", min_value=0, max_value=500),

    # Rule 4: payment_type must be one of these
    gx.expect_column_values_to_be_in_set("payment_type",
        ["Cash", "Credit Card", "Mobile", "Prcard", "Unknown"]),

    # Rule 5: timestamps must be valid dates
    gx.expect_column_values_to_match_strftime_format("trip_start_timestamp",
        "%Y-%m-%dT%H:%M:%S"),

    # Rule 6: trip_id must be unique
    gx.expect_column_values_to_be_unique("trip_id"),

    # Rule 7: At least 100 rows per day
    gx.expect_table_row_count_to_be_between(min_value=100, max_value=1000000)
]
```

**What happens when bad data arrives:**
1. Great Expectations runs validation checks
2. Detects violations (null trip_id, negative fare, etc.)
3. **STOPS the data from loading to bronze**
4. Moves bad file to quarantine bucket
5. Sends alert: "Taxi data failed validation - 5 issues found"
6. Generates HTML report showing exactly what's wrong
7. Clean data continues to bronze layer

**Result:** Bad data never pollutes your data warehouse! 🎉

---

## Real Example for Your Project

### Taxi Data Validation Pipeline

```python
# File: extractors/validation/validate_taxi_data.py

from great_expectations.core import ExpectationSuite
from great_expectations.dataset import PandasDataset
import pandas as pd
from google.cloud import storage
import json

def validate_taxi_batch(file_uri):
    """
    Validate taxi data before loading to bronze layer.
    Returns: (is_valid, validation_report)
    """

    # 1. Download file from GCS
    storage_client = storage.Client()
    bucket_name = "chicago-bi-app-msds-432-476520-landing"
    blob = storage_client.bucket(bucket_name).blob(file_uri)
    data_json = blob.download_as_text()

    # 2. Load into pandas DataFrame
    data = [json.loads(line) for line in data_json.split('\n') if line]
    df = pd.DataFrame(data)

    # 3. Convert to Great Expectations dataset
    ge_df = PandasDataset(df)

    # 4. Run validation checks
    results = {
        "trip_id_not_null": ge_df.expect_column_values_to_not_be_null("trip_id"),
        "fare_valid_range": ge_df.expect_column_values_to_be_between("fare", 0, 1000),
        "trip_miles_valid": ge_df.expect_column_values_to_be_between("trip_miles", 0, 500),
        "coordinates_not_null": ge_df.expect_column_values_to_not_be_null("pickup_centroid_latitude"),
        "payment_type_valid": ge_df.expect_column_values_to_be_in_set("payment_type",
            ["Cash", "Credit Card", "Mobile", "Prcard", "Unknown", "No Charge", "Dispute"]),
        "unique_trip_ids": ge_df.expect_column_values_to_be_unique("trip_id"),
        "row_count_reasonable": ge_df.expect_table_row_count_to_be_between(100, 1000000)
    }

    # 5. Check if all validations passed
    all_passed = all(result.success for result in results.values())

    # 6. Generate validation report
    report = {
        "file_uri": file_uri,
        "is_valid": all_passed,
        "total_rows": len(df),
        "checks_run": len(results),
        "checks_passed": sum(1 for r in results.values() if r.success),
        "checks_failed": sum(1 for r in results.values() if not r.success),
        "failures": [
            {
                "check": name,
                "unexpected_count": result.result.get("unexpected_count", 0),
                "unexpected_percent": result.result.get("unexpected_percent", 0)
            }
            for name, result in results.items()
            if not result.success
        ]
    }

    return all_passed, report

# Usage in your pipeline
file_uri = "taxi/2025-10-30/batch_001.json"
is_valid, report = validate_taxi_batch(file_uri)

if is_valid:
    print("✅ Data passed validation - loading to bronze layer")
    load_to_bronze(file_uri)
else:
    print(f"❌ Data failed validation - moving to quarantine")
    print(f"Failures: {report['failures']}")
    move_to_quarantine(file_uri)
    send_alert(f"Taxi data validation failed: {report['checks_failed']} issues")
```

### Example Validation Report

```json
{
  "file_uri": "taxi/2025-10-30/batch_001.json",
  "is_valid": false,
  "total_rows": 15234,
  "checks_run": 7,
  "checks_passed": 5,
  "checks_failed": 2,
  "failures": [
    {
      "check": "fare_valid_range",
      "unexpected_count": 23,
      "unexpected_percent": 0.15,
      "details": "23 rows (0.15%) have fares outside range $0-$1000"
    },
    {
      "check": "trip_id_not_null",
      "unexpected_count": 5,
      "unexpected_percent": 0.03,
      "details": "5 rows (0.03%) have null trip_ids"
    }
  ]
}
```

**Action:** File moved to quarantine, email alert sent, manual review required.

---

## Benefits of Great Expectations

### 1. **Catch Errors Early** 🛡️
- Prevents bad data from entering your data warehouse
- Saves hours of debugging
- Protects dashboard accuracy

### 2. **Automated Documentation** 📚
- Auto-generates data quality reports
- HTML reports with charts and statistics
- Shows data quality trends over time

### 3. **Data Profiling** 📊
- Automatically analyzes your data
- Discovers patterns, distributions, nulls
- Suggests appropriate expectations

### 4. **Living Documentation** 📖
- Expectations serve as data contracts
- New team members understand data quality requirements
- Academic project: Shows professional data practices

### 5. **CI/CD Integration** 🔄
- Runs in your pipeline automatically
- Cloud Run, Dataflow, or Cloud Functions
- Integrates with Cloud Monitoring for alerts

---

## Cost for Your Project

| Component | Cost |
|-----------|------|
| **Software** | $0 (open source) |
| **Compute** | ~$1/month (Cloud Run validation) |
| **Storage** | ~$0.01/month (validation reports) |
| **TOTAL** | **~$1/month** |

**ROI:** Prevents data issues that could cost hours of debugging time!

---

## What is Data Lineage?

**Simple Definition:**
Data lineage is **tracking where your data comes from, how it's transformed, and where it goes** - like a family tree for your data.

**Think of it like tracking ingredients in a recipe from farm to plate.**

---

## Data Lineage in Action

### Example: Taxi Trip Data Journey

```
Source (Chicago API)
  ├─ Extraction: 2025-10-30 03:00 AM
  │  └─ Extractor: extractor-taxi v1.0
  │     └─ Output: gs://chicago-bi-landing/taxi/2025-10-30/batch_001.json
  │        ├─ Rows: 15,234
  │        ├─ Size: 8.5 MB
  │        └─ SHA256: abc123...
  │
  ├─ Validation: 2025-10-30 03:05 AM
  │  └─ Great Expectations: PASSED (7/7 checks)
  │
  ├─ Bronze Load: 2025-10-30 03:10 AM
  │  └─ Target: raw_data.raw_taxi_trips$20251030
  │     ├─ Rows loaded: 15,234
  │     └─ Load job ID: job_abc123
  │
  ├─ Silver Transformation: 2025-10-30 04:00 AM
  │  └─ Query: bronze_to_silver.sql
  │     ├─ Added zip codes (spatial join)
  │     ├─ Cleaned nulls (removed 23 rows)
  │     └─ Output: cleaned_data.cleaned_taxi_trips$20251030
  │        └─ Rows: 15,211 (23 rows filtered)
  │
  └─ Gold Aggregation: 2025-10-30 05:00 AM
     └─ Query: silver_to_gold_daily.sql
        └─ Output: analytics.agg_taxi_daily
           ├─ Aggregation: daily totals by zip code
           ├─ Input rows: 15,211
           └─ Output rows: 42 (one per zip code)
```

**Lineage Tracking:** You can answer questions like:
- "Where did this number in my dashboard come from?"
- "Which API call produced this data?"
- "When was this data last updated?"
- "How many rows were filtered out?"
- "What transformations were applied?"

---

## Manifest Table for Lineage

### The Problem Without Lineage

**Question:** "Why is yesterday's taxi data missing from the dashboard?"

**Without lineage:**
- ❓ Did the API call fail?
- ❓ Did the file upload to GCS?
- ❓ Did it load to BigQuery?
- ❓ Did validation pass?
- ❓ Which file has this data?

**Result:** Spend 2 hours checking logs, GCS, BigQuery...

---

### The Solution: Manifest Table

```sql
CREATE TABLE landing.file_manifest (
  -- File identification
  file_uri STRING NOT NULL,
  dataset STRING NOT NULL,           -- 'taxi', 'tnp', 'covid', etc.
  partition_date DATE NOT NULL,

  -- File metadata
  row_count INT64,
  size_bytes INT64,
  sha256_checksum STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),

  -- Lineage tracking
  extractor_version STRING,          -- 'extractor-taxi:v1.0'
  api_endpoint STRING,               -- 'https://data.cityofchicago.org/...'
  extraction_duration_seconds INT64,

  -- Validation
  validation_status STRING,          -- 'pending', 'passed', 'failed'
  validation_timestamp TIMESTAMP,
  validation_checks_passed INT64,
  validation_checks_failed INT64,
  validation_error_message STRING,

  -- Bronze loading
  loaded_to_bronze BOOL DEFAULT FALSE,
  bronze_table STRING,               -- 'raw_data.raw_taxi_trips'
  bronze_partition STRING,           -- '$20251030'
  bronze_loaded_at TIMESTAMP,
  bronze_load_job_id STRING,         -- BigQuery job ID
  bronze_rows_loaded INT64,

  -- Processing status
  processing_stage STRING,           -- 'landing', 'validated', 'bronze', 'quarantined'
  quarantined BOOL DEFAULT FALSE,
  quarantine_reason STRING
)
PARTITION BY partition_date
CLUSTER BY dataset, processing_stage;
```

### Example Manifest Entries

```sql
-- File 1: Successfully loaded
INSERT INTO landing.file_manifest VALUES (
  'taxi/2025-10-30/batch_001.json',
  'taxi',
  '2025-10-30',
  15234,
  8912345,
  'abc123def456...',
  '2025-10-30 03:05:00',
  'extractor-taxi:v1.0',
  'https://data.cityofchicago.org/resource/wrvz-psew.json',
  45,
  'passed',
  '2025-10-30 03:06:00',
  7,
  0,
  NULL,
  TRUE,
  'raw_data.raw_taxi_trips',
  '$20251030',
  '2025-10-30 03:10:00',
  'bqjob_abc123',
  15234,
  'bronze',
  FALSE,
  NULL
);

-- File 2: Failed validation, quarantined
INSERT INTO landing.file_manifest VALUES (
  'taxi/2025-10-31/batch_002.json',
  'taxi',
  '2025-10-31',
  12456,
  7234567,
  'def456ghi789...',
  '2025-10-31 03:05:00',
  'extractor-taxi:v1.0',
  'https://data.cityofchicago.org/resource/wrvz-psew.json',
  38,
  'failed',
  '2025-10-31 03:06:00',
  5,
  2,
  'fare_valid_range: 23 rows outside range; trip_id_not_null: 5 null values',
  FALSE,
  NULL,
  NULL,
  NULL,
  NULL,
  0,
  'quarantined',
  TRUE,
  'Validation failed: 2 checks failed'
);
```

---

## Lineage Queries You Can Run

### Query 1: Data Freshness by Dataset
```sql
-- How fresh is each dataset?
SELECT
  dataset,
  MAX(partition_date) AS latest_data_date,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(created_at), HOUR) AS hours_since_last_load,
  COUNT(*) AS total_files,
  SUM(row_count) AS total_rows
FROM landing.file_manifest
WHERE loaded_to_bronze = TRUE
GROUP BY dataset
ORDER BY hours_since_last_load;
```

**Output:**
```
dataset | latest_data_date | hours_since_last_load | total_files | total_rows
--------|------------------|----------------------|-------------|------------
taxi    | 2025-10-30       | 2                    | 45          | 687,432
covid   | 2025-10-29       | 26                   | 12          | 3,456
tnp     | 2025-10-28       | 50                   | 8           | 12,345
```

**Insight:** COVID data is 26 hours old - might need to investigate!

---

### Query 2: Validation Success Rate
```sql
-- How often does validation pass?
SELECT
  dataset,
  COUNT(*) AS total_files,
  SUM(CASE WHEN validation_status = 'passed' THEN 1 ELSE 0 END) AS passed,
  SUM(CASE WHEN validation_status = 'failed' THEN 1 ELSE 0 END) AS failed,
  ROUND(100.0 * SUM(CASE WHEN validation_status = 'passed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate_pct
FROM landing.file_manifest
WHERE partition_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY dataset;
```

**Output:**
```
dataset | total_files | passed | failed | success_rate_pct
--------|-------------|--------|--------|------------------
taxi    | 45          | 43     | 2      | 95.56
covid   | 12          | 12     | 0      | 100.00
tnp     | 8           | 7      | 1      | 87.50
```

**Insight:** TNP data has lower quality (87.5%) - needs attention.

---

### Query 3: Find Missing Data
```sql
-- Which dates are missing data?
WITH expected_dates AS (
  SELECT date
  FROM UNNEST(GENERATE_DATE_ARRAY('2025-10-01', CURRENT_DATE())) AS date
),
actual_dates AS (
  SELECT DISTINCT partition_date AS date
  FROM landing.file_manifest
  WHERE dataset = 'taxi'
    AND loaded_to_bronze = TRUE
)
SELECT e.date AS missing_date
FROM expected_dates e
LEFT JOIN actual_dates a ON e.date = a.date
WHERE a.date IS NULL
ORDER BY e.date;
```

**Output:**
```
missing_date
-------------
2025-10-15
2025-10-22
```

**Insight:** Taxi data missing for Oct 15 and Oct 22 - extraction failed?

---

### Query 4: Track a Specific File
```sql
-- Full lineage for a specific file
SELECT
  file_uri,
  dataset,
  partition_date,
  row_count,
  created_at,
  validation_status,
  validation_checks_passed,
  validation_checks_failed,
  loaded_to_bronze,
  bronze_loaded_at,
  bronze_rows_loaded,
  processing_stage,
  quarantined,
  quarantine_reason
FROM landing.file_manifest
WHERE file_uri = 'taxi/2025-10-30/batch_001.json';
```

**Output:**
```
file_uri: taxi/2025-10-30/batch_001.json
dataset: taxi
partition_date: 2025-10-30
row_count: 15234
created_at: 2025-10-30 03:05:00
validation_status: passed
validation_checks_passed: 7
validation_checks_failed: 0
loaded_to_bronze: TRUE
bronze_loaded_at: 2025-10-30 03:10:00
bronze_rows_loaded: 15234
processing_stage: bronze
quarantined: FALSE
quarantine_reason: NULL
```

**Insight:** Complete journey from API → landing → validation → bronze!

---

## Why Lineage Matters for Your Project

### 1. **Debugging** 🔍
- "Dashboard shows zero trips for Oct 30" → Check manifest → See file failed validation
- Saves hours of debugging time

### 2. **Data Quality Monitoring** 📊
- Track validation success rates over time
- Identify problematic data sources
- Show data quality metrics in your presentation

### 3. **Compliance & Auditing** 📋
- Prove data wasn't tampered with (checksums)
- Show complete data transformation history
- Academic integrity documentation

### 4. **Operational Monitoring** 🚨
- Alert when data freshness exceeds 24 hours
- Monitor extraction failure rates
- Track quarantined files needing review

### 5. **Academic Value** 🎓
- Demonstrates professional data engineering practices
- Shows understanding of data governance
- Impressive for portfolio and presentations

---

## Summary: Why Use Both?

| Feature | Great Expectations | Data Lineage |
|---------|-------------------|--------------|
| **Purpose** | **Data Quality** - Is the data correct? | **Data Tracking** - Where did the data come from? |
| **Answers** | "Does this data meet our standards?" | "What happened to this data?" |
| **When** | Before loading to bronze | Throughout entire pipeline |
| **Output** | Validation reports, pass/fail | Manifest table, full history |
| **Cost** | ~$1/month | ~$0.01/month |
| **Value** | Prevents bad data | Enables debugging and monitoring |

**Together:** Complete data quality and observability solution! 🎉

---

## Implementation for Your Project

### Week 2 Tasks:
1. Create manifest table in BigQuery
2. Update extractors to write manifest entries
3. Implement Great Expectations validation
4. Set up quarantine workflow
5. Create lineage monitoring dashboard

**Total Cost:** ~$1/month
**Time Investment:** 4-6 hours
**ROI:** Prevents data quality issues, enables fast debugging

---

**Ready to implement?** Both are highly recommended for a production-grade academic project!
