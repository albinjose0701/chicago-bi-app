#!/bin/bash
#
# Deploy BigQuery Schemas
# Creates all tables in the bronze layer (raw_data dataset)
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
PROJECT_ID="chicago-bi-app-msds-432-476520"
DATASET="raw_data"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Deploy BigQuery Schemas - Bronze Layer${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

print_section() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Step 1: Verify dataset exists
print_section "Step 1: Verify Dataset Exists"

if bq ls -d ${PROJECT_ID}:${DATASET} &>/dev/null; then
    print_success "Dataset ${DATASET} exists"
else
    print_info "Dataset ${DATASET} does not exist, creating..."
    bq mk --dataset \
        --location=us-central1 \
        --description="Bronze layer - Raw data from Chicago Data Portal" \
        ${PROJECT_ID}:${DATASET}
    print_success "Created dataset ${DATASET}"
fi

# Step 2: Create Table 1 - Raw Taxi Trips
print_section "Step 2: Create Table - raw_taxi_trips"

print_info "Creating raw_taxi_trips table..."

bq query --use_legacy_sql=false --project_id=${PROJECT_ID} <<EOF
CREATE TABLE IF NOT EXISTS \`${PROJECT_ID}.${DATASET}.raw_taxi_trips\`
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
  require_partition_filter = TRUE
);
EOF

print_success "Table raw_taxi_trips created"

# Step 3: Create Table 2 - Raw TNP Trips
print_section "Step 3: Create Table - raw_tnp_trips"

print_info "Creating raw_tnp_trips table..."

bq query --use_legacy_sql=false --project_id=${PROJECT_ID} <<EOF
CREATE TABLE IF NOT EXISTS \`${PROJECT_ID}.${DATASET}.raw_tnp_trips\`
(
  -- Primary key
  trip_id STRING NOT NULL,

  -- Trip details
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
  tip FLOAT64,
  additional_charges FLOAT64,
  trip_total FLOAT64,

  -- Rideshare-specific fields
  shared_trip_authorized BOOLEAN,
  trips_pooled INT64,

  -- Metadata
  _ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  _source_file STRING,
  _api_response_code INT64
)
PARTITION BY DATE(trip_start_timestamp)
CLUSTER BY pickup_centroid_latitude, pickup_centroid_longitude
OPTIONS(
  description = "Raw TNP (rideshare) trip data from Chicago Data Portal",
  require_partition_filter = TRUE
);
EOF

print_success "Table raw_tnp_trips created"

# Summary
print_section "Deployment Complete!"

echo -e "${GREEN}✅ BigQuery schemas deployed successfully!${NC}"
echo ""
echo "Summary:"
echo "  • Dataset: ${PROJECT_ID}:${DATASET}"
echo "  • Location: us-central1"
echo "  • Tables created:"
echo "    1. raw_taxi_trips (partitioned by trip_start_timestamp)"
echo "    2. raw_tnp_trips (partitioned by trip_start_timestamp)"
echo ""
echo "Verification:"
echo "  • View tables: bq ls ${PROJECT_ID}:${DATASET}"
echo "  • Check schema:"
echo "      bq show ${PROJECT_ID}:${DATASET}.raw_taxi_trips"
echo "      bq show ${PROJECT_ID}:${DATASET}.raw_tnp_trips"
echo ""
echo "Next steps:"
echo "  1. Deploy taxi extractor:"
echo "     cd ~/Desktop/chicago-bi-app/extractors/taxi"
echo "     ./deploy_with_auth.sh"
echo ""
echo "  2. Deploy TNP extractor:"
echo "     cd ~/Desktop/chicago-bi-app/extractors/tnp"
echo "     ./deploy_with_auth.sh"
echo ""
echo "  3. Run historical backfill:"
echo "     cd ~/Desktop/chicago-bi-app/backfill"
echo "     ./quarterly_backfill_q1_2020.sh all"
echo ""
echo -e "${BLUE}================================================${NC}"
echo ""
