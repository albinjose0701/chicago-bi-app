# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
| **2.0.0** | 2025-10-31 | Major | Added TNP trips support (m6dm-c72p) |
| **1.0.0** | 2025-10-30 | Major | Initial project setup with taxi trips |

---

## Upcoming Changes (Planned)

### [2.1.0] - TBD
- BigQuery load jobs integration (GCS → BigQuery automation)
- Data quality checks for TNP trips
- Silver layer transformations for both datasets

### [2.2.0] - TBD
- Gold layer analytics tables
- Comparative analytics (taxi vs TNP)
- Q1 2020 baseline metrics

### [3.0.0] - TBD
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
