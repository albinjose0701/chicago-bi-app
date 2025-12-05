-- ============================================================================
-- Bronze Layer: Building Permits
-- Filters: Must have both latitude AND longitude (not null, not blank)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.bronze_data.bronze_building_permits`
PARTITION BY issue_date
CLUSTER BY community_area
AS
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
  -- Partition filter (required for partitioned tables)
  AND DATE(issue_date) >= '2020-01-01'
  AND DATE(issue_date) <= CURRENT_DATE()

  -- Coordinate quality filters (must have both lat AND lon)
  AND latitude IS NOT NULL
  AND longitude IS NOT NULL
  -- Also ensure they're valid Chicago coordinates
  AND latitude BETWEEN 41.6 AND 42.1
  AND longitude BETWEEN -87.95 AND -87.5;
