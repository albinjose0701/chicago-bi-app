-- ============================================================================
-- Silver Layer: Building Permits - Clean & Enriched
-- Applies business rules, removes problematic data, adds quality flags
-- ============================================================================

CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.silver_data.permits_clean` AS
WITH permits_with_flags AS (
  SELECT
    *,
    -- Data quality flags
    CASE
      WHEN permit_ IS NULL THEN 'missing_permit_number'
      WHEN issue_date IS NULL THEN 'missing_issue_date'
      WHEN issue_date > CURRENT_DATE() THEN 'future_issue_date'
      WHEN issue_date < '2000-01-01' THEN 'invalid_issue_date'
      WHEN latitude IS NULL OR longitude IS NULL THEN 'missing_coordinates'
      WHEN latitude NOT BETWEEN 41.6 AND 42.1 THEN 'invalid_latitude'
      WHEN longitude NOT BETWEEN -87.95 AND -87.5 THEN 'invalid_longitude'
      WHEN total_fee < 0 THEN 'negative_fee'
      WHEN total_fee > 10000000 THEN 'extreme_high_fee'
      WHEN community_area < 1 OR community_area > 77 THEN 'invalid_community_area'
      ELSE 'valid'
    END as data_quality_flag,

    -- Additional derived fields
    DATE(issue_date) as issue_date_only,
    EXTRACT(YEAR FROM issue_date) as issue_year,
    EXTRACT(MONTH FROM issue_date) as issue_month,
    EXTRACT(QUARTER FROM issue_date) as issue_quarter,
    EXTRACT(DAYOFWEEK FROM issue_date) as issue_day_of_week,
    FORMAT_DATE('%B', issue_date) as issue_month_name,

    -- Fee categories
    CASE
      WHEN total_fee = 0 THEN 'No Fee'
      WHEN total_fee <= 100 THEN '$1-100'
      WHEN total_fee <= 500 THEN '$101-500'
      WHEN total_fee <= 1000 THEN '$501-1000'
      WHEN total_fee <= 5000 THEN '$1001-5000'
      WHEN total_fee <= 10000 THEN '$5001-10000'
      ELSE '$10000+'
    END as fee_category,

    -- Permit type simplified
    CASE
      WHEN LOWER(permit_type) LIKE '%new construction%' THEN 'New Construction'
      WHEN LOWER(permit_type) LIKE '%renovation%' OR LOWER(permit_type) LIKE '%alteration%' THEN 'Renovation/Alteration'
      WHEN LOWER(permit_type) LIKE '%wrecking%' OR LOWER(permit_type) LIKE '%demol%' THEN 'Demolition'
      WHEN LOWER(permit_type) LIKE '%sign%' THEN 'Sign'
      WHEN LOWER(permit_type) LIKE '%electrical%' THEN 'Electrical'
      WHEN LOWER(permit_type) LIKE '%plumb%' THEN 'Plumbing'
      ELSE 'Other'
    END as permit_type_category,

    -- Processing time (if application date exists)
    CASE
      WHEN application_start_date IS NOT NULL AND issue_date IS NOT NULL
      THEN DATE_DIFF(DATE(issue_date), DATE(application_start_date), DAY)
      ELSE NULL
    END as processing_days

  FROM `chicago-bi-app-msds-432-476520.raw_data.raw_building_permits`
)
SELECT
  -- Core identifiers
  permit_,
  id,
  row_id,

  -- Dates
  issue_date,
  issue_date_only,
  issue_year,
  issue_month,
  issue_quarter,
  issue_day_of_week,
  issue_month_name,
  application_start_date,
  processing_days,

  -- Permit details
  permit_type,
  permit_type_category,
  review_type,
  permit_status,
  permit_milestone,
  work_type,
  work_description,
  permit_condition,

  -- Location
  street_number,
  street_direction,
  street_name,
  latitude,
  longitude,
  community_area,
  census_tract,
  ward,
  xcoordinate,
  ycoordinate,
  zip_code,

  -- Fees
  total_fee,
  fee_category,
  building_fee_paid,
  building_fee_unpaid,
  building_fee_waived,
  building_fee_subtotal,
  zoning_fee_paid,
  zoning_fee_unpaid,
  zoning_fee_waived,
  zoning_fee_subtotal,
  other_fee_paid,
  other_fee_unpaid,
  other_fee_waived,
  other_fee_subtotal,
  subtotal_paid,
  subtotal_unpaid,
  subtotal_waived,

  -- Other details
  reported_cost,
  pin_list,

  -- Contacts (keeping top 2 for simplicity)
  contact_1_type,
  contact_1_name,
  contact_1_city,
  contact_1_state,
  contact_1_zipcode,
  contact_2_type,
  contact_2_name,
  contact_2_city,
  contact_2_state,
  contact_2_zipcode,

  -- Data quality
  data_quality_flag

FROM permits_with_flags
WHERE 1=1
  -- Critical filters - must have these
  AND permit_ IS NOT NULL
  AND issue_date IS NOT NULL
  AND issue_date >= '2020-01-01'
  AND issue_date <= CURRENT_DATE()

  -- Soft filters - flag bad data but allow nulls
  AND (
    latitude IS NULL
    OR (latitude BETWEEN 41.6 AND 42.1 AND longitude BETWEEN -87.95 AND -87.5)
  )
  AND (
    total_fee IS NULL
    OR (total_fee >= 0 AND total_fee <= 10000000)
  )
  AND (
    community_area IS NULL
    OR (community_area BETWEEN 1 AND 77)
  );

-- Create materialized version for better performance (optional)
-- Refresh daily with new data
CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.silver_data.permits_clean_materialized`
PARTITION BY issue_date_only
CLUSTER BY community_area, permit_type_category
AS
SELECT * FROM `chicago-bi-app-msds-432-476520.silver_data.permits_clean`;

-- Verification query
SELECT
  'Total Records' as metric,
  COUNT(*) as value,
  NULL as percentage
FROM `chicago-bi-app-msds-432-476520.silver_data.permits_clean`
WHERE issue_date >= '2020-01-01'

UNION ALL

SELECT
  'Records by Quality Flag' as metric,
  data_quality_flag as value,
  ROUND(COUNT(*) / (SELECT COUNT(*) FROM `chicago-bi-app-msds-432-476520.silver_data.permits_clean`) * 100, 2) as percentage
FROM `chicago-bi-app-msds-432-476520.silver_data.permits_clean`
WHERE issue_date >= '2020-01-01'
GROUP BY data_quality_flag
ORDER BY metric, percentage DESC;
