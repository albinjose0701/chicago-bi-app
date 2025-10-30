-- Chicago BI App - Bronze Layer (Raw Data)
-- Dataset: raw_data
-- Purpose: Store raw ingested data with full lineage

-- Create dataset
CREATE SCHEMA IF NOT EXISTS `chicago-bi.raw_data`
OPTIONS(
  description = "Bronze layer - Raw data from Chicago Data Portal",
  location = "us-central1"
);

-- Table 1: Raw Taxi Trips
CREATE TABLE IF NOT EXISTS `chicago-bi.raw_data.raw_taxi_trips`
(
  -- Primary key
  trip_id STRING NOT NULL,

  -- Trip details
  taxi_id STRING,
  trip_start_timestamp TIMESTAMP,
  trip_end_timestamp TIMESTAMP,
  trip_seconds INT64,
  trip_miles FLOAT64,

  -- Pickup location
  pickup_census_tract STRING,
  pickup_community_area STRING,
  pickup_centroid_latitude FLOAT64,
  pickup_centroid_longitude FLOAT64,

  -- Dropoff location
  dropoff_census_tract STRING,
  dropoff_community_area STRING,
  dropoff_centroid_latitude FLOAT64,
  dropoff_centroid_longitude FLOAT64,

  -- Financial
  fare FLOAT64,
  tips FLOAT64,
  tolls FLOAT64,
  extras FLOAT64,
  trip_total FLOAT64,
  payment_type STRING,

  -- Company
  company STRING,

  -- Metadata
  _ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  _source_file STRING,
  _api_response_code INT64
)
PARTITION BY DATE(trip_start_timestamp)
CLUSTER BY pickup_centroid_latitude, pickup_centroid_longitude
OPTIONS(
  description = "Raw taxi trip data from Chicago Data Portal",
  require_partition_filter = TRUE,
  partition_expiration_days = 30
);

-- Table 2: Raw TNP Permits
CREATE TABLE IF NOT EXISTS `chicago-bi.raw_data.raw_tnp_permits`
(
  -- Primary key
  id STRING NOT NULL,

  -- Permit details
  permit_number STRING,
  permit_type STRING,
  permit_status STRING,
  issue_date DATE,
  expiration_date DATE,

  -- Vehicle/Driver
  license_type STRING,
  license_number STRING,
  vehicle_id STRING,
  vehicle_year INT64,
  vehicle_make STRING,
  vehicle_model STRING,

  -- Address
  address STRING,
  city STRING,
  state STRING,
  zip_code STRING,
  latitude FLOAT64,
  longitude FLOAT64,

  -- Metadata
  _ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  _source_file STRING
)
PARTITION BY issue_date
OPTIONS(
  description = "Raw Transportation Network Provider permits",
  require_partition_filter = TRUE,
  partition_expiration_days = 30
);

-- Table 3: Raw COVID Cases
CREATE TABLE IF NOT EXISTS `chicago-bi.raw_data.raw_covid_cases`
(
  -- Composite key
  zip_code STRING NOT NULL,
  week_start DATE NOT NULL,
  week_end DATE NOT NULL,

  -- COVID metrics
  cases_weekly INT64,
  cases_cumulative INT64,
  case_rate_weekly FLOAT64,
  case_rate_cumulative FLOAT64,

  -- Testing
  tests_weekly INT64,
  tests_cumulative INT64,
  test_rate_weekly FLOAT64,
  test_rate_cumulative FLOAT64,
  percent_tested_positive_weekly FLOAT64,
  percent_tested_positive_cumulative FLOAT64,

  -- Deaths
  deaths_weekly INT64,
  deaths_cumulative INT64,
  death_rate_weekly FLOAT64,
  death_rate_cumulative FLOAT64,

  -- Population
  population INT64,

  -- Metadata
  _ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  _source_file STRING
)
PARTITION BY week_start
CLUSTER BY zip_code
OPTIONS(
  description = "Raw COVID-19 cases by zip code and week",
  require_partition_filter = TRUE
);

-- Table 4: Raw Building Permits
CREATE TABLE IF NOT EXISTS `chicago-bi.raw_data.raw_building_permits`
(
  -- Primary key
  id STRING NOT NULL,
  permit_number STRING,

  -- Permit details
  permit_type STRING,
  review_type STRING,
  application_start_date DATE,
  issue_date DATE,
  processing_time INT64,

  -- Work description
  work_description STRING,
  estimated_cost FLOAT64,

  -- Location
  street_number STRING,
  street_direction STRING,
  street_name STRING,
  suffix STRING,
  zip_code STRING,
  latitude FLOAT64,
  longitude FLOAT64,

  -- Community
  community_area STRING,
  census_tract STRING,
  ward STRING,

  -- Contractor
  contractor_name STRING,

  -- Metadata
  _ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  _source_file STRING
)
PARTITION BY issue_date
CLUSTER BY zip_code
OPTIONS(
  description = "Raw building permits",
  require_partition_filter = TRUE,
  partition_expiration_days = 30
);
