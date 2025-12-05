# Chicago Boundary Files & Spatial Enrichment

**Created:** November 6, 2025
**Purpose:** Load Chicago boundary GeoJSON files and create many-to-many spatial crosswalk tables

---

## 📁 Files

1. **01_load_boundaries.sh** - Download and load boundary GeoJSON files to BigQuery
2. **02_create_crosswalk_tables.sql** - Create many-to-many spatial relationship tables
3. **03_enrich_raw_datasets.sql** - Create enriched silver layer views with ST_WITHIN

---

## 🚀 Quick Start

### Step 1: Load Boundary Files (5 minutes)

```bash
cd /Users/albin/Desktop/chicago-bi-app/boundaries
chmod +x 01_load_boundaries.sh
./01_load_boundaries.sh
```

This creates `reference_data` dataset with:
- `community_area_boundaries` (77 areas)
- `zip_code_boundaries` (60+ ZIPs)
- `neighborhood_boundaries` (200+ neighborhoods)
- `ward_boundaries` (50 wards)
- `census_tract_boundaries` (800+ tracts)

### Step 2: Create Crosswalk Tables (10-15 minutes)

```bash
bq query --use_legacy_sql=false < 02_create_crosswalk_tables.sql
```

This creates many-to-many mapping tables:
- `crosswalk_community_zip` - Community areas ↔ ZIP codes with overlap %
- `crosswalk_community_neighborhood` - Community areas ↔ Neighborhoods
- `crosswalk_zip_neighborhood` - ZIP codes ↔ Neighborhoods
- `crosswalk_complete` - Three-way intersection (CA + ZIP + Neighborhood)

### Step 3: Create Enriched Views (5 minutes)

```bash
bq query --use_legacy_sql=false < 03_enrich_raw_datasets.sql
```

This creates `silver_data` views:
- `permits_enriched` - Permits with verified geography using ST_WITHIN
- `covid_enriched` - COVID cases distributed across community areas
- `permits_by_community_and_zip` - Aggregated permit statistics

---

## 🗺️ Understanding the Many-to-Many Relationships

### Problem: Non-Aligned Boundaries

Chicago's administrative boundaries don't align:

```
Example: ZIP Code 60614
├── Community Area 6 (Lake View) - 60% overlap
└── Community Area 7 (Lincoln Park) - 40% overlap

Example: Community Area 32 (Loop)
├── ZIP 60601 - 30% overlap
├── ZIP 60602 - 25% overlap
├── ZIP 60603 - 25% overlap
└── ZIP 60604 - 20% overlap

Example: Neighborhood "Wicker Park"
├── Community Area 24 (West Town) - 70%
└── Community Area 23 (Humboldt Park) - 30%
```

### Solution: Crosswalk Tables with Overlap Percentages

**crosswalk_community_zip:**
| community_area | zip_code | pct_of_community_area | pct_of_zip | is_primary_zip |
|----------------|----------|----------------------|------------|----------------|
| 6 (Lake View)  | 60614    | 65.2                 | 58.3       | TRUE           |
| 6 (Lake View)  | 60613    | 34.8                 | 41.7       | FALSE          |
| 7 (Lincoln Park)| 60614   | 42.1                 | 35.8       | FALSE          |

**Key Fields:**
- `pct_of_community_area` - What % of the community area falls in this ZIP?
- `pct_of_zip` - What % of the ZIP falls in this community area?
- `is_primary_zip` - Is this the main ZIP for this community area? (>50% overlap)

---

## 📊 Usage Examples

### Example 1: Enrich Permits with ST_WITHIN

```sql
-- Get verified geography for a permit using point-in-polygon
SELECT
  permit_,
  community_area as reported_community_area,
  verified_community_area,
  community_area_name_verified,
  zip_code_verified,
  neighborhood_name,
  ward_number,
  community_area_matches  -- TRUE if reported matches verified
FROM `silver_data.permits_enriched`
WHERE permit_ = '12345'
```

### Example 2: Distribute COVID Cases Across Community Areas

```sql
-- COVID data is by ZIP, distribute proportionally to community areas
SELECT
  week_start,
  community_area_name,
  SUM(estimated_cases_in_community_area) as total_cases
FROM `silver_data.covid_enriched`
WHERE is_primary_zip = TRUE  -- Use primary relationships only
GROUP BY week_start, community_area_name
ORDER BY week_start, total_cases DESC
```

### Example 3: Find All Community Areas in a ZIP

```sql
-- What community areas does ZIP 60614 overlap?
SELECT
  zip_code,
  community_area_name,
  pct_of_zip,
  pct_of_community_area,
  is_primary_zip
FROM `reference_data.crosswalk_community_zip`
WHERE zip_code = '60614'
ORDER BY pct_of_zip DESC
```

### Example 4: Find All ZIPs in a Neighborhood

```sql
-- What ZIPs does Wicker Park span?
SELECT
  neighborhood_name,
  zip_code,
  pct_of_neighborhood,
  is_primary_neighborhood
FROM `reference_data.crosswalk_zip_neighborhood`
WHERE neighborhood_name = 'Wicker Park'
ORDER BY pct_of_neighborhood DESC
```

### Example 5: Complex Three-Way Join

```sql
-- Permits aggregated by all three geographies
SELECT
  year,
  community_area_name,
  zip_code_verified,
  neighborhood_name,
  COUNT(*) as permit_count,
  SUM(total_fee) as total_fees
FROM `silver_data.permits_enriched`
WHERE year = 2024
GROUP BY year, community_area_name, zip_code_verified, neighborhood_name
ORDER BY permit_count DESC
```

---

## 🔍 Data Quality Checks

### Check 1: Verify Boundaries Loaded

```sql
SELECT
  'community_area_boundaries' as table_name,
  COUNT(*) as record_count
FROM `reference_data.community_area_boundaries`
UNION ALL
SELECT 'zip_code_boundaries', COUNT(*)
FROM `reference_data.zip_code_boundaries`
UNION ALL
SELECT 'neighborhood_boundaries', COUNT(*)
FROM `reference_data.neighborhood_boundaries`
```

**Expected:**
- Community areas: 77
- ZIP codes: 60+
- Neighborhoods: 200+

### Check 2: Verify Crosswalk Coverage

```sql
-- How many community areas have multiple ZIPs?
SELECT COUNT(*) as community_areas_with_multiple_zips
FROM (
  SELECT community_area_number
  FROM `reference_data.crosswalk_community_zip`
  GROUP BY community_area_number
  HAVING COUNT(DISTINCT zip_code) > 1
)
```

### Check 3: Check Point Match Rate

```sql
-- Do reported community areas match verified ones?
SELECT
  'Match Rate' as metric,
  ROUND(
    COUNTIF(community_area_matches = TRUE) / COUNT(*) * 100,
    2
  ) as percentage
FROM `silver_data.permits_enriched`
WHERE issue_date >= '2020-01-01'
```

**Expected:** 95%+ match rate (some permits have incorrect reported community areas)

---

## 💡 Best Practices

### 1. Use Primary Relationships When Possible

```sql
-- Filter to primary relationships to avoid double-counting
WHERE is_primary_zip = TRUE
```

### 2. Distribute Metrics Proportionally

```sql
-- When aggregating from ZIP to community area, use overlap %
SUM(metric * pct_of_zip / 100) as distributed_metric
```

### 3. Cache Crosswalk Joins

The crosswalk tables are small (<10K rows each). Consider materializing joined views:

```sql
CREATE TABLE `silver_data.permits_enriched_materialized` AS
SELECT * FROM `silver_data.permits_enriched`;
```

### 4. Use ST_WITHIN for Point Data

For datasets with lat/lon (permits, taxis), always use ST_WITHIN:

```sql
WHERE ST_WITHIN(
  ST_GEOGPOINT(longitude, latitude),
  boundary_geometry
)
```

### 5. Use Crosswalks for Aggregate Data

For datasets already aggregated by geography (COVID by ZIP), use crosswalk tables:

```sql
JOIN `reference_data.crosswalk_community_zip`
  ON covid.zip_code = crosswalk.zip_code
```

---

## 🎯 Performance Tips

1. **Partition enriched tables** by date for faster queries
2. **Cluster by geography** (community_area, zip_code, neighborhood)
3. **Use views for development**, materialize for production
4. **Filter by bounding box** before ST_WITHIN to reduce computation
5. **Sample large datasets** when testing geography joins

---

## 📚 References

### Chicago Data Portal
- Community Areas: https://data.cityofchicago.org/Facilities-Geographic-Boundaries/Boundaries-Community-Areas-current-/cauq-8yn6
- ZIP Codes: https://data.cityofchicago.org/Facilities-Geographic-Boundaries/Boundaries-ZIP-Codes/unjd-c2ca
- Neighborhoods: https://data.cityofchicago.org/Facilities-Geographic-Boundaries/Boundaries-Neighborhoods/igws-duph

### BigQuery Geography
- ST_WITHIN: https://cloud.google.com/bigquery/docs/reference/standard-sql/geography_functions#st_within
- ST_INTERSECTS: https://cloud.google.com/bigquery/docs/reference/standard-sql/geography_functions#st_intersects
- ST_AREA: https://cloud.google.com/bigquery/docs/reference/standard-sql/geography_functions#st_area

---

**Last Updated:** November 6, 2025
**Status:** Production Ready ✅
