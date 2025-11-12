-- ============================================================================
-- Enrich Raw Datasets with Spatial Data Using ST_WITHIN
-- Creates enriched views in silver_data dataset
-- ============================================================================

-- Create silver_data dataset if it doesn't exist
CREATE SCHEMA IF NOT EXISTS `chicago-bi-app-msds-432-476520.silver_data`;

-- ============================================================================
-- 1. Enriched Building Permits
-- Uses point-in-polygon lookups with ST_WITHIN
-- ============================================================================

CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.silver_data.permits_enriched` AS
WITH permit_locations AS (
  SELECT
    p.*,
    ST_GEOGPOINT(p.longitude, p.latitude) as location_point
  FROM `chicago-bi-app-msds-432-476520.raw_data.raw_building_permits` p
  WHERE p.latitude IS NOT NULL
    AND p.longitude IS NOT NULL
    AND p.latitude BETWEEN 41.6 AND 42.1  -- Chicago bounds
    AND p.longitude BETWEEN -87.95 AND -87.5
)
SELECT
  p.*,
  -- Community area (from point lookup)
  ca.area_numbe as verified_community_area,
  ca.community as community_area_name_verified,
  CASE
    WHEN CAST(p.community_area AS STRING) = ca.area_numbe THEN TRUE
    ELSE FALSE
  END as community_area_matches,

  -- ZIP code (from point lookup)
  zip.zip as zip_code_verified,

  -- Neighborhood (from point lookup)
  nb.pri_neigh as neighborhood_name,
  nb.sec_neigh as secondary_neighborhood,

  -- Ward (from point lookup)
  wd.ward as ward_number,
  wd.alderman as alderman_name,

  -- Census tract
  ct.tractce10 as census_tract

FROM permit_locations p
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.community_area_boundaries` ca
  ON ST_WITHIN(p.location_point, ca.the_geom)
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.zip_code_boundaries` zip
  ON ST_WITHIN(p.location_point, zip.the_geom)
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.neighborhood_boundaries` nb
  ON ST_WITHIN(p.location_point, nb.the_geom)
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.ward_boundaries` wd
  ON ST_WITHIN(p.location_point, wd.the_geom)
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.census_tract_boundaries` ct
  ON ST_WITHIN(p.location_point, ct.the_geom);

-- ============================================================================
-- 2. Enriched COVID-19 Cases
-- Uses crosswalk tables since data is by ZIP code
-- ============================================================================

CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.silver_data.covid_enriched` AS
SELECT
  c.*,
  -- Add community area info via crosswalk (may have multiple per ZIP)
  cw.community_area_number,
  cw.community_area_name,
  cw.pct_of_zip,
  cw.is_primary_zip,

  -- Add neighborhood info via crosswalk
  zn.neighborhood_name,
  zn.pct_of_neighborhood,

  -- Distribute cases proportionally if ZIP spans multiple community areas
  CASE
    WHEN cw.pct_of_zip > 0 THEN
      ROUND(c.cases_weekly * (cw.pct_of_zip / 100))
    ELSE NULL
  END as estimated_cases_in_community_area,

  CASE
    WHEN cw.pct_of_zip > 0 THEN
      ROUND(c.deaths_weekly * (cw.pct_of_zip / 100))
    ELSE NULL
  END as estimated_deaths_in_community_area

FROM `chicago-bi-app-msds-432-476520.raw_data.raw_covid19_cases_by_zip` c
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.crosswalk_community_zip` cw
  ON c.zip_code = cw.zip_code
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.crosswalk_zip_neighborhood` zn
  ON c.zip_code = zn.zip_code AND zn.is_primary_neighborhood = TRUE;

-- ============================================================================
-- 3. Enriched Taxi Trips (if you want to add geography later)
-- Using pickup/dropoff coordinates
-- ============================================================================

CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.silver_data.taxi_trips_with_geography` AS
WITH trip_locations AS (
  SELECT
    t.*,
    ST_GEOGPOINT(t.pickup_longitude, t.pickup_latitude) as pickup_location,
    ST_GEOGPOINT(t.dropoff_longitude, t.dropoff_latitude) as dropoff_location
  FROM `chicago-bi-app-msds-432-476520.raw_data.raw_taxi_trips` t
  WHERE t.pickup_latitude IS NOT NULL
    AND t.pickup_longitude IS NOT NULL
    AND t.pickup_latitude BETWEEN 41.6 AND 42.1
    AND t.pickup_longitude BETWEEN -87.95 AND -87.5
  LIMIT 1000000  -- Sample for testing
)
SELECT
  t.trip_id,
  t.trip_start_timestamp,
  t.trip_end_timestamp,
  t.trip_miles,
  t.trip_total,

  -- Pickup location enrichment
  pickup_ca.community as pickup_community_area,
  pickup_nb.pri_neigh as pickup_neighborhood,
  pickup_zip.zip as pickup_zip_code,

  -- Dropoff location enrichment
  dropoff_ca.community as dropoff_community_area,
  dropoff_nb.pri_neigh as dropoff_neighborhood,
  dropoff_zip.zip as dropoff_zip_code,

  -- Trip distance calculation
  ST_DISTANCE(t.pickup_location, t.dropoff_location) as straight_line_distance_meters

FROM trip_locations t
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.community_area_boundaries` pickup_ca
  ON ST_WITHIN(t.pickup_location, pickup_ca.the_geom)
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.neighborhood_boundaries` pickup_nb
  ON ST_WITHIN(t.pickup_location, pickup_nb.the_geom)
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.zip_code_boundaries` pickup_zip
  ON ST_WITHIN(t.pickup_location, pickup_zip.the_geom)
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.community_area_boundaries` dropoff_ca
  ON ST_WITHIN(t.dropoff_location, dropoff_ca.the_geom)
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.neighborhood_boundaries` dropoff_nb
  ON ST_WITHIN(t.dropoff_location, dropoff_nb.the_geom)
LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.zip_code_boundaries` dropoff_zip
  ON ST_WITHIN(t.dropoff_location, dropoff_zip.the_geom);

-- ============================================================================
-- 4. Aggregated Permits by Multiple Geographies
-- Using the many-to-many relationships
-- ============================================================================

CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.silver_data.permits_by_community_and_zip` AS
SELECT
  EXTRACT(YEAR FROM p.issue_date) as year,
  EXTRACT(MONTH FROM p.issue_date) as month,
  p.community_area,
  pe.zip_code_verified,
  pe.neighborhood_name,
  COUNT(*) as permit_count,
  SUM(p.total_fee) as total_fees,
  AVG(p.total_fee) as avg_fee,
  COUNT(CASE WHEN p.permit_type = 'PERMIT - NEW CONSTRUCTION' THEN 1 END) as new_construction_count,
  COUNT(CASE WHEN p.permit_type = 'PERMIT - RENOVATION/ALTERATION' THEN 1 END) as renovation_count
FROM `chicago-bi-app-msds-432-476520.raw_data.raw_building_permits` p
LEFT JOIN `chicago-bi-app-msds-432-476520.silver_data.permits_enriched` pe
  ON p.permit_ = pe.permit_
WHERE p.issue_date >= '2020-01-01'
GROUP BY year, month, p.community_area, pe.zip_code_verified, pe.neighborhood_name;

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Count enriched permits
SELECT 'Enriched Permits' as view_name, COUNT(*) as record_count
FROM `chicago-bi-app-msds-432-476520.silver_data.permits_enriched`
WHERE issue_date >= '2020-01-01';

-- Check match rate for community areas
SELECT 'Community Area Match Rate' as metric,
  ROUND(
    COUNTIF(community_area_matches = TRUE) / COUNT(*) * 100,
    2
  ) as match_percentage
FROM `chicago-bi-app-msds-432-476520.silver_data.permits_enriched`
WHERE issue_date >= '2020-01-01';

-- Sample enriched COVID data
SELECT zip_code, community_area_name, neighborhood_name,
  SUM(estimated_cases_in_community_area) as total_estimated_cases
FROM `chicago-bi-app-msds-432-476520.silver_data.covid_enriched`
WHERE week_start >= '2020-03-01'
GROUP BY zip_code, community_area_name, neighborhood_name
ORDER BY total_estimated_cases DESC
LIMIT 10;
