-- ============================================================================
-- Chicago Boundary Crosswalk Tables
-- Creates many-to-many spatial relationship tables
-- ============================================================================

-- ============================================================================
-- 1. Community Area ↔ ZIP Code Crosswalk
-- ============================================================================

CREATE OR REPLACE TABLE `chicago-bi-app-msds-432-476520.reference_data.crosswalk_community_zip` AS
WITH intersections AS (
  SELECT
    CAST(ca.area_numbe AS INT64) as community_area_number,
    ca.community as community_area_name,
    CAST(zip.zip AS STRING) as zip_code,
    -- Calculate intersection area
    ST_AREA(ST_INTERSECTION(ca.geometry, zip.geometry)) as intersection_area,
    ST_AREA(ca.geometry) as community_area_total_area,
    ST_AREA(zip.geometry) as zip_total_area
  FROM `chicago-bi-app-msds-432-476520.reference_data.community_area_boundaries` ca
  CROSS JOIN `chicago-bi-app-msds-432-476520.reference_data.zip_code_boundaries` zip
  WHERE ST_INTERSECTS(ca.geometry, zip.geometry)
)
SELECT
  community_area_number,
  community_area_name,
  zip_code,
  intersection_area,
  -- Percentage of community area covered by this ZIP
  ROUND(intersection_area / community_area_total_area * 100, 2) as pct_of_community_area,
  -- Percentage of ZIP covered by this community area
  ROUND(intersection_area / zip_total_area * 100, 2) as pct_of_zip,
  -- Flag for primary relationship (>50% overlap)
  CASE
    WHEN intersection_area / community_area_total_area > 0.5 THEN TRUE
    ELSE FALSE
  END as is_primary_zip
FROM intersections
ORDER BY community_area_number, pct_of_community_area DESC;

-- ============================================================================
-- 2. Community Area ↔ Neighborhood Crosswalk
-- ============================================================================

CREATE OR REPLACE TABLE `chicago-bi-app-msds-432-476520.reference_data.crosswalk_community_neighborhood` AS
WITH intersections AS (
  SELECT
    CAST(ca.area_numbe AS INT64) as community_area_number,
    ca.community as community_area_name,
    nb.pri_neigh as neighborhood_name,
    ST_AREA(ST_INTERSECTION(ca.geometry, nb.geometry)) as intersection_area,
    ST_AREA(ca.geometry) as community_area_total_area,
    ST_AREA(nb.geometry) as neighborhood_total_area
  FROM `chicago-bi-app-msds-432-476520.reference_data.community_area_boundaries` ca
  CROSS JOIN `chicago-bi-app-msds-432-476520.reference_data.neighborhood_boundaries` nb
  WHERE ST_INTERSECTS(ca.geometry, nb.geometry)
)
SELECT
  community_area_number,
  community_area_name,
  neighborhood_name,
  intersection_area,
  ROUND(intersection_area / community_area_total_area * 100, 2) as pct_of_community_area,
  ROUND(intersection_area / neighborhood_total_area * 100, 2) as pct_of_neighborhood,
  CASE
    WHEN intersection_area / neighborhood_total_area > 0.5 THEN TRUE
    ELSE FALSE
  END as is_primary_community_area
FROM intersections
ORDER BY community_area_number, pct_of_community_area DESC;

-- ============================================================================
-- 3. ZIP Code ↔ Neighborhood Crosswalk
-- ============================================================================

CREATE OR REPLACE TABLE `chicago-bi-app-msds-432-476520.reference_data.crosswalk_zip_neighborhood` AS
WITH intersections AS (
  SELECT
    CAST(zip.zip AS STRING) as zip_code,
    nb.pri_neigh as neighborhood_name,
    ST_AREA(ST_INTERSECTION(zip.geometry, nb.geometry)) as intersection_area,
    ST_AREA(zip.geometry) as zip_total_area,
    ST_AREA(nb.geometry) as neighborhood_total_area
  FROM `chicago-bi-app-msds-432-476520.reference_data.zip_code_boundaries` zip
  CROSS JOIN `chicago-bi-app-msds-432-476520.reference_data.neighborhood_boundaries` nb
  WHERE ST_INTERSECTS(zip.geometry, nb.geometry)
)
SELECT
  zip_code,
  neighborhood_name,
  intersection_area,
  ROUND(intersection_area / zip_total_area * 100, 2) as pct_of_zip,
  ROUND(intersection_area / neighborhood_total_area * 100, 2) as pct_of_neighborhood,
  CASE
    WHEN intersection_area / zip_total_area > 0.5 THEN TRUE
    ELSE FALSE
  END as is_primary_neighborhood
FROM intersections
ORDER BY zip_code, pct_of_zip DESC;

-- ============================================================================
-- 4. Complete Many-to-Many Crosswalk (All Three)
-- ============================================================================

CREATE OR REPLACE TABLE `chicago-bi-app-msds-432-476520.reference_data.crosswalk_complete` AS
WITH three_way_intersections AS (
  SELECT
    CAST(ca.area_numbe AS INT64) as community_area_number,
    ca.community as community_area_name,
    CAST(zip.zip AS STRING) as zip_code,
    nb.pri_neigh as neighborhood_name,
    -- Calculate three-way intersection
    ST_AREA(ST_INTERSECTION(
      ST_INTERSECTION(ca.geometry, zip.geometry),
      nb.geometry
    )) as intersection_area,
    ST_AREA(ca.geometry) as ca_area,
    ST_AREA(zip.geometry) as zip_area,
    ST_AREA(nb.geometry) as nb_area
  FROM `chicago-bi-app-msds-432-476520.reference_data.community_area_boundaries` ca
  CROSS JOIN `chicago-bi-app-msds-432-476520.reference_data.zip_code_boundaries` zip
  CROSS JOIN `chicago-bi-app-msds-432-476520.reference_data.neighborhood_boundaries` nb
  WHERE ST_INTERSECTS(ca.geometry, zip.geometry)
    AND ST_INTERSECTS(ca.geometry, nb.geometry)
    AND ST_INTERSECTS(zip.geometry, nb.geometry)
    AND ST_AREA(ST_INTERSECTION(
      ST_INTERSECTION(ca.geometry, zip.geometry),
      nb.geometry
    )) > 0
)
SELECT
  community_area_number,
  community_area_name,
  zip_code,
  neighborhood_name,
  intersection_area,
  ROUND(intersection_area / ca_area * 100, 2) as pct_of_community_area,
  ROUND(intersection_area / zip_area * 100, 2) as pct_of_zip,
  ROUND(intersection_area / nb_area * 100, 2) as pct_of_neighborhood
FROM three_way_intersections
WHERE intersection_area > 1000  -- Filter out tiny slivers
ORDER BY community_area_number, pct_of_community_area DESC;

-- ============================================================================
-- 5. Point-Based Lookup Helper View
-- For enriching datasets with lat/lon using ST_WITHIN
-- ============================================================================

-- NOTE: Ward boundaries view commented out - load ward boundaries first
-- Uncomment after loading ward_boundaries table

/*
CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.reference_data.point_lookup_helper` AS
SELECT
  ca.area_numbe as community_area_number,
  ca.community as community_area_name,
  ca.geometry as community_area_geom,
  zip.zip as zip_code,
  zip.geometry as zip_geom,
  nb.pri_neigh as neighborhood_name,
  nb.geometry as neighborhood_geom
FROM `chicago-bi-app-msds-432-476520.reference_data.community_area_boundaries` ca
CROSS JOIN `chicago-bi-app-msds-432-476520.reference_data.zip_code_boundaries` zip
CROSS JOIN `chicago-bi-app-msds-432-476520.reference_data.neighborhood_boundaries` nb;
*/

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Check community area ↔ ZIP relationships
SELECT 'Community Area to ZIP Crosswalk' as check_name,
  COUNT(*) as total_relationships,
  COUNT(DISTINCT community_area_number) as unique_community_areas,
  COUNT(DISTINCT zip_code) as unique_zips
FROM `chicago-bi-app-msds-432-476520.reference_data.crosswalk_community_zip`;

-- Check for community areas with multiple ZIPs
SELECT 'Community Areas with Multiple ZIPs' as check_name,
  COUNT(*) as community_areas_with_multiple_zips
FROM (
  SELECT community_area_number, COUNT(DISTINCT zip_code) as zip_count
  FROM `chicago-bi-app-msds-432-476520.reference_data.crosswalk_community_zip`
  GROUP BY community_area_number
  HAVING COUNT(DISTINCT zip_code) > 1
);

-- Check for ZIPs spanning multiple community areas
SELECT 'ZIPs Spanning Multiple Community Areas' as check_name,
  COUNT(*) as zips_spanning_multiple_areas
FROM (
  SELECT zip_code, COUNT(DISTINCT community_area_number) as ca_count
  FROM `chicago-bi-app-msds-432-476520.reference_data.crosswalk_community_zip`
  GROUP BY zip_code
  HAVING COUNT(DISTINCT community_area_number) > 1
);
