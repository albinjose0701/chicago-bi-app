# Chicago BI App - Architecture Gap Analysis
**Production Strategy vs Current Implementation**

---

## Executive Summary

**Overall Alignment:** 7/10
- ✅ **Strong Matches:** BigQuery medallion, Cloud Operations, no Cloud SQL
- ⚠️ **Medium Gaps:** File format, validation layer, manifest tracking
- 🔴 **Critical Gaps:** Data quality framework, retention policies, BI Engine cost

**Recommendation:** Adopt production strategy with phased implementation (Week 1-4)

---

## Detailed Comparison

### 1. Data Format: JSON vs Parquet

| Aspect | Current Plan | Production Strategy | Gap Severity | Recommendation |
|--------|--------------|-------------------|--------------|----------------|
| **Extractor Output** | JSON (newline-delimited) | Parquet columnar | 🟡 Medium | Phase in Parquet |
| **Rationale** | Simple Go code | 10x compression, faster queries | | |
| **Storage Cost** | ~$4.60/month (200GB JSON) | ~$0.50/month (20GB Parquet) | | **$4/month savings** |
| **Query Cost** | $5/TB scanned | $0.50/TB (10x less data) | | **90% query savings** |

**Impact Analysis:**
- JSON 200GB taxi data → BigQuery scans 200GB per full table scan = $1/scan
- Parquet 20GB taxi data → BigQuery scans 20GB per full table scan = $0.10/scan
- **10 queries/day × 30 days = $30/month saved with Parquet**

**Action Items:**
1. ✅ Week 1: Keep JSON extractors (faster to deploy)
2. ⏳ Week 2: Add Dataflow JSON→Parquet conversion job
3. ⏳ Week 3: Update extractors to emit Parquet natively (optional)

**Cost:** Dataflow job ~$2/month (100GB/month conversion) - **Net savings: $28/month**

---

### 2. Validation Layer & Quarantine

| Aspect | Current Plan | Production Strategy | Gap Severity |
|--------|--------------|-------------------|--------------|
| **Pre-Bronze Validation** | ❌ None | ✅ Automated checks + quarantine | 🔴 Critical |
| **Quality Gates** | ❌ None | ✅ Row count, schema, nulls | 🔴 Critical |
| **Failed Data Handling** | ❌ Fails silently | ✅ Quarantine bucket + alerts | 🔴 Critical |

**Current Risk:**
- Bad data loads directly to bronze → corrupts silver/gold
- No visibility into data quality issues
- Manual cleanup required for bad data

**Production Strategy:**
```
Landing → Validation → {Pass: Bronze, Fail: Quarantine}
                    ↓
              Cloud Monitoring Alert
```

**Action Items:**
1. Create `gs://chicago-bi-app-msds-432-476520-quarantine/` bucket
2. Implement validation checks:
   - Row count matches manifest (±1% tolerance)
   - Schema conformance (required fields present)
   - Non-null checks (trip_id, timestamps, coordinates)
   - Data range checks (fare > 0, trip_miles > 0)
3. Failed files → quarantine + Cloud Monitoring alert
4. Quarantine retention: 30 days for manual review

**Cost:** $0 (validation runs in BigQuery, quarantine storage minimal)

---

### 3. Manifest Tracking

| Aspect | Current Plan | Production Strategy | Gap Severity |
|--------|--------------|-------------------|--------------|
| **File Tracking** | ❌ None | ✅ BigQuery manifest table | 🟡 Medium |
| **Lineage** | ❌ Unknown | ✅ Full data lineage | 🟡 Medium |
| **Checksums** | ❌ None | ✅ SHA256 verification | 🟡 Medium |

**Production Strategy Manifest Table:**
```sql
CREATE TABLE landing.file_manifest (
  file_uri STRING NOT NULL,
  dataset STRING NOT NULL,
  partition_date DATE NOT NULL,
  row_count INT64,
  size_bytes INT64,
  sha256_checksum STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  loaded_to_bronze BOOL DEFAULT FALSE,
  bronze_loaded_at TIMESTAMP,
  validation_status STRING  -- 'pending', 'passed', 'failed'
)
PARTITION BY partition_date
CLUSTER BY dataset, validation_status;
```

**Benefits:**
- Track which files loaded to bronze
- Detect duplicate loads
- Audit data lineage
- Monitor data freshness per dataset

**Action Items:**
1. Create `landing.file_manifest` table (Week 2)
2. Extractors write manifest entry after GCS upload
3. Bronze load job updates `loaded_to_bronze = TRUE`
4. Query manifest for data lineage reports

**Cost:** ~$0.01/month (manifest table < 1GB)

---

### 4. Lifecycle Policies

| Aspect | Current Plan | Production Strategy | Gap Severity |
|--------|--------------|-------------------|--------------|
| **Landing** | 30d → Nearline, 90d → Delete | 7d → Delete after bronze | 🟡 Medium |
| **Bronze** | 30d partition expiration | 90d live → Coldline 7yr | 🟡 Medium |
| **Silver** | No policy | 180d live → archive to GCS | 🟡 Medium |
| **Gold** | Permanent | Permanent (with annual review) | ✅ Match |

**Updated Lifecycle Policies:**
```bash
# Landing bucket
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 7}  # Changed from 90
    }
  ]
}

# Bronze BigQuery partitions
CREATE TABLE raw_data.raw_taxi_trips (...)
PARTITION BY DATE(trip_start_timestamp)
OPTIONS(
  partition_expiration_days = 90  # Changed from 30
);

# Bronze to Coldline archive (manual export after 90d)
bq extract --destination_format=PARQUET \
  'raw_data.raw_taxi_trips$20251001' \
  'gs://chicago-bi-archive/bronze/2025/10/01/*.parquet'
```

**7-Year Retention Requirement:**
- Academic project doesn't require 7-year retention
- If needed for compliance: GCS Archive class costs $0.0012/GB/month
- 200GB × $0.0012 × 84 months = **$20 total for 7 years**

**Action Items:**
1. Update landing lifecycle to 7 days (Week 1)
2. Update bronze partition expiration to 90 days (Week 2)
3. Document silver archival process (Week 3)

**Cost Impact:** Saves ~$3/month (faster deletion of landing data)

---

### 5. Geospatial Strategy

| Aspect | Current Plan | Production Strategy | Gap Severity |
|--------|--------------|-------------------|--------------|
| **Primary Method** | ✅ BigQuery Geography | ✅ BigQuery Geography | ✅ Perfect match |
| **Fallback** | ✅ GeoPandas (local) | ⚠️ Dataflow + PostGIS | 🟢 Minor |
| **Cloud SQL PostGIS** | ❌ Removed | ❌ Not needed | ✅ Match |

**Our Decision:** ✅ Correct - BigQuery Geography handles our use cases
- Point-in-polygon (taxi → zip code): `ST_CONTAINS()`
- Distance calculations: `ST_DISTANCE()`
- Geospatial joins: Native BigQuery

**No changes needed** - our approach aligns with production strategy.

---

### 6. BI Engine

| Aspect | Current Plan | Production Strategy | Gap Severity |
|--------|--------------|-------------------|--------------|
| **BI Engine** | ❌ Not budgeted | ✅ 1GB reservation | 🟡 Medium |
| **Cost** | $0 | ₹2,500/month (~$30/month) | | |
| **Query Performance** | 5-10 seconds | <1 second | | |

**BI Engine Recommendation:**
- Caches frequently queried data in-memory
- Sub-second dashboard refresh
- Reduces query costs (cached queries don't scan data)

**Cost-Benefit:**
- **Cost:** $30/month
- **Savings:** ~$15/month (reduced query scans)
- **Net cost:** $15/month
- **New monthly total:** $28.84 + $15 = **$43.84/month**
- **Credits duration:** $310 ÷ $43.84 = **7 months** (down from 10.7)

**Recommendation:** ❌ **Skip BI Engine** for academic project
- Not worth reducing credits duration 7 months
- Acceptable performance without it (<5s queries)
- Can enable later if needed

**Alternative:** Use BigQuery materialized views (free) for caching common queries

---

### 7. Cloud Operations Suite

| Aspect | Current Plan | Production Strategy | Gap Severity |
|--------|--------------|-------------------|--------------|
| **Cloud Monitoring** | ✅ Planned | ✅ Required | ✅ Match |
| **Cloud Logging** | ✅ Planned | ✅ Required | ✅ Match |
| **Error Reporting** | ✅ Planned | ✅ Required | ✅ Match |
| **Cloud Trace** | ❌ Not planned | ✅ Recommended | 🟢 Minor |
| **Cost** | $0-4/month | $0-4/month | ✅ Match |

**Perfect alignment** - our budget monitoring script uses Cloud Operations.

**Action Items:**
1. ✅ Already enabled in setup script
2. Configure custom dashboards (Week 2)
3. Set up alerts for pipeline failures (Week 2)

---

### 8. Data Quality Framework: Great Expectations

| Aspect | Current Plan | Production Strategy | Recommendation |
|--------|--------------|-------------------|----------------|
| **Data Quality** | ❌ None | ⚠️ Not mentioned | 🟡 Consider |
| **Framework** | N/A | Great Expectations? | **YES** ✅ |

**What is Great Expectations?**
- Python library for data validation, profiling, and documentation
- Define "expectations" (assertions) about your data
- Automatically generates data quality reports
- Integrates with BigQuery, Dataflow, Airflow

**Use Cases for Chicago BI:**
1. **Schema validation**: Ensure incoming data matches expected schema
2. **Value range checks**: `expect_column_values_to_be_between(column="fare", min_value=0, max_value=1000)`
3. **Null checks**: `expect_column_values_to_not_be_null(column="trip_id")`
4. **Uniqueness**: `expect_column_values_to_be_unique(column="trip_id")`
5. **Data profiling**: Auto-generate data quality reports

**Example:**
```python
import great_expectations as gx

# Define expectations
expectations = [
    gx.expect_column_values_to_not_be_null("trip_id"),
    gx.expect_column_values_to_be_between("fare", 0, 1000),
    gx.expect_column_values_to_match_regex("payment_type", r"^(Cash|Credit Card|Mobile)$"),
    gx.expect_table_row_count_to_be_between(min_value=1000, max_value=100000)
]

# Validate data
results = context.run_checkpoint(
    checkpoint_name="taxi_validation",
    batch_request={"datasource_name": "bigquery"}
)

# If validation fails → quarantine data
if not results.success:
    quarantine_file(file_uri)
    send_alert("Data quality check failed")
```

**Benefits:**
- Catches data quality issues before bronze load
- Generates data quality documentation automatically
- Integrates with Cloud Monitoring for alerts
- Open source and free

**Cost:**
- Software: $0 (open source)
- Compute: ~$1/month (runs in Cloud Run or Dataflow)
- **Total: ~$1/month**

**Recommendation:** ✅ **YES, adopt Great Expectations**
- Aligns with production validation strategy
- Minimal cost ($1/month)
- Academic project benefit: Shows enterprise data quality practices

**Action Items:**
1. Install Great Expectations in extractors (Week 2)
2. Define expectations for each dataset (Week 2)
3. Integrate with validation-before-bronze workflow (Week 2)
4. Generate data quality reports for documentation (Week 3)

---

## Updated Architecture with Production Best Practices

```
┌─────────────────────────────────────────────────────────────┐
│         DATA SOURCES (Chicago Data Portal - SODA API)       │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│       EXTRACTION LAYER (Cloud Run Jobs - Go 1.21)           │
│  • Extractors write JSON to GCS landing                     │
│  • Create manifest entry in landing.file_manifest           │
│  • Generate SHA256 checksum                                 │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│      LANDING ZONE (Cloud Storage - Standard 7 days)         │
│  gs://chicago-bi-landing/                                   │
│    ├── taxi/2025-10-30/batch_*.json                         │
│    ├── tnp/2025-10-30/batch_*.json                          │
│    └── covid/2025-10-30/batch_*.json                        │
│                                                              │
│  Manifest Table: landing.file_manifest (BigQuery)           │
│    - file_uri, row_count, sha256, partition_date            │
│    - Queryable for lineage and freshness tracking           │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│           VALIDATION LAYER (Great Expectations)             │
│  • Schema conformance checks                                │
│  • Row count verification (±1%)                             │
│  • Non-null validation (trip_id, timestamps)                │
│  • Value range checks (fare > 0, trip_miles > 0)            │
│  • Uniqueness checks (trip_id unique)                       │
│                                                              │
│  Pass → Bronze    |    Fail → Quarantine                    │
└──────┬────────────┴───────────┬──────────────────────────────┘
       │                        │
       ▼                        ▼
┌────────────────────┐  ┌────────────────────────────────────┐
│   BRONZE LAYER     │  │   QUARANTINE BUCKET                │
│   (BigQuery)       │  │   gs://chicago-bi-quarantine/      │
│   90d retention    │  │   30d retention + alerts           │
└────────┬───────────┘  └────────────────────────────────────┘
         │
         ▼ [Optional: Dataflow JSON → Parquet conversion]
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│         SILVER LAYER (BigQuery - 180d retention)            │
│  • Cleaned and validated data                               │
│  • Geospatial enrichment (BigQuery Geography)               │
│  • Zip code joins, distance calculations                    │
│  • Export to GCS Parquet quarterly for archival             │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│         GOLD LAYER (BigQuery - Permanent)                   │
│  • Pre-aggregated analytics tables                          │
│  • Materialized views (free caching)                        │
│  • Partitioned and clustered for BI                         │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              VISUALIZATION (Looker Studio)                  │
│  • Direct connection to BigQuery gold                       │
│  • 12-hour cache refresh                                    │
│  • 8 interactive dashboards                                 │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│           MONITORING (Cloud Operations Suite)               │
│  • Cloud Monitoring: Pipeline success, data freshness       │
│  • Cloud Logging: Centralized logs                          │
│  • Error Reporting: Automatic error detection               │
│  • Budget Alerts: 5%, 10%, 20%, 30%, 40%, 50%, 80%         │
│  • Auto-shutdown at 80% budget                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Updated Cost Estimate

| Component | Original Plan | Production Strategy | Change |
|-----------|---------------|-------------------|--------|
| BigQuery Storage | $2.07/month | $0.50/month | -$1.57 (Parquet) |
| BigQuery Queries | $18.75/month | $5/month | -$13.75 (10x less scan) |
| Cloud Storage | $4.60/month | $1/month | -$3.60 (faster deletion) |
| Dataflow (JSON→Parquet) | $0 | $2/month | +$2 |
| Great Expectations | $0 | $1/month | +$1 |
| Cloud Run | $1.62/month | $1.62/month | $0 |
| Cloud Scheduler | $0.30/month | $0.30/month | $0 |
| Cloud Build | $1.50/month | $1.50/month | $0 |
| Cloud Operations | $0-4/month | $0-4/month | $0 |
| **TOTAL** | **$28.84-33/month** | **$12.92-17/month** | **-$15.92/month (55% savings!)** |

**Updated Credits Duration:**
- Original: $310 ÷ $28.84 = 10.7 months
- Production: $310 ÷ $12.92 = **24 months!** (2 years!)

---

## Implementation Roadmap

### Week 1: Foundation (Current)
- ✅ GCP infrastructure setup
- ✅ Budget monitoring + auto-shutdown
- ⏳ Deploy JSON extractors (simpler, faster)
- ⏳ Create landing bucket with 7-day lifecycle

### Week 2: Validation & Quality
- Create quarantine bucket
- Implement Great Expectations validation
- Create `landing.file_manifest` table
- Set up validation-before-bronze workflow
- Configure Cloud Monitoring alerts

### Week 3: Optimization
- Deploy Dataflow JSON→Parquet job
- Update bronze partition expiration to 90 days
- Implement silver archival workflow
- Create materialized views for gold layer

### Week 4: Production Readiness
- Comprehensive testing
- Data quality documentation
- Performance tuning
- Presentation preparation

---

## Recommendations Summary

### ✅ Adopt from Production Strategy
1. **Parquet format** - 55% cost savings ($15.92/month)
2. **Validation layer** - Critical for data quality
3. **Quarantine workflow** - Prevents bad data propagation
4. **Manifest tracking** - Enables data lineage
5. **Updated lifecycle policies** - Faster deletion, lower costs
6. **Great Expectations** - Enterprise data quality practices

### ❌ Skip from Production Strategy
1. **BI Engine** - Not worth 3-month credit reduction
2. **7-year retention** - Not required for academic project
3. **Cloud SQL PostGIS** - BigQuery Geography sufficient

### 🎯 Final Architecture Score
**9.5/10** - Production-ready with optimizations

**Alignment:**
- Core medallion: ✅ Perfect match
- Geospatial: ✅ Perfect match
- Monitoring: ✅ Perfect match
- Data quality: ✅ Enhanced with Great Expectations
- Cost optimization: ✅ 55% savings vs original

---

## Next Steps

**Ready to implement production strategy?**
1. Run infrastructure setup scripts (5 minutes)
2. Add validation layer components (Week 2)
3. Deploy with production best practices

**Estimated final cost:** $12.92-17/month = **24 months** on $310 credits! 🎉
