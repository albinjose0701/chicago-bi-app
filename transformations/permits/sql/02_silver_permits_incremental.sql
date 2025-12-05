-- ============================================================================
-- SILVER LAYER: Building Permits Enriched - INCREMENTAL UPDATE
-- ============================================================================
-- Purpose: Incrementally enrich permits with spatial data (ZIP, neighborhood)
-- Strategy: MERGE on primary key (id) to avoid duplicates
-- Dependencies: bronze_building_permits, zip_code_boundaries, neighborhood_boundaries
-- ============================================================================

-- Create table if not exists (first run only)
CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched` (
  id STRING NOT NULL,
  permit_ STRING,
  permit_status STRING,
  permit_type STRING,
  application_start_date DATE,
  issue_date DATE,
  processing_time INT64,
  work_type STRING,
  total_fee FLOAT64,
  reported_cost FLOAT64,
  community_area INT64,
  latitude FLOAT64,
  longitude FLOAT64,
  zip_code STRING,
  neighborhood STRING,
  permit_year INT64,
  permit_month INT64,
  enriched_at TIMESTAMP
)
PARTITION BY issue_date
CLUSTER BY community_area, permit_type;

-- ============================================================================
-- MERGE Statement: Enrich and add/update records
-- ============================================================================

MERGE `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched` AS target
USING (
  WITH permits_with_geography AS (
    SELECT
      p.*,
      -- Create geography point for spatial joins
      ST_GEOGPOINT(p.longitude, p.latitude) as permit_point
    FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_building_permits` p
    WHERE issue_date >= '2020-01-01'
      AND issue_date <= CURRENT_DATE()
      -- Incremental: Only process recent permits (last 30 days) OR all if silver empty
      AND (
        p.issue_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
        OR
        -- Or all records if silver is empty (initial load)
        NOT EXISTS (
          SELECT 1 FROM `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched` LIMIT 1
        )
      )
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

  FROM permits_with_neighborhood
) AS source

ON target.id = source.id

-- When record exists, update it
WHEN MATCHED THEN
  UPDATE SET
    permit_ = source.permit_,
    permit_status = source.permit_status,
    permit_type = source.permit_type,
    application_start_date = source.application_start_date,
    issue_date = source.issue_date,
    processing_time = source.processing_time,
    work_type = source.work_type,
    total_fee = source.total_fee,
    reported_cost = source.reported_cost,
    community_area = source.community_area,
    latitude = source.latitude,
    longitude = source.longitude,
    zip_code = source.zip_code,
    neighborhood = source.neighborhood,
    permit_year = source.permit_year,
    permit_month = source.permit_month,
    enriched_at = source.enriched_at

-- When record doesn't exist, insert it
WHEN NOT MATCHED THEN
  INSERT (
    id, permit_, permit_status, permit_type,
    application_start_date, issue_date, processing_time,
    work_type, total_fee, reported_cost,
    community_area, latitude, longitude,
    zip_code, neighborhood,
    permit_year, permit_month, enriched_at
  )
  VALUES (
    source.id, source.permit_, source.permit_status, source.permit_type,
    source.application_start_date, source.issue_date, source.processing_time,
    source.work_type, source.total_fee, source.reported_cost,
    source.community_area, source.latitude, source.longitude,
    source.zip_code, source.neighborhood,
    source.permit_year, source.permit_month, source.enriched_at
  );

-- ============================================================================
-- Verification Query (for logging)
-- ============================================================================
-- SELECT
--   'silver_permits_enriched' as layer,
--   COUNT(*) as total_records,
--   COUNT(DISTINCT id) as unique_ids,
--   COUNT(DISTINCT zip_code) as unique_zips,
--   COUNTIF(zip_code IS NULL) as missing_zip,
--   MIN(issue_date) as oldest_permit,
--   MAX(issue_date) as newest_permit,
--   MAX(enriched_at) as last_update
-- FROM `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched`;
