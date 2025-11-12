# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.14.0] - 2025-11-13 ✅ CURRENT

### Added - Gold Layer with Analytics Aggregations 🎉

**Status:** ✅ **PRODUCTION READY**

#### Gold Tables Created (7 tables, 52M+ records)

1. **gold_taxi_hourly_by_zip** (35.4M rows)
   - Hourly trip aggregations by pickup/dropoff ZIP pairs
   - Metrics: trip_count, avg_miles, avg_fare
   - Partitioned by trip_date, clustered by pickup_zip/dropoff_zip/trip_hour
   - Use case: Peak hour demand analysis, time-of-day pricing

2. **gold_taxi_daily_by_zip** (4M rows)
   - Daily trip aggregations by pickup/dropoff ZIP pairs
   - Use case: Daily trends, seasonal patterns

3. **gold_route_pairs** (10 rows)
   - Top 10 most popular routes with revenue analysis
   - Use case: Route optimization, high-value corridor identification

4. **gold_permits_roi** (59 rows)
   - Building permits aggregated by ZIP (192,435 total permits)
   - Metrics: total_permits, total_permit_value, avg_permit_value
   - Use case: Construction activity hotspots, investment patterns

5. **gold_covid_hotspots** (13,132 rows) ⭐ COMPLEX
   - COVID risk scoring with mobility + epidemiological + CCVI vulnerability
   - Coverage: 60 ZIPs × 219 weeks (March 2020 - May 2024)
   - Risk formulas: Mobility Risk + Epi Risk × CCVI Adjustment
   - Partitioned by week_start, clustered by zip_code/risk_category
   - Use case: Pandemic impact analysis, mobility-COVID correlation

6. **gold_loan_targets** (60 rows) ⭐ COMPLEX
   - Illinois Small Business Emergency Loan Fund Delta eligibility targeting
   - 35 eligible ZIPs (per_capita_income < $30,000)
   - 4-component eligibility index with weighted income calculation
   - Use case: Small business loan targeting, economic development

7. **gold_forecasts** (1,650 rows)
   - Prophet-ready forecasting structure (55 ZIPs × 30 days)
   - Sample data with confidence intervals (placeholder for ML model)
   - Use case: Demand forecasting, capacity planning

#### Key Achievements
- ✅ 52M+ aggregated records from 168M silver records
- ✅ Complex risk scoring (3-factor COVID model)
- ✅ Loan eligibility with weighted income via spatial crosswalk
- ✅ Time series COVID tracking (219 weeks, 3 pandemic waves)
- ✅ Partitioned/clustered for 95%+ query scan reduction
- ✅ 3-minute total execution time for all tables

#### Performance
- **Total Execution Time:** ~3 minutes
- **Data Scanned:** ~20 GB
- **Estimated Cost:** $0.10 per full refresh
- **Query Optimization:** 95%+ scan reduction (partitioning) + 10-100x improvement (clustering)

#### Files Created
- 9 SQL scripts (1 dataset, 7 table creation, 1 master script)
- Comprehensive README (70+ pages)
- Session context documentation (100+ pages)

---

## [2.13.0] - 2025-11-12

### Added - Silver Layer with Spatial Enrichment 🎉

**Status:** ✅ **PRODUCTION READY**

#### Silver Tables Created (4 tables, 168M+ records)

1. **silver_trips_enriched** (167.8M rows)
   - Spatial enrichment via BigQuery Geography ST_CONTAINS
   - 100% ZIP match, 99.99% neighborhood match
   - Airport trips identified: 14.2M (19.9% taxi, 6.4% TNP)
   - 8-minute spatial join on 168M records with 4 joins per record

2. **silver_permits_enriched** (207,984 rows)
   - Spatial enrichment: 99.2-99.6% match rates
   - Derived fields: permit_year, permit_month

3. **silver_covid_weekly_historical** (13,132 rows)
   - Full time series: All 219 weeks (March 2020 - May 2024)
   - Risk categorization (High/Medium/Low)
   - Pandemic waves: Omicron peak Dec 2021 (1,872 cases/100K)

4. **silver_ccvi_high_risk** (39 rows)
   - High vulnerability areas only (CCVI score > 40)
   - 26 Community Areas + 13 ZIP codes

#### Key Achievements
- ✅ 168M+ records spatially enriched
- ✅ 100% ZIP match, 99.99% neighborhood match
- ✅ 14.2M airport trips identified
- ✅ 8-minute spatial join performance
- ✅ BigQuery Geography instead of Cloud SQL (cost savings)

---

## [2.12.0] - 2025-11-08

### Added - Bronze Layer with Quality Filters 🎉

**Status:** ✅ **PRODUCTION READY**

#### Bronze Tables Created (6 tables, 168M records)

1. **bronze_taxi_trips** (25.3M rows)
   - 21.6% filtered for quality
   - Geographic bounds validation

2. **bronze_tnp_trips** (142.5M rows)
   - 16.2% filtered for quality

3. **bronze_covid_cases** (13,132 rows) - 100% retained
4. **bronze_building_permits** (207,984 rows) - 1.8% filtered
5. **bronze_ccvi** (135 rows) - 100% retained
6. **bronze_public_health** (77 rows) - 100% retained

#### Key Achievements
- ✅ 168M clean records from 202.5M raw
- ✅ 17% data quality improvement (34.5M filtered)
- ✅ Geographic bounds validation (Chicago: 41.6-42.1°N, -87.95 to -87.5°W)
- ✅ Smart optimization (90% faster - 59 sec vs 5-10 min)

---

## [2.11.0] - 2025-11-06

### Added - Boundary Files, Crosswalks & Reference Data 🎉

**Status:** ✅ **PRODUCTION READY**

#### Reference Tables Created (7 tables)

1. **Boundary Files** (3 tables)
   - zip_code_boundaries (59 ZIPs)
   - neighborhood_boundaries (98 neighborhoods)
   - community_area_boundaries (77 areas)

2. **Spatial Crosswalks** (4 tables)
   - crosswalk_zip_neighborhood
   - crosswalk_zip_community
   - crosswalk_neighborhood_community
   - crosswalk_community_zip (with overlap percentages)

3. **Static Datasets** (2 tables)
   - bronze_ccvi (135 rows)
   - bronze_public_health (77 rows)

#### Key Achievements
- ✅ 7 reference tables created
- ✅ 272+ spatial relationships mapped
- ✅ Fixed location mismatch (all tables now us-central1)
- ✅ Many-to-many relationships (72% CAs span multiple ZIPs)

---

## [2.10.0] - 2025-11-06

### Added - Architecture Planning for Silver Layer

**Status:** ✅ **PLANNING COMPLETE**

#### Key Decisions
- Use BigQuery Geography instead of Cloud SQL PostGIS
- Create many-to-many spatial crosswalk tables
- Two-stage data quality (critical in extractor, documentation in SQL)
- Static data loading via `bq load` for <100 record datasets

#### Files Created
- 11 SQL scripts (4 boundary, 5 silver layer, 2 documentation)
- Architecture decision documentation

---

## [2.9.0] - 2025-11-05/06

### Added - Permits & COVID Backfill Execution 🎉

**Status:** ✅ **COMPLETE**

#### Backfill Results
- **COVID-19:** 13,132 records (100% coverage)
  - 219 weeks × 60 ZIP codes
  - 819K cases, 8.4K deaths

- **Building Permits:** 211,894 permits (99.7% coverage)
  - 2,130/2,136 dates (6 missing are weekends/holidays)
  - $225M total fees
  - 98.2% with coordinates

#### Key Achievements
- ✅ Multi-hour execution without interruptions
- ✅ Network resilience proven
- ✅ 100% data integrity verified
- 🐛 Discovered grep bug (cosmetic, data OK)

---

## [2.8.0] - 2025-11-05

### Added - Building Permits & COVID-19 Extractors 🎉

**Status:** ✅ **PRODUCTION READY**

#### New Extractors Created (2)

1. **Building Permits Extractor**
   - Dataset: ydr8-5enu
   - Fields: 64 fields
   - BigQuery table: raw_building_permits

2. **COVID-19 Cases Extractor**
   - Dataset: yhhz-zm2v
   - Fields: 20 fields
   - BigQuery table: raw_covid_cases

#### Key Achievements
- ✅ 2 new extractors (1,261 lines Go code)
- ✅ 2 BigQuery tables with partitioning/clustering
- ✅ Both tested and validated
- ✅ Ready for historical backfill

---

## [2.7.0] - 2025-11-05

### Added - Full 2024 + Partial 2025 Complete 🎉

**Status:** ✅ **PRODUCTION READY**

#### Backfill Results
- **Dates:** 640 (2024 + 2025 through Oct 1)
- **Trips:** 11.6M (90% above estimate)
- **Execution:** 2h 49m (7-way parallel)

#### Key Achievements
- ✅ 5+ years taxi data complete (2020-2025)
- ✅ 32.3M total taxi trips
- ✅ 25x performance improvement (2s delays)

---

## [2.6.0] - 2025-11-05

### Added - 2023 Complete + 2024 Schema Discovery 🎉

**Status:** ✅ **PRODUCTION READY**

#### Backfill Results
- **Year 2023:** 365 dates, 6.5M trips
- **Execution:** 3 hours (4-way parallel, 2s delays)

#### Discovery
- **2024+ Dataset:** Separate API endpoint (ajtu-isnz)
- **Updated Code:** v2.3.0 with dynamic dataset selection

#### Key Achievements
- ✅ 4 years taxi data (2020-2023, 20.7M trips)
- ✅ 13x performance improvement
- ✅ Code ready for 2024-2025

---

## [2.5.0] - 2025-11-05

### Added - Full 2022 Dataset Complete 🎉

**Status:** ✅ **PRODUCTION READY**

#### Backfill Results
- **Dates:** 365 (full year)
- **Trips:** 75.5M (6.38M taxi, 69.1M TNP)
- **Execution:** 7h 31m (4-way parallel)

#### Key Achievements
- ✅ Three complete years (2020+2021+2022)
- ✅ 185M total trips
- ✅ 75% time savings via parallelization
- ✅ Created session-contexts folder

---

## [2.4.0] - 2025-11-04/05

### Added - Full 2021 Dataset Complete 🎉

**Status:** ✅ **PRODUCTION READY**

#### Backfill Results
- **Dates:** 365 (full year)
- **Trips:** 55.5M (3.95M taxi, 51.5M TNP)
- **Execution:** 7h 42m (4-way parallel)

#### Key Achievements
- ✅ Two complete years (2020+2021)
- ✅ 109.5M total trips
- ✅ 6x performance improvement (30s → 5s delays)
- ✅ 74% time savings

---

## [2.3.0] - 2025-11-04

### Added - Full 2020 Dataset Complete 🎉

**Status:** ✅ **PRODUCTION READY**

#### Backfill Results
- **Dates:** 366 (full year, leap year)
- **Trips:** 54M (3.89M taxi, 50.1M TNP)
- **Execution:** Optimized (10s delays, parallel Q3+Q4)

#### Key Achievements
- ✅ Complete 2020 dataset
- ✅ Network resilience tested (2 switches + power outage)
- ✅ 3x faster execution (30s → 10s delays)
- ✅ COVID-19 impact captured (Q1→Q4 trends)

---

## [2.2.0] - 2025-11-02

### Added - Q1 2020 Backfill Complete 🎉

**Status:** ✅ **PRODUCTION READY**

#### Backfill Results
- **Dates:** 91/91 for both datasets
- **Trips:** 25.9M total
- **Quality:** 90%+ geographic coverage

#### Fixed
- Bash array indexing bug (Bash 3.2 compatibility)
- Network-resilient backfill scripts

#### Key Achievements
- ✅ First complete quarter
- ✅ Full data quality validation
- ✅ Production-ready for analytics

---

## [2.1.0] - 2025-11-01

### Fixed - Critical Performance and Reliability Issues

#### 🔥 **BREAKING BUG FIXES** - Extractors Were Not Working Properly

**Problem:** v2.0.0 extractors had fundamental issues causing data extraction failures:
- Only 2 dates loaded for taxi trips
- Only 1 date loaded for TNP with 0 rows
- Expected: 90 dates per dataset (180 total)
- Root cause: **Missing BigQuery loading, no pagination, no concurrency**

#### Extractor Improvements

**Fixed Critical Issues:**
1. ✅ **Added BigQuery Loading** - Data now automatically loads from GCS to BigQuery
   - Added `loadToBigQuery()` function using BigQuery Go SDK
   - Added `verifyBigQueryData()` function to confirm successful loading
   - Extractors now complete full pipeline: API → GCS → BigQuery

2. ✅ **Implemented Pagination** - Now handles datasets with >50k records/day
   - Added `$offset` parameter to API queries
   - Handles unlimited record volumes (previously capped at 50k)
   - TNP dataset (100k-150k records/day) now fully extracted

3. ✅ **Implemented Concurrency** - 6x faster extraction
   - Added goroutines for parallel API requests
   - Semaphore pattern limits concurrent requests to 5
   - Previous: 30-60s per date, Now: 5-10s per date
   - For 180 dates: 90 minutes → 15-30 minutes

4. ✅ **Added Retry Logic** - Automatic recovery from transient failures
   - 3 retry attempts with exponential backoff
   - 5-second delay between retries
   - Handles network timeouts and API rate limits

5. ✅ **Enhanced Logging** - Better visibility and debugging
   - Structured logging with emoji indicators
   - Batch progress tracking
   - Row count verification
   - Execution time metrics

**Files Modified:**
- `extractors/taxi/main.go` - Complete rewrite with all fixes
- `extractors/tnp/main.go` - Complete rewrite with all fixes
- `extractors/taxi/go.mod` - Added `cloud.google.com/go/bigquery v1.57.1`
- `extractors/tnp/go.mod` - Added `cloud.google.com/go/bigquery v1.57.1`

#### Backfill Script Improvements

**Fixed Issues:**
1. ✅ **Added Data Verification** - Confirms data actually loaded to BigQuery
   - `verify_bigquery_data()` function queries row counts
   - Fails if 0 rows detected
   - Reports actual row counts in logs

2. ✅ **Added Retry Logic** - Automatic retry on failures
   - 2 retry attempts with 60-second delay
   - Handles both Cloud Run and BigQuery failures

3. ✅ **Enhanced Error Handling** - Better failure detection
   - Checks Cloud Run exit codes
   - Validates BigQuery data after each extraction
   - Detailed error messages with context

4. ✅ **Improved Pre-Flight Checks** - Validates infrastructure before starting
   - Checks for `bq` CLI installation
   - Verifies Cloud Run jobs exist
   - Verifies BigQuery tables exist
   - Sets correct GCP project

5. ✅ **Better Progress Tracking** - Total rows loaded
   - Tracks row counts across all dates
   - Summary includes total rows loaded
   - Log file includes per-date row counts

**Files Modified:**
- `backfill/quarterly_backfill_q1_2020.sh` - Major update with verification

### Performance Impact

**Before v2.1.0:**
- Concurrency: None (single-threaded)
- Pagination: Missing (50k limit)
- BigQuery Loading: Manual/missing
- Time per Date: 30-60 seconds
- Total Time (180 dates): 90-180 minutes
- Reliability: Low (only 3/180 dates worked)
- Data Completeness: Partial (missing >50k records)

**After v2.1.0:**
- Concurrency: 5 parallel requests
- Pagination: Automatic (unlimited records)
- BigQuery Loading: Automatic with verification
- Time per Date: 5-10 seconds
- Total Time (180 dates): 15-30 minutes
- Reliability: High (error handling + retry)
- Data Completeness: 100% (all records extracted)

**Performance Gain:** 6x faster + actually works!

### Technical Details

**New Functions Added:**
```go
// Both extractors (taxi & tnp)
extractAllDataConcurrent()  // Concurrent pagination with goroutines
buildQueryWithOffset()      // API query with offset parameter
extractBatchWithRetry()     // Retry logic for API requests
loadToBigQuery()           // Load GCS data to BigQuery
verifyBigQueryData()       // Verify data loaded successfully
```

**New Bash Functions:**
```bash
# Backfill script
verify_bigquery_data()          # Query BigQuery for row counts
run_extraction_with_retry()     # Retry wrapper for extractions
```

**Dependencies Added:**
- `cloud.google.com/go/bigquery v1.57.1` - BigQuery Go SDK
- `google.golang.org/api/iterator` - Result iteration

### Migration Guide

**Upgrading from 2.0.0 to 2.1.0:**

⚠️ **IMPORTANT:** If you already ran backfills with v2.0.0, you likely have incomplete data.

**Action Required:**

1. **Redeploy Extractors with Fixed Code:**
   ```bash
   # Rebuild and redeploy taxi extractor
   cd extractors/taxi
   docker build --platform linux/amd64 -t gcr.io/chicago-bi-app-msds-432-476520/extractor-taxi:v2.1.0 .
   docker push gcr.io/chicago-bi-app-msds-432-476520/extractor-taxi:v2.1.0
   gcloud run jobs update extractor-taxi --image gcr.io/chicago-bi-app-msds-432-476520/extractor-taxi:v2.1.0 --region us-central1

   # Rebuild and redeploy TNP extractor
   cd ../tnp
   docker build --platform linux/amd64 -t gcr.io/chicago-bi-app-msds-432-476520/extractor-tnp:v2.1.0 .
   docker push gcr.io/chicago-bi-app-msds-432-476520/extractor-tnp:v2.1.0
   gcloud run jobs update extractor-tnp --image gcr.io/chicago-bi-app-msds-432-476520/extractor-tnp:v2.1.0 --region us-central1
   ```

2. **Clear Incomplete Data (Optional but Recommended):**
   ```bash
   # Delete incomplete data from BigQuery
   bq query --use_legacy_sql=false "DELETE FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
   bq query --use_legacy_sql=false "DELETE FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_tnp_trips\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
   ```

3. **Re-run Backfill with Fixed Script:**
   ```bash
   cd backfill
   chmod +x quarterly_backfill_q1_2020.sh
   ./quarterly_backfill_q1_2020.sh all
   ```

4. **Verify Complete Data:**
   ```bash
   # Check row counts per date
   bq query --use_legacy_sql=false "SELECT DATE(trip_start_timestamp) AS date, COUNT(*) as trips FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31' GROUP BY date ORDER BY date"

   # Check total rows
   bq query --use_legacy_sql=false "SELECT COUNT(*) as total_trips, COUNT(DISTINCT DATE(trip_start_timestamp)) as partitions FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips\` WHERE DATE(trip_start_timestamp) BETWEEN '2020-01-01' AND '2020-03-31'"
   ```

**Expected Results:**
- Taxi: ~3-5 million trips, 90 partitions
- TNP: ~10-15 million trips, 90 partitions
- No dates with 0 rows
- All dates from 2020-01-01 to 2020-03-31 present

---

## [2.0.0] - 2025-10-31

### Added - TNP Trips Support

#### Extractors
- **NEW:** TNP trips extractor for rideshare data (m6dm-c72p)
  - `extractors/tnp/main.go` - Full extractor with authentication
  - `extractors/tnp/deploy_with_auth.sh` - Deployment automation
  - `extractors/tnp/test_single_date.sh` - Testing script
  - `extractors/tnp/Dockerfile`, `go.mod`, `go.sum` - Build dependencies

#### BigQuery Schemas
- **NEW:** `raw_tnp_trips` table for rideshare trip data
  - Added to `bigquery/schemas/bronze_layer.sql`
  - Schema includes rideshare-specific fields: `shared_trip_authorized`, `trips_pooled`
  - Partitioned by `trip_start_timestamp`, clustered by location
- **NEW:** `bigquery/schemas/deploy_schemas.sh` - Automated schema deployment

#### Documentation
- **NEW:** `DEPLOYMENT_GUIDE.md` v2.0.0 - Complete deployment guide for both datasets
- **NEW:** `CHANGELOG.md` - This file
- **NEW:** `VERSIONS.md` - Documentation versioning standards
- **NEW:** `DOC_INDEX.md` - Documentation index with versions

### Changed

#### Schemas
- Updated `bronze_layer.sql` table numbering:
  - Table 2: raw_tnp_trips (NEW)
  - Table 3: raw_tnp_permits (was Table 2)
  - Table 4: raw_covid_cases (was Table 3)
  - Table 5: raw_building_permits (was Table 4)

#### Documentation
- Updated `START_HERE.md` references to include TNP dataset
- Added version headers to all major documentation files

### Technical Details

**Datasets Supported:**
- Taxi Trips: `wrvz-psew` (Traditional taxis)
- TNP Trips: `m6dm-c72p` (Rideshare - Uber/Lyft)

**Schema Differences:**
```
Taxi-specific:  taxi_id, company, payment_type, tips (plural), tolls, extras
TNP-specific:   tip (singular), additional_charges, shared_trip_authorized, trips_pooled
Common fields:  trip_id, timestamps, miles, fare, trip_total, location data
```

**Backfill Support:**
- `quarterly_backfill_q1_2020.sh` already supported both datasets
- No changes needed - processes 180 daily extractions (90 taxi + 90 TNP)

---

## [1.0.0] - 2025-10-30

### Added - Initial Project Setup

#### Infrastructure
- GCP project setup: `chicago-bi-app-msds-432-476520`
- Cloud Storage buckets for landing zone
- BigQuery datasets: `raw_data`, `cleaned_data`, `analytics`, `reference`, `monitoring`
- Secret Manager for Socrata API credentials
- IAM service accounts and permissions

#### Extractors
- Taxi trips extractor (wrvz-psew)
  - `extractors/taxi/main.go` - Core extractor with authentication
  - `extractors/taxi/deploy_with_auth.sh` - Deployment script
  - `extractors/taxi/test_single_date.sh` - Testing utilities
  - Dockerfile and Go module configuration

#### BigQuery Schemas
- `bigquery/schemas/bronze_layer.sql` - Initial schema
  - raw_taxi_trips table
  - raw_tnp_permits table (driver permits, not trips)
  - raw_covid_cases table
  - raw_building_permits table

#### Backfill Scripts
- `backfill/quarterly_backfill_q1_2020.sh` - Q1 2020 historical backfill
- `backfill/monthly_backfill.sh` - Monthly backfill utility

#### Documentation
- `README.md` v1.0.0 - Project overview and architecture
- `START_HERE.md` v1.0.0 - Quick start guide
- `SETUP_SUMMARY.md` v1.0.0 - Infrastructure setup summary
- `QUICKSTART_CLOUD_BACKFILL.md` v1.0.0 - Cloud backfill guide
- `DEPLOY_AUTHENTICATED_EXTRACTOR.md` v1.0.0 - Extractor deployment
- `ARCHITECTURE_GAP_ANALYSIS.md` v1.0.0 - Architecture decisions
- `UPDATED_WEEK1_PLAN.md` v1.0.0 - Week 1 implementation plan
- `FINAL_IMPLEMENTATION_PLAN.md` v1.0.0 - Complete implementation plan

#### Infrastructure Scripts
- `setup_gcp_infrastructure.sh` - Complete GCP setup
- `setup_budget_shutdown.sh` - Budget controls and auto-shutdown

#### Geospatial
- GeoPandas scripts for boundary processing
- Local PostGIS setup for reference maps

---

## Version History Summary

| Version | Date | Type | Description |
|---------|------|------|-------------|
| **2.1.0** | 2025-11-01 | Minor | Fixed critical bugs: BigQuery loading, pagination, concurrency |
| **2.0.0** | 2025-10-31 | Major | Added TNP trips support (m6dm-c72p) |
| **1.0.0** | 2025-10-30 | Major | Initial project setup with taxi trips |

---

## Upcoming Changes (Planned)

### [2.2.0] - TBD
- Data quality checks for TNP trips
- Silver layer transformations for both datasets
- Duplicate detection and handling

### [3.0.0] - TBD
- Gold layer analytics tables
- Comparative analytics (taxi vs TNP)
- Q1 2020 baseline metrics
- Real-time incremental extraction
- Cloud Scheduler automation
- Monitoring and alerting
- Looker Studio dashboards

---

## Migration Guide

### Upgrading from 1.0.0 to 2.0.0

**Breaking Changes:**
- None - This is additive only

**New Features:**
- TNP trips extractor available
- New BigQuery table: `raw_tnp_trips`

**Action Required:**
1. Deploy new BigQuery schema:
   ```bash
   cd bigquery/schemas
   ./deploy_schemas.sh
   ```

2. Deploy TNP extractor:
   ```bash
   cd extractors/tnp
   ./deploy_with_auth.sh
   ```

3. Run backfill for TNP data:
   ```bash
   cd backfill
   ./quarterly_backfill_q1_2020.sh tnp
   # OR for both: ./quarterly_backfill_q1_2020.sh all
   ```

**Compatibility:**
- All v1.0.0 extractors continue to work unchanged
- Existing taxi data is unaffected
- Can run TNP independently or alongside taxi

---

## Contributors

**Northwestern MSDS 432 - Group 2:**
- Albin Anto Jose
- Myetchae Thu
- Ansh Gupta
- Bickramjit Basu

**Course:** MSDSP 432 - Foundations of Data Engineering
**Institution:** Northwestern University
**Instructor:** Dr. Abid Ali

---

## Notes

- This project uses **Semantic Versioning** (MAJOR.MINOR.PATCH)
- MAJOR: Breaking changes or significant new features
- MINOR: New features, backward compatible
- PATCH: Bug fixes, backward compatible
- All dates in ISO 8601 format (YYYY-MM-DD)
- See `VERSIONS.md` for versioning standards and guidelines
