# Bronze Layer Tables

The Bronze layer contains cleaned raw data with quality filters applied. This layer sits between the Raw layer (raw_data dataset) and the Silver layer (silver_data dataset).

## Overview

**Dataset:** `bronze_data`
**Location:** `us-central1`
**Purpose:** Clean, filter, and standardize raw data for downstream analytics

## Data Quality Filters

### Taxi & TNP Trips
- ✅ All 4 coordinates (pickup/dropoff lat/lon) must be non-null
- ✅ `trip_miles` ≤ 500 miles
- ✅ `trip_seconds` ≤ 100,000 seconds (~27.8 hours)
- ✅ `fare` ≤ $1,000
- ✅ All values must be ≥ 0

### Building Permits
- ✅ Both `latitude` AND `longitude` must be non-null
- ✅ Coordinates must be within Chicago bounds (41.6-42.1°N, -87.95 to -87.5°W)

### COVID-19 Cases
- ✅ `zip_code`, `week_start`, `week_end`, `row_id` must be non-null
- ℹ️ No additional quality filters applied

### CCVI (Vulnerability Index)
- ✅ `geography_type`, `community_area_or_zip`, `ccvi_score` must be non-null
- ℹ️ No additional quality filters applied

### Public Health Statistics
- ✅ `per_capita_income` must be non-null
- ✅ `community_area` must be non-null

## Tables

### 1. bronze_taxi_trips
**Source:** `raw_data.raw_taxi_trips`
**Partitioning:** `trip_start_timestamp` (DATE)
**Clustering:** `pickup_community_area`, `dropoff_community_area`

**Schema:**
- `trip_id` - STRING (Primary key)
- `trip_start_timestamp` - TIMESTAMP
- `trip_end_timestamp` - TIMESTAMP
- `trip_seconds` - INTEGER
- `trip_miles` - FLOAT (rounded to 2 decimals)
- `pickup_community_area` - INTEGER (converted from STRING)
- `dropoff_community_area` - INTEGER (converted from STRING)
- `fare` - FLOAT (rounded to 2 decimals)
- `shared_trip_authorized` - BOOLEAN (NULL for taxi trips)
- `trips_pooled` - INTEGER (0 for taxi trips)
- `pickup_centroid_latitude` - FLOAT (rounded to 6 decimals)
- `pickup_centroid_longitude` - FLOAT (rounded to 6 decimals)
- `dropoff_centroid_latitude` - FLOAT (rounded to 6 decimals)
- `dropoff_centroid_longitude` - FLOAT (rounded to 6 decimals)
- `extracted_at` - TIMESTAMP

**Expected Records:** ~32.3M (from raw: 32.3M)

---

### 2. bronze_tnp_trips
**Source:** `raw_data.raw_tnp_trips`
**Partitioning:** `trip_start_timestamp` (DATE)
**Clustering:** `pickup_community_area`, `dropoff_community_area`

**Schema:** Same as `bronze_taxi_trips` but includes actual values for:
- `shared_trip_authorized` - BOOLEAN (TRUE/FALSE)
- `trips_pooled` - INTEGER (number of trips)

**Expected Records:** ~170M (from raw: 170M)

---

### 3. bronze_covid_cases
**Source:** `raw_data.raw_covid19_cases_by_zip`
**Partitioning:** `week_start` (DATE)
**Clustering:** `zip_code`

**Schema:**
- `zip_code` - STRING
- `week_number` - INTEGER
- `week_start` - DATE (converted from TIMESTAMP)
- `week_end` - DATE (converted from TIMESTAMP)
- `cases_weekly` - INTEGER
- `tests_weekly` - INTEGER
- `deaths_weekly` - INTEGER
- `population` - INTEGER
- `case_rate_weekly` - FLOAT (rounded to 2 decimals)
- `row_id` - STRING
- `extracted_at` - TIMESTAMP

**Note:** `zip_code_location` (GEOGRAPHY) field not available in raw data. Can be added later by joining with `reference_data.zip_code_boundaries`.

**Expected Records:** ~13,132 (from raw: 13,132)

---

### 4. bronze_building_permits
**Source:** `raw_data.raw_building_permits`
**Partitioning:** `issue_date` (DATE)
**Clustering:** `community_area`

**Schema:**
- `id` - STRING (Primary key)
- `permit_` - STRING (Permit number)
- `permit_status` - STRING
- `permit_type` - STRING
- `application_start_date` - DATE (converted from TIMESTAMP)
- `issue_date` - DATE (converted from TIMESTAMP)
- `processing_time` - INTEGER
- `street_number` - INTEGER
- `street_direction` - STRING
- `street_name` - STRING
- `work_type` - STRING
- `work_description` - STRING
- `permit_condition` - STRING
- `total_fee` - FLOAT (rounded to 2 decimals)
- `reported_cost` - FLOAT (rounded to 2 decimals)
- `pin_list` - STRING
- `community_area` - INTEGER
- `latitude` - FLOAT (rounded to 6 decimals)
- `longitude` - FLOAT (rounded to 6 decimals)
- `extracted_at` - TIMESTAMP

**Expected Records:** ~208K (from raw: 211,894 with ~98% having valid coords)

---

### 5. bronze_ccvi
**Source:** `raw_data.raw_ccvi`

**Schema:**
- `geography_type` - STRING ("CA" or "ZIP")
- `community_area_or_zip` - STRING
- `ccvi_score` - FLOAT (rounded to 3 decimals, 0-1 scale)
- `ccvi_category` - STRING ("LOW", "MEDIUM", "HIGH")
- `location` - STRING (WKT format: "POINT (lon lat)")
- `extracted_at` - TIMESTAMP

**Note:** `location` is stored as STRING in WKT format, not GEOGRAPHY type. Can be converted using `ST_GEOGFROMTEXT()` in Silver layer.

**Expected Records:** 135 (77 Community Areas + 58 ZIP Codes)

---

### 6. bronze_public_health
**Source:** `raw_data.raw_public_health_stats`

**Schema:**
- `community_area` - INTEGER (Primary key)
- `community_area_name` - STRING
- `per_capita_income` - INTEGER
- `extracted_at` - TIMESTAMP

**Note:** This table only includes the minimal required fields. Additional health indicators are available in the raw table and can be added to Silver layer as needed.

**Expected Records:** 77 (one per Community Area)

---

## Execution

### Create All Tables
```bash
# From project root
cd bronze-layer
./scripts/00_create_all_bronze_tables.sh
```

### Create Individual Tables
```bash
# Example: Create only taxi trips bronze table
bq query --use_legacy_sql=false --project_id=chicago-bi-app-msds-432-476520 < sql/02_bronze_taxi_trips.sql
```

## Data Volume Summary

| Table | Expected Records | Size Estimate |
|-------|-----------------|---------------|
| bronze_taxi_trips | ~32.3M | ~3-4 GB |
| bronze_tnp_trips | ~170M | ~15-20 GB |
| bronze_covid_cases | ~13,132 | <1 MB |
| bronze_building_permits | ~208K | ~50 MB |
| bronze_ccvi | 135 | <1 KB |
| bronze_public_health | 77 | <1 KB |
| **TOTAL** | **~202.5M** | **~18-24 GB** |

## Verification Queries

Each SQL script includes verification queries that run automatically. To manually verify:

```sql
-- Check all bronze tables exist
SELECT table_name, row_count, size_bytes
FROM `chicago-bi-app-msds-432-476520.bronze_data.__TABLES__`;

-- Get row counts
SELECT 'bronze_taxi_trips' as table_name, COUNT(*) as rows
FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_taxi_trips`
UNION ALL
SELECT 'bronze_tnp_trips', COUNT(*)
FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_tnp_trips`
-- ... etc
```

## Next Steps

After creating Bronze tables:
1. **Silver Layer:** Apply business logic transformations (already scripted in `/silver-layer`)
2. **Enrichment:** Add geography joins using `reference_data` tables
3. **Gold Layer:** Create aggregated analytics tables
4. **Dashboards:** Build visualizations on Gold layer

## Schema Mapping Notes

### Field Name Standardization
- Raw table field names with spaces are converted to snake_case
- Example: `"Geography Type"` → `geography_type`
- Example: `"CCVI Score"` → `ccvi_score`

### Type Conversions
- STRING community areas → INTEGER (e.g., "6" → 6)
- TIMESTAMP dates → DATE where appropriate
- FLOAT values rounded for consistency

### Missing Fields
- Taxi trips don't have `shared_trip_authorized` or `trips_pooled` in raw data → set to NULL/0
- COVID data doesn't have geography POINT field → can be added via spatial join

---

**Created:** November 7, 2025
**Status:** Ready for execution
**Next Version:** Silver layer enrichment with business logic
