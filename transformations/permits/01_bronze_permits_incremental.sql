-- ============================================================================
-- BRONZE LAYER: Building Permits - INCREMENTAL UPDATE
-- ============================================================================
-- Purpose: Incrementally merge new permits from raw to bronze layer
-- Strategy: MERGE on primary key (id) to avoid duplicates
-- Filters: Valid coordinates, date range
-- ============================================================================

-- Create table if not exists (first run only)
CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.bronze_data.bronze_building_permits` (
  id STRING NOT NULL,
  permit_ STRING,
  permit_status STRING,
  permit_type STRING,
  application_start_date DATE,
  issue_date DATE,
  processing_time INT64,
  street_number INT64,
  street_direction STRING,
  street_name STRING,
  work_type STRING,
  work_description STRING,
  permit_condition STRING,
  total_fee FLOAT64,
  reported_cost FLOAT64,
  pin_list STRING,
  community_area INT64,
  latitude FLOAT64,
  longitude FLOAT64,
  extracted_at TIMESTAMP
)
PARTITION BY issue_date
CLUSTER BY community_area;

-- ============================================================================
-- MERGE Statement: Add new records or update existing ones
-- ============================================================================

MERGE `chicago-bi-app-msds-432-476520.bronze_data.bronze_building_permits` AS target
USING (
  SELECT
    -- Primary identifiers
    id,
    permit_,

    -- Permit details
    permit_status,
    permit_type,

    -- Dates (convert from TIMESTAMP to DATE)
    DATE(application_start_date) as application_start_date,
    DATE(issue_date) as issue_date,
    processing_time,

    -- Location address
    street_number,
    street_direction,
    street_name,

    -- Work details
    work_type,
    work_description,
    permit_condition,

    -- Financial
    ROUND(total_fee, 2) as total_fee,
    ROUND(reported_cost, 2) as reported_cost,

    -- Property identifiers
    pin_list,

    -- Geography
    community_area,
    ROUND(latitude, 6) as latitude,
    ROUND(longitude, 6) as longitude,

    -- Metadata
    CURRENT_TIMESTAMP() as extracted_at

  FROM `chicago-bi-app-msds-432-476520.raw_data.raw_building_permits`

  WHERE 1=1
    -- Date filters
    AND DATE(issue_date) >= '2020-01-01'
    AND DATE(issue_date) <= CURRENT_DATE()

    -- Coordinate quality filters (must have both lat AND lon)
    AND latitude IS NOT NULL
    AND longitude IS NOT NULL
    AND latitude BETWEEN 41.6 AND 42.1
    AND longitude BETWEEN -87.95 AND -87.5

    -- Incremental filter: Process recent permits (last 30 days) OR all if bronze empty
    AND (
      -- Recent permits (issued in last 30 days)
      DATE(issue_date) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
      OR
      -- Or all records if running initial load (when bronze is empty)
      NOT EXISTS (
        SELECT 1 FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_building_permits` LIMIT 1
      )
    )
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
    street_number = source.street_number,
    street_direction = source.street_direction,
    street_name = source.street_name,
    work_type = source.work_type,
    work_description = source.work_description,
    permit_condition = source.permit_condition,
    total_fee = source.total_fee,
    reported_cost = source.reported_cost,
    pin_list = source.pin_list,
    community_area = source.community_area,
    latitude = source.latitude,
    longitude = source.longitude,
    extracted_at = source.extracted_at

-- When record doesn't exist, insert it
WHEN NOT MATCHED THEN
  INSERT (
    id, permit_, permit_status, permit_type,
    application_start_date, issue_date, processing_time,
    street_number, street_direction, street_name,
    work_type, work_description, permit_condition,
    total_fee, reported_cost, pin_list,
    community_area, latitude, longitude, extracted_at
  )
  VALUES (
    source.id, source.permit_, source.permit_status, source.permit_type,
    source.application_start_date, source.issue_date, source.processing_time,
    source.street_number, source.street_direction, source.street_name,
    source.work_type, source.work_description, source.permit_condition,
    source.total_fee, source.reported_cost, source.pin_list,
    source.community_area, source.latitude, source.longitude, source.extracted_at
  );

-- ============================================================================
-- Verification Query (for logging)
-- ============================================================================
-- SELECT
--   'bronze_building_permits' as layer,
--   COUNT(*) as total_records,
--   COUNT(DISTINCT id) as unique_ids,
--   MIN(issue_date) as oldest_permit,
--   MAX(issue_date) as newest_permit,
--   MAX(extracted_at) as last_update
-- FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_building_permits`;
