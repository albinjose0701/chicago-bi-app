# Chicago Neighborhoods - Geometry Validation Report

**Date:** October 30, 2025
**Analyst:** Claude Code
**File Analyzed:** `Neighborhoods_2012b_20251030.geojson`

---

## Executive Summary

✅ **ALL 98 neighborhoods in the Neighborhoods file have VALID, COMPLETE geometries.**

❌ **NO geometries are missing from the Neighborhoods file.**

⚠️ **Same as Community Areas: The issue is CSV format limitations, NOT missing data.**

---

## Detailed Findings

### Neighborhoods File Analysis

**File:** `/Users/albin/Downloads/Geographical Reference Files/Neighborhoods_2012b_20251030.geojson`

**Total Neighborhoods:** 98 (Chicago 2012b official neighborhood boundaries)

**Geometry Status:** ✅ ALL VALID

### Sample Neighborhoods with Geometry Data

| Index | Primary Neighborhood | Secondary Neighborhood | Geometry Type | Polygons | Points | Status |
|-------|---------------------|------------------------|---------------|----------|--------|--------|
| 0 | Grand Boulevard | BRONZEVILLE | MultiPolygon | 1 | 328 | ✅ Valid |
| 24 | O'Hare | OHARE | MultiPolygon | 3 | 2,424 | ✅ Valid |
| 34 | Lake View | LAKE VIEW | MultiPolygon | 1 | 1,113 | ✅ Valid |
| 35 | Lincoln Park | LINCOLN PARK | MultiPolygon | 1 | 1,422 | ✅ Valid |
| 48 | Rogers Park | ROGERS PARK | MultiPolygon | 1 | 926 | ✅ Valid |
| 50 | Sauganash,Forest Glen | SAUGANASH,FOREST GLEN | MultiPolygon | 1 | 1,883 | ✅ Valid |
| 56 | Uptown | UPTOWN | MultiPolygon | 1 | 1,021 | ✅ Valid |
| 57 | Norwood Park | NORWOOD PARK | MultiPolygon | 1 | 1,707 | ✅ Valid |
| 67 | Near South Side | NEAR SOUTH SIDE | MultiPolygon | 1 | 297 | ✅ Valid |
| 74 | Hyde Park | HYDE PARK | MultiPolygon | 1 | 543 | ✅ Valid |

**Complete list:** All 98 neighborhoods validated ✅

### Validation Results

```
Total neighborhoods:      98
✅ Valid geometries:      98
❌ Null geometries:       0
❌ Empty coordinates:     0
❌ Malformed features:    0
❌ Total invalid:         0
```

**Success Rate:** 100% (98/98)

---

## Comparison: Community Areas vs Neighborhoods

### Side-by-Side Comparison

| Aspect | Community Areas | Neighborhoods |
|--------|----------------|---------------|
| **File** | Boundaries_-_Community_Areas_20251030.geojson | Neighborhoods_2012b_20251030.geojson |
| **Total Areas** | 77 | 98 |
| **Geometry Type** | MultiPolygon | MultiPolygon |
| **Valid Geometries** | 77 (100%) | 98 (100%) |
| **Missing Geometries** | 0 | 0 |
| **Data Source** | Chicago Data Portal (Official) | Chicago Data Portal (Official) |
| **File Size** | ~2.5 MB | ~2.1 MB |
| **Average Points per Area** | ~750 points | ~550 points |

### Key Observations

1. **Both files are complete** - No missing geometries in either file
2. **Same format** - Both use MultiPolygon geometry type
3. **Same structure** - Both have identical JSON structure
4. **Different granularity:**
   - Community Areas: 77 official administrative divisions
   - Neighborhoods: 98 informal neighborhood names (more granular)
5. **Property differences:**
   - Community Areas: `community`, `area_numbe`
   - Neighborhoods: `pri_neigh`, `sec_neigh`

### Overlapping Areas

Some neighborhoods correspond to community areas:

| Neighborhood (pri_neigh) | Community Area (community) | Match |
|--------------------------|---------------------------|-------|
| Rogers Park | ROGERS PARK | ✅ Exact |
| Uptown | UPTOWN | ✅ Exact |
| Lincoln Park | LINCOLN PARK | ✅ Exact |
| Hyde Park | HYDE PARK | ✅ Exact |
| Norwood Park | NORWOOD PARK | ✅ Exact |
| O'Hare | OHARE | ✅ Exact |
| Sauganash,Forest Glen | FOREST GLEN | ⚠️ Partial |
| Near South Side | NEAR SOUTH SIDE | ✅ Exact |

---

## CSV Viewing Issue (SAME AS COMMUNITY AREAS)

### Why Geometries Appear "Missing" in CSV

**Root Cause:** CSV format cannot represent nested array structures

**GeoJSON Structure:**
```json
{
  "geometry": {
    "type": "MultiPolygon",
    "coordinates": [           // Level 1: Array of polygons
      [                        // Level 2: Array of rings
        [                      // Level 3: Array of points
          [-87.78, 41.99],     // Level 4: [lon, lat]
          [-87.78, 41.99],
          ...
        ]
      ]
    ]
  }
}
```

**CSV Limitations:**
- CSV is **flat** (2D table: rows × columns)
- GeoJSON geometries are **nested** (4 levels deep)
- CSV viewers **truncate** or **hide** complex nested data
- **Result:** Appears empty/missing but data is actually present

### What You See in CSV

**Actual data in GeoJSON:**
```json
"coordinates": [[[[
  [-87.78002, 41.99741],
  [-87.78049, 41.99741],
  ... (1,707 more points)
]]]]
```

**What CSV shows:**
```
pri_neigh        | coordinates
-----------------|-------------
Norwood Park     | [[[[-87.78...
```

Or even worse:
```
pri_neigh        | coordinates
-----------------|-------------
Norwood Park     | (truncated)
```

---

## Format Analysis

### File Structure

Both files use identical GeoJSON structure:

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "pri_neigh": "Norwood Park",      // Neighborhoods file
        "community": "NORWOOD PARK",      // Community Areas file
        "sec_neigh": "NORWOOD PARK",
        "shape_area": "...",
        "shape_len": "..."
      },
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-87.78002228630051, 41.99741355306097],
              [-87.78049248636901, 41.997410075445806],
              ...
            ]
          ]
        ]
      }
    }
  ]
}
```

### Coordinate Precision

Both files use **high-precision coordinates:**
- Longitude: 14-17 decimal places (~0.0001 inch precision)
- Latitude: 14-17 decimal places (~0.0001 inch precision)

**Example:**
```
Norwood Park: [-87.78002228630051, 41.99741355306097]
```

This precision is **far more** than needed for mapping:
- 6 decimals = ~4 inch precision
- 14+ decimals = sub-millimeter precision

---

## Recommendations

### ✅ WHAT TO DO:

1. **Use both files as-is**
   - Community Areas: 77 official administrative boundaries
   - Neighborhoods: 98 informal neighborhood names
   - Both are complete and ready to use

2. **View GeoJSON files properly**
   ```bash
   # Option 1: Web viewer
   open https://geojson.io
   # Then drag and drop the file

   # Option 2: Python/GeoPandas
   import geopandas as gpd
   gdf = gpd.read_file("Neighborhoods_2012b_20251030.geojson")
   gdf.plot()
   ```

3. **Upload to BigQuery**
   ```python
   import geopandas as gpd
   from google.cloud import bigquery

   # Load neighborhoods
   gdf = gpd.read_file("Neighborhoods_2012b_20251030.geojson")
   gdf['geometry'] = gdf['geometry'].apply(lambda x: x.wkt)

   # Upload to BigQuery
   client = bigquery.Client()
   gdf.to_gbq(
       'reference.ref_boundaries_neighborhoods',
       project_id='chicago-bi',
       if_exists='replace'
   )
   ```

4. **Choose the right file for your use case:**
   - **Community Areas** (77): For official reporting, policy analysis
   - **Neighborhoods** (98): For user-facing applications, local insights

### ❌ WHAT NOT TO DO:

1. **Don't convert to CSV for viewing geometries**
   - You'll lose all geometry data
   - It will appear "missing" even when present

2. **Don't assume data is missing**
   - Both files are 100% complete
   - CSV viewing issue ≠ missing data

3. **Don't try to "fix" or "merge" data**
   - Nothing is broken
   - All geometries are valid

---

## Use Cases for Each File

### Community Areas (77 areas)

**Best for:**
- Official city reporting
- Policy analysis
- Census data alignment
- Socioeconomic studies
- Healthcare resource allocation
- COVID-19 analysis (CCVI alignment)

**Example Query:**
```sql
SELECT
  c.community,
  COUNT(t.trip_id) as trip_count,
  AVG(t.fare) as avg_fare
FROM raw_data.raw_taxi_trips t
JOIN reference.ref_boundaries_community c
  ON ST_CONTAINS(
    c.geometry,
    ST_GEOGPOINT(t.pickup_longitude, t.pickup_latitude)
  )
GROUP BY c.community
ORDER BY trip_count DESC;
```

### Neighborhoods (98 areas)

**Best for:**
- User-facing dashboards
- Real estate applications
- Local business insights
- Tourism maps
- Restaurant/venue recommendations
- Hyper-local analytics

**Example Query:**
```sql
SELECT
  n.pri_neigh as neighborhood,
  n.sec_neigh as secondary_name,
  COUNT(p.permit_number) as permit_count,
  SUM(p.estimated_cost) as total_investment
FROM raw_data.raw_building_permits p
JOIN reference.ref_boundaries_neighborhoods n
  ON ST_CONTAINS(
    n.geometry,
    ST_GEOGPOINT(p.longitude, p.latitude)
  )
GROUP BY n.pri_neigh, n.sec_neigh
ORDER BY total_investment DESC;
```

---

## File Statistics

### Community Areas File

```
Filename: Boundaries_-_Community_Areas_20251030.geojson
Size: ~2.5 MB
Features: 77
Geometry Type: MultiPolygon
Total Coordinate Points: ~58,000
Average Points per Area: ~753
Min Points: 211 (Burnside)
Max Points: 2,424 (OHARE)
```

### Neighborhoods File

```
Filename: Neighborhoods_2012b_20251030.geojson
Size: ~2.1 MB
Features: 98
Geometry Type: MultiPolygon
Total Coordinate Points: ~54,000
Average Points per Area: ~551
Min Points: 37 (Magnificent Mile)
Max Points: 2,424 (O'Hare)
```

---

## BigQuery Schema Recommendations

### Community Areas Table

```sql
CREATE TABLE reference.ref_boundaries_community (
  community STRING NOT NULL,
  area_number STRING,
  geometry GEOGRAPHY NOT NULL,
  shape_area FLOAT64,
  shape_len FLOAT64,
  _created_at TIMESTAMP
)
OPTIONS(
  description = "Chicago community area boundaries (77 official areas)"
);
```

### Neighborhoods Table

```sql
CREATE TABLE reference.ref_boundaries_neighborhoods (
  pri_neigh STRING NOT NULL,
  sec_neigh STRING,
  geometry GEOGRAPHY NOT NULL,
  shape_area FLOAT64,
  shape_len FLOAT64,
  _created_at TIMESTAMP
)
OPTIONS(
  description = "Chicago neighborhood boundaries (98 informal neighborhoods)"
);
```

---

## Conclusion

**Your observation:** "Can see some missing geometries in CSV for neighborhoods file"

**Reality:**
- ✅ All 98 geometries are present and valid
- ❌ None are missing
- ⚠️ CSV format limitation created false appearance of missing data

**Verdict:**
Both the **Community Areas** (77) and **Neighborhoods** (98) files are **COMPLETE, VALID, and READY TO USE**. No parsing, merging, or fixing needed!

---

## Next Steps for Chicago BI Project

1. **Upload both files to BigQuery**
   ```bash
   cd ~/Desktop/chicago-bi-app/geospatial/geopandas

   # Upload community areas
   python generate_community_boundaries.py \
     --file "/Users/albin/Downloads/Geographical Reference Files/Boundaries_-_Community_Areas_20251030.geojson"

   # Upload neighborhoods
   python generate_neighborhood_boundaries.py \
     --file "/Users/albin/Downloads/Geographical Reference Files/Neighborhoods_2012b_20251030.geojson"
   ```

2. **Use in spatial joins** for taxi trip enrichment

3. **Create dual-granularity dashboards**
   - High-level: Community Areas (77)
   - Detailed: Neighborhoods (98)

4. **Enable geographic filtering** in Looker Studio

---

## Validation Scripts

**Location:** `~/Desktop/chicago-bi-app/geospatial/`

**Available Scripts:**
- `validate_geometries.py` - Community Areas validator
- `validate_neighborhoods.py` - Neighborhoods validator
- `view_geometries.py` - Visual geometry viewer

**Run Validation:**
```bash
cd ~/Desktop/chicago-bi-app/geospatial

# Validate community areas
python3 validate_geometries.py

# Validate neighborhoods
python3 validate_neighborhoods.py

# View geometries
python3 view_geometries.py \
  --file "/Users/albin/Downloads/Geographical Reference Files/Neighborhoods_2012b_20251030.geojson"
```

---

**Generated by:** Chicago BI App Validation System
**Project:** Northwestern University MSDSP 432 - Phase 2
**Team:** Group 2
