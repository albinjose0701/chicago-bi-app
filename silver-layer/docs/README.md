# Silver Layer - Enriched Analytics Tables

The Silver layer contains clean, enriched, analytics-ready tables with spatial joins, business logic, and derived fields applied on top of the Bronze layer.

## 📊 Overview

**Dataset:** `chicago-bi-app-msds-432-476520.silver_data`
**Location:** us-central1
**Purpose:** Clean, enriched data ready for analytics and visualization

## 🗂️ Tables

### 1. silver_trips_enriched
**Source:** bronze_taxi_trips + bronze_tnp_trips
**Rows:** ~168M (combined taxi + TNP)
**Partitioning:** trip_date
**Clustering:** source_dataset, pickup_community_area, dropoff_community_area

**Description:** Combined taxi and TNP (rideshare) trips with spatial enrichment for zip codes and neighborhoods.

**Key Fields:**
- `trip_id` - Unique trip identifier
- `trip_date` - Extracted trip date
- `trip_hour` - Extracted hour (0-23)
- `trip_start_timestamp`, `trip_end_timestamp` - Trip timestamps
- `trip_seconds`, `trip_miles`, `fare` - Trip metrics
- `pickup_community_area`, `dropoff_community_area` - Original community areas
- `pickup_centroid_latitude`, `pickup_centroid_longitude` - Pickup coordinates
- `dropoff_centroid_latitude`, `dropoff_centroid_longitude` - Dropoff coordinates
- `pickup_zip`, `dropoff_zip` - **Enriched via spatial join**
- `pickup_neighborhood`, `dropoff_neighborhood` - **Enriched via spatial join**
- `shared_trip_authorized` - Shared trip flag (FALSE for all taxi trips)
- `trips_pooled` - Number of pooled trips (1 for all taxi trips)
- `is_airport_trip` - Flag for O'Hare (60666) or Midway (60018) trips
- `source_dataset` - 'taxi' or 'tnp' for lineage tracking
- `enriched_at` - Timestamp of enrichment

**Spatial Joins:**
- Pickup/dropoff ZIP codes via `ST_CONTAINS(zip.geography, ST_GEOGPOINT(lon, lat))`
- Pickup/dropoff neighborhoods via `ST_CONTAINS(neighborhood.geography, ST_GEOGPOINT(lon, lat))`

**Usage Example:**
```sql
-- Count airport trips by source
SELECT
  source_dataset,
  COUNT(*) as total_trips,
  COUNTIF(is_airport_trip) as airport_trips,
  ROUND(COUNTIF(is_airport_trip) / COUNT(*) * 100, 2) as airport_pct
FROM silver_data.silver_trips_enriched
GROUP BY source_dataset;
```

---

### 2. silver_permits_enriched
**Source:** bronze_building_permits
**Rows:** ~208K
**Partitioning:** issue_date
**Clustering:** community_area, permit_type

**Description:** Building permits with spatial enrichment for zip codes and neighborhoods.

**Key Fields:**
- `id` - Unique permit identifier
- `permit_` - Permit number
- `permit_status`, `permit_type` - Permit classification
- `application_start_date`, `issue_date` - Key dates
- `processing_time` - Days to process
- `work_type` - Type of work
- `total_fee`, `reported_cost` - Financial metrics
- `community_area` - Community area number
- `latitude`, `longitude` - Coordinates
- `zip_code` - **Enriched via spatial join**
- `neighborhood` - **Enriched via spatial join**
- `permit_year`, `permit_month` - Derived date fields
- `enriched_at` - Timestamp of enrichment

**Usage Example:**
```sql
-- Permits by neighborhood
SELECT
  neighborhood,
  COUNT(*) as permit_count,
  ROUND(AVG(total_fee), 2) as avg_fee,
  ROUND(AVG(processing_time), 0) as avg_processing_days
FROM silver_data.silver_permits_enriched
WHERE permit_year = 2024
GROUP BY neighborhood
ORDER BY permit_count DESC
LIMIT 10;
```

---

### 3. silver_covid_latest
**Source:** bronze_covid_cases
**Rows:** ~60 (one per ZIP code, latest week only)
**No partitioning** (small table)

**Description:** Most recent week of COVID-19 data by ZIP code with risk categorization.

**Key Fields:**
- `zip_code` - ZIP code
- `latest_week_end` - Most recent week end date
- `cases_weekly` - Cases in latest week
- `case_rate_weekly` - Case rate per 100,000 population
- `tests_weekly`, `deaths_weekly` - Testing and mortality metrics
- `population` - ZIP code population
- `risk_category` - **Derived:** 'High' (≥400), 'Medium' (≥200), 'Low' (<200) based on case rate
- `created_at` - Timestamp of creation

**Risk Category Logic:**
```sql
CASE
  WHEN case_rate_weekly >= 400 THEN 'High'
  WHEN case_rate_weekly >= 200 THEN 'Medium'
  ELSE 'Low'
END
```

**Usage Example:**
```sql
-- Risk distribution
SELECT
  risk_category,
  COUNT(*) as zip_count,
  ROUND(AVG(case_rate_weekly), 2) as avg_case_rate,
  SUM(population) as total_population
FROM silver_data.silver_covid_latest
GROUP BY risk_category
ORDER BY
  CASE risk_category
    WHEN 'High' THEN 1
    WHEN 'Medium' THEN 2
    ELSE 3
  END;
```

---

### 4. silver_ccvi_high_risk
**Source:** bronze_ccvi
**Rows:** ~50 (high risk areas only)
**No partitioning** (small table)

**Description:** Chicago COVID Vulnerability Index (CCVI) - High risk areas only.

**Key Fields:**
- `geography_type` - 'CA' (Community Area) or 'ZIP'
- `geography_id` - Community area number or ZIP code
- `ccvi_score` - CCVI vulnerability score (0-1 scale)
- `ccvi_category` - 'HIGH' (filtered for high risk only)
- `created_at` - Timestamp of creation

**Filter Applied:**
```sql
WHERE ccvi_category = 'HIGH'
```

**Usage Example:**
```sql
-- High risk areas by type
SELECT
  geography_type,
  COUNT(*) as high_risk_count,
  ROUND(AVG(ccvi_score), 3) as avg_score
FROM silver_data.silver_ccvi_high_risk
GROUP BY geography_type;
```

---

## 🚀 Execution

### Create All Tables
```bash
cd ~/Desktop/chicago-bi-app/silver-layer
./scripts/00_create_all_silver_tables.sh
```

### Create Individual Tables
```bash
# Dataset creation
bq query --use_legacy_sql=false < 01_create_silver_dataset.sql

# Trips (WARNING: Takes 10-20 minutes!)
bq query --use_legacy_sql=false < 02_silver_trips_enriched.sql

# Permits
bq query --use_legacy_sql=false < 03_silver_permits_enriched.sql

# COVID
bq query --use_legacy_sql=false < 04_silver_covid_latest.sql

# CCVI
bq query --use_legacy_sql=false < 05_silver_ccvi_high_risk.sql
```

### List Tables
```bash
bq ls --project_id=chicago-bi-app-msds-432-476520 silver_data
```

---

## 🔗 Data Lineage

### bronze_data → silver_data

```
Bronze Layer                           Silver Layer
├── bronze_taxi_trips (25.3M)     ┐
│                                  ├──→ silver_trips_enriched (~168M)
├── bronze_tnp_trips (142.5M)     ┘
│
├── bronze_building_permits (208K) ───→ silver_permits_enriched (~208K)
│
├── bronze_covid_cases (13K)       ───→ silver_covid_latest (~60)
│
├── bronze_ccvi (135)              ───→ silver_ccvi_high_risk (~50)
│
└── bronze_public_health (77)      ───→ (Used for joins, not transformed)
```

### Reference Data (used for enrichment)
```
reference_data.boundaries_zip_codes ──────→ pickup_zip, dropoff_zip, zip_code
reference_data.boundaries_neighborhoods ──→ pickup_neighborhood, dropoff_neighborhood, neighborhood
```

---

## 📐 Spatial Join Pattern

All spatial joins use BigQuery Geography functions:

```sql
-- Create point from coordinates
ST_GEOGPOINT(longitude, latitude)

-- Spatial containment join
LEFT JOIN reference_data.boundaries_zip_codes z
  ON ST_CONTAINS(z.geography, ST_GEOGPOINT(lon, lat))
```

**Performance Note:** Spatial joins on large tables (168M trips) can take 10-20 minutes. Tables are partitioned and clustered to optimize query performance.

---

## 🎯 Key Transformations

### 1. Derived Fields
- `trip_date` = `DATE(trip_start_timestamp)`
- `trip_hour` = `EXTRACT(HOUR FROM trip_start_timestamp)`
- `permit_year` = `EXTRACT(YEAR FROM issue_date)`
- `permit_month` = `EXTRACT(MONTH FROM issue_date)`

### 2. Business Logic
- **Airport trips:** Pickup or dropoff in ZIP 60666 (O'Hare) or 60018 (Midway)
- **COVID risk:** High (≥400 case rate), Medium (≥200), Low (<200)
- **CCVI filter:** Only HIGH category areas included

### 3. Data Lineage
- `source_dataset` = 'taxi' or 'tnp' (tracks origin)
- `enriched_at` = `CURRENT_TIMESTAMP()` (audit trail)

### 4. Taxi Trip Defaults
- `shared_trip_authorized` = FALSE (all taxi trips)
- `trips_pooled` = 1 (all taxi trips)

---

## 📊 Data Quality Metrics

| Table | Expected Rows | Enrichment Rate |
|-------|---------------|-----------------|
| silver_trips_enriched | ~168M | 95%+ ZIP/neighborhood match |
| silver_permits_enriched | ~208K | 98%+ ZIP/neighborhood match |
| silver_covid_latest | ~60 | 100% (one per ZIP) |
| silver_ccvi_high_risk | ~50 | 100% (filtered HIGH only) |

---

## 🔍 Verification Queries

### Check All Tables
```sql
SELECT
  table_name,
  FORMAT('%,d', row_count) as rows,
  FORMAT('%.2f GB', size_bytes / 1e9) as size_gb
FROM `chicago-bi-app-msds-432-476520.silver_data.__TABLES__`
ORDER BY table_name;
```

### Trips Enrichment Rate
```sql
SELECT
  source_dataset,
  COUNT(*) as total,
  COUNTIF(pickup_zip IS NOT NULL) as pickup_zip_enriched,
  ROUND(COUNTIF(pickup_zip IS NOT NULL) / COUNT(*) * 100, 2) as pickup_zip_pct,
  COUNTIF(dropoff_zip IS NOT NULL) as dropoff_zip_enriched,
  ROUND(COUNTIF(dropoff_zip IS NOT NULL) / COUNT(*) * 100, 2) as dropoff_zip_pct
FROM silver_data.silver_trips_enriched
GROUP BY source_dataset;
```

### COVID Risk Distribution
```sql
SELECT
  risk_category,
  COUNT(*) as zip_count,
  ROUND(AVG(case_rate_weekly), 2) as avg_case_rate
FROM silver_data.silver_covid_latest
GROUP BY risk_category
ORDER BY CASE risk_category WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END;
```

---

## 🛠️ Maintenance

### Refresh Silver Tables
Silver tables are static snapshots. To refresh:

```bash
# Drop and recreate (WARNING: Data loss!)
bq rm -f -t silver_data.silver_trips_enriched
bq query --use_legacy_sql=false < 02_silver_trips_enriched.sql
```

### Incremental Updates
For production, consider:
1. **Incremental trips:** Only enrich new dates
2. **COVID updates:** Weekly refresh of latest data
3. **Permits updates:** Daily refresh of new permits

---

## 📝 Notes

1. **Spatial Join Performance:** The trips table spatial join processes 168M records and may take 10-20 minutes
2. **Airport Codes:** O'Hare = 60666, Midway = 60018 (per STTM specification)
3. **Bronze Tables Used:** All silver tables use `bronze_data.*` tables, not `raw_data.*`
4. **CREATE IF NOT EXISTS:** All scripts are safe to re-run (won't drop existing data)
5. **Location Consistency:** All tables in us-central1 region for optimal performance

---

## 🔜 Next Steps

After Silver layer creation:
1. **Gold Layer:** Create aggregated views (monthly/yearly rollups)
2. **Dashboards:** Connect Looker/Tableau to silver tables
3. **Incremental Loading:** Implement daily/weekly updates
4. **Data Quality Monitoring:** Track enrichment rates and anomalies

---

**Last Updated:** November 2025
**Version:** Silver Layer v1.0
**Status:** Production Ready
