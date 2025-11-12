#!/bin/bash
#
# Load Chicago Boundary GeoJSON files to BigQuery
# Creates reference_data dataset with GEOGRAPHY columns
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_ID="chicago-bi-app-msds-432-476520"
DATASET="reference_data"
LOCATION="us-central1"
SOURCE_DIR="/Users/albin/Downloads/Geographical Reference Files"

echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Chicago Boundary Files - BigQuery Loader${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""

# Create reference_data dataset
echo -e "${YELLOW}Creating reference_data dataset...${NC}"
bq mk --dataset --location=${LOCATION} --project_id=${PROJECT_ID} ${DATASET} 2>/dev/null || echo "Dataset already exists"
echo ""

# Boundary file definitions
# Format: source_filename:table_name:description
declare -a BOUNDARIES=(
  "Boundaries_-_Community_Areas_20251030.geojson:community_area_boundaries:Community Areas (77 areas)"
  "Boundaries_-_ZIP_Codes_20251030.geojson:zip_code_boundaries:ZIP Code Boundaries (60+ ZIPs)"
  "Neighborhoods_2012b_20251030.geojson:neighborhood_boundaries:Neighborhood Boundaries (200+ neighborhoods)"
)

for boundary in "${BOUNDARIES[@]}"; do
  SOURCE_FILE="${boundary%%:*}"
  REST="${boundary#*:}"
  TABLE_NAME="${REST%%:*}"
  DESCRIPTION="${REST#*:}"

  echo -e "${BLUE}Loading: ${DESCRIPTION}${NC}"
  echo "  Source: ${SOURCE_FILE}"
  echo "  Table: ${TABLE_NAME}"

  # Check if source file exists
  SOURCE_PATH="${SOURCE_DIR}/${SOURCE_FILE}"
  if [ ! -f "${SOURCE_PATH}" ]; then
    echo -e "  ${YELLOW}⚠ File not found, skipping${NC}"
    continue
  fi

  # Check if file has content
  if [ ! -s "${SOURCE_PATH}" ]; then
    echo -e "  ${YELLOW}⚠ Empty file, skipping${NC}"
    continue
  fi

  # Convert FeatureCollection to newline-delimited JSON and fix field names
  echo "  Converting to newline-delimited format..."
  TEMP_FILE="${TABLE_NAME}_ndjson.json"
  # Remove ':' prefix from property field names (e.g., :created_at -> created_at)
  if jq -c '.features[] | .properties |= with_entries(.key |= ltrimstr(":"))' "${SOURCE_PATH}" > "${TEMP_FILE}" 2>/dev/null; then
    echo -e "  ${GREEN}✓ Converted${NC}"
  else
    echo -e "  ${YELLOW}⚠ Conversion failed, skipping${NC}"
    continue
  fi

  # Load to BigQuery with geography
  echo "  Loading to BigQuery..."
  bq load --replace \
    --source_format=NEWLINE_DELIMITED_JSON \
    --autodetect \
    --json_extension=GEOJSON \
    --project_id=${PROJECT_ID} \
    ${DATASET}.${TABLE_NAME} \
    "${TEMP_FILE}"

  if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓ Loaded to ${DATASET}.${TABLE_NAME}${NC}"
    rm -f "${TEMP_FILE}"
  else
    echo -e "  ${YELLOW}⚠ Load failed${NC}"
  fi

  echo ""
done

echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Boundary Loading Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "  1. Run: ./02_create_crosswalk_tables.sh"
echo "  2. Verify: bq ls ${DATASET}"
echo "  3. Query: bq query 'SELECT COUNT(*) FROM ${DATASET}.community_area_boundaries'"
echo ""
