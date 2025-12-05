-- ============================================================================
-- Silver Layer: Building Permits Enriched
-- Building permits with spatial enrichment for zip code and neighborhood
-- ============================================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched`
PARTITION BY issue_date
CLUSTER BY community_area, permit_type
AS
WITH permits_with_geography AS (
  SELECT
    p.*,
    -- Create geography point for spatial joins
    ST_GEOGPOINT(p.longitude, p.latitude) as permit_point
  FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_building_permits` p
  WHERE issue_date >= '2020-01-01'
    AND issue_date <= CURRENT_DATE()
),
permits_with_zip AS (
  SELECT
    p.*,
    -- ZIP code via spatial join (convert INTEGER to STRING)
    CAST(z.zip AS STRING) as zip_code
  FROM permits_with_geography p
  LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.zip_code_boundaries` z
    ON ST_CONTAINS(z.geometry, p.permit_point)
),
permits_with_neighborhood AS (
  SELECT
    p.*,
    -- Neighborhood via spatial join
    n.pri_neigh as neighborhood
  FROM permits_with_zip p
  LEFT JOIN `chicago-bi-app-msds-432-476520.reference_data.neighborhood_boundaries` n
    ON ST_CONTAINS(n.geometry, p.permit_point)
)
SELECT
  -- Primary key
  id,

  -- Permit details
  permit_,
  permit_status,
  permit_type,

  -- Dates
  application_start_date,
  issue_date,
  processing_time,

  -- Work details
  work_type,

  -- Financials
  ROUND(total_fee, 2) as total_fee,
  ROUND(reported_cost, 2) as reported_cost,

  -- Location
  community_area,
  ROUND(latitude, 6) as latitude,
  ROUND(longitude, 6) as longitude,

  -- Enriched geography fields (from spatial joins)
  zip_code,
  neighborhood,

  -- Derived date fields
  EXTRACT(YEAR FROM issue_date) as permit_year,
  EXTRACT(MONTH FROM issue_date) as permit_month,

  -- Audit timestamp
  CURRENT_TIMESTAMP() as enriched_at

FROM permits_with_neighborhood;
