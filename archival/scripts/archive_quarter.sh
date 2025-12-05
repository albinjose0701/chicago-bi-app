#!/bin/bash
#
# Chicago BI App - Quarterly Data Archival Script
#
# This script exports BigQuery data to GCS Coldline storage for long-term archival
# after analysis is complete. This allows you to delete BigQuery partitions and
# reduce storage costs while maintaining historical data for compliance.
#
# Usage:
#   ./archive_quarter.sh <YYYY-QX> [layer]
#
# Arguments:
#   YYYY-QX: Year and quarter (e.g., 2020-Q1, 2020-Q2)
#   layer: bronze, silver, gold, or "all" (default: all)
#
# Examples:
#   ./archive_quarter.sh 2020-Q1 bronze      # Archive Q1 2020 bronze layer
#   ./archive_quarter.sh 2020-Q1 all         # Archive Q1 2020 all layers
#   ./archive_quarter.sh 2020-Q1             # Archive Q1 2020 all layers
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
ARCHIVE_BUCKET="gs://chicago-bi-app-msds-432-476520-archive"
QUARTER="${1:-}"
LAYER="${2:-all}"

# Validate arguments
if [[ -z "$QUARTER" ]]; then
    echo -e "${RED}Error: Missing required argument YYYY-QX${NC}"
    echo ""
    echo "Usage: $0 <YYYY-QX> [layer]"
    echo ""
    echo "Examples:"
    echo "  $0 2020-Q1 bronze       # Archive Q1 2020 bronze layer"
    echo "  $0 2020-Q1 all          # Archive Q1 2020 all layers"
    echo "  $0 2020-Q1              # Archive Q1 2020 all layers"
    exit 1
fi

# Parse year and quarter
YEAR=$(echo "$QUARTER" | cut -d'-' -f1)
QUARTER_NUM=$(echo "$QUARTER" | cut -d'-' -f2 | sed 's/Q//')

# Validate year and quarter format
if ! [[ "$YEAR" =~ ^[0-9]{4}$ ]] || ! [[ "$QUARTER_NUM" =~ ^[1-4]$ ]]; then
    echo -e "${RED}Error: Invalid quarter format. Use YYYY-QX (e.g., 2020-Q1)${NC}"
    exit 1
fi

# Calculate date range for the quarter
case $QUARTER_NUM in
    1)
        START_DATE="${YEAR}-01-01"
        END_DATE="${YEAR}-03-31"
        ;;
    2)
        START_DATE="${YEAR}-04-01"
        END_DATE="${YEAR}-06-30"
        ;;
    3)
        START_DATE="${YEAR}-07-01"
        END_DATE="${YEAR}-09-30"
        ;;
    4)
        START_DATE="${YEAR}-10-01"
        END_DATE="${YEAR}-12-31"
        ;;
esac

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Chicago BI App - Quarterly Archival${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Quarter: ${GREEN}${QUARTER}${NC}"
echo -e "Date Range: ${GREEN}${START_DATE} to ${END_DATE}${NC}"
echo -e "Layer: ${GREEN}${LAYER}${NC}"
echo -e "Archive Bucket: ${GREEN}${ARCHIVE_BUCKET}${NC}"
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

# Export BigQuery table to GCS in Parquet format
export_table() {
    local dataset=$1
    local table=$2
    local date_column=$3
    local archive_path="${ARCHIVE_BUCKET}/${dataset}/${table}/${QUARTER}/*.parquet"

    print_info "Exporting ${dataset}.${table} for ${QUARTER}..."

    # Build query to filter data by quarter
    local query="SELECT * FROM \`${PROJECT_ID}.${dataset}.${table}\` WHERE ${date_column} BETWEEN '${START_DATE}' AND '${END_DATE}'"

    # Export to GCS using bq extract with Parquet format
    if bq extract \
        --project_id="${PROJECT_ID}" \
        --destination_format=PARQUET \
        --compression=SNAPPY \
        "${dataset}.${table}\$__PARTITIONS_SUMMARY__" \
        "${archive_path}" 2>/dev/null || \
       bq query \
        --project_id="${PROJECT_ID}" \
        --use_legacy_sql=false \
        --destination_table="${dataset}.${table}_temp_${QUARTER//-/_}" \
        --replace \
        "${query}" && \
       bq extract \
        --project_id="${PROJECT_ID}" \
        --destination_format=PARQUET \
        --compression=SNAPPY \
        "${dataset}.${table}_temp_${QUARTER//-/_}" \
        "${archive_path}"; then

        print_success "Exported ${dataset}.${table}"

        # Clean up temp table if created
        bq rm -f -t "${dataset}.${table}_temp_${QUARTER//-/_}" 2>/dev/null || true

        return 0
    else
        print_error "Failed to export ${dataset}.${table}"
        return 1
    fi
}

# Set GCS bucket lifecycle to Coldline for archival
set_coldline_lifecycle() {
    print_info "Setting Coldline storage class for archived data..."

    # Create lifecycle configuration
    cat > /tmp/archive_lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "SetStorageClass",
          "storageClass": "COLDLINE"
        },
        "condition": {
          "age": 0,
          "matchesPrefix": ["bronze/", "silver/", "gold/"]
        }
      }
    ]
  }
}
EOF

    if gsutil lifecycle set /tmp/archive_lifecycle.json "${ARCHIVE_BUCKET}"; then
        print_success "Coldline lifecycle policy set"
        rm /tmp/archive_lifecycle.json
        return 0
    else
        print_error "Failed to set lifecycle policy"
        rm /tmp/archive_lifecycle.json
        return 1
    fi
}

# Archive bronze layer
archive_bronze() {
    print_section "Archiving Bronze Layer (${QUARTER})"

    export_table "raw_data" "raw_taxi_trips" "DATE(trip_start_timestamp)"
    export_table "raw_data" "raw_tnp_permits" "issue_date"
    # Add more tables as needed
    # export_table "raw_data" "raw_covid_cases" "week_start"
    # export_table "raw_data" "raw_building_permits" "issue_date"

    print_success "Bronze layer archival completed"
}

# Archive silver layer
archive_silver() {
    print_section "Archiving Silver Layer (${QUARTER})"

    # Example - adjust based on your actual silver layer tables
    # export_table "cleaned_data" "cleaned_taxi_trips" "DATE(trip_start_timestamp)"
    # export_table "cleaned_data" "cleaned_tnp_permits" "issue_date"

    print_info "Silver layer tables not yet defined - skipping"
}

# Archive gold layer
archive_gold() {
    print_section "Archiving Gold Layer (${QUARTER})"

    # Example - adjust based on your actual gold layer tables
    # export_table "analytics" "daily_trip_metrics" "date"
    # export_table "analytics" "monthly_revenue_summary" "month"

    print_info "Gold layer tables not yet defined - skipping"
}

# Delete archived partitions from BigQuery
delete_archived_partitions() {
    local dataset=$1
    local table=$2
    local date_column=$3

    print_info "Deleting archived partitions from ${dataset}.${table}..."

    # Build delete query
    local delete_query="DELETE FROM \`${PROJECT_ID}.${dataset}.${table}\` WHERE ${date_column} BETWEEN '${START_DATE}' AND '${END_DATE}'"

    if bq query \
        --project_id="${PROJECT_ID}" \
        --use_legacy_sql=false \
        "${delete_query}"; then
        print_success "Deleted archived partitions from ${dataset}.${table}"
        return 0
    else
        print_error "Failed to delete partitions from ${dataset}.${table}"
        return 1
    fi
}

# Main archival workflow
run_archival() {
    print_section "Pre-Flight Checks"

    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not found"
        exit 1
    fi
    print_success "gcloud CLI found"

    # Check if bq is installed
    if ! command -v bq &> /dev/null; then
        print_error "bq CLI not found"
        exit 1
    fi
    print_success "bq CLI found"

    # Check if gsutil is installed
    if ! command -v gsutil &> /dev/null; then
        print_error "gsutil CLI not found"
        exit 1
    fi
    print_success "gsutil CLI found"

    # Check if archive bucket exists
    if ! gsutil ls "${ARCHIVE_BUCKET}" &> /dev/null; then
        print_error "Archive bucket does not exist: ${ARCHIVE_BUCKET}"
        exit 1
    fi
    print_success "Archive bucket exists"

    # Set Coldline lifecycle
    set_coldline_lifecycle

    # Archive based on layer selection
    case $LAYER in
        bronze)
            archive_bronze
            ;;
        silver)
            archive_silver
            ;;
        gold)
            archive_gold
            ;;
        all)
            archive_bronze
            archive_silver
            archive_gold
            ;;
        *)
            print_error "Invalid layer: ${LAYER}"
            echo "Valid options: bronze, silver, gold, all"
            exit 1
            ;;
    esac

    print_section "Archival Summary"

    # Calculate storage savings
    print_info "Calculating storage savings..."

    echo ""
    echo "Archived data location:"
    echo "  ${ARCHIVE_BUCKET}/"
    echo ""
    echo "To list archived files:"
    echo "  gsutil ls -lh ${ARCHIVE_BUCKET}/raw_data/raw_taxi_trips/${QUARTER}/"
    echo ""
    echo "To calculate size:"
    echo "  gsutil du -sh ${ARCHIVE_BUCKET}/raw_data/raw_taxi_trips/${QUARTER}/"
    echo ""
}

# Confirmation prompt
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will export ${QUARTER} data to Coldline storage.${NC}"
echo -e "${YELLOW}   Coldline storage cost: ~\$0.004/GB/month (very cheap)${NC}"
echo ""
echo -e "${RED}⚠️  IMPORTANT: Do NOT delete BigQuery partitions until export is verified!${NC}"
echo ""
read -p "Continue with archival for ${QUARTER}? (yes/no): " confirmation

if [[ "$confirmation" != "yes" ]]; then
    print_info "Archival cancelled by user"
    exit 0
fi

# Run the archival
run_archival

print_section "Next Steps"

echo "1. Verify archived data:"
echo "   gsutil ls -lh ${ARCHIVE_BUCKET}/raw_data/raw_taxi_trips/${QUARTER}/"
echo ""
echo "2. Calculate total archived size:"
echo "   gsutil du -sh ${ARCHIVE_BUCKET}/"
echo ""
echo "3. OPTIONAL - Delete BigQuery partitions to save costs:"
echo "   # ⚠️  ONLY after verifying archive is complete!"
echo "   ./delete_archived_partitions.sh ${QUARTER}"
echo ""
echo "4. To restore archived data (if needed):"
echo "   bq load --source_format=PARQUET raw_data.raw_taxi_trips ${ARCHIVE_BUCKET}/raw_data/raw_taxi_trips/${QUARTER}/*.parquet"
echo ""

print_success "Quarterly archival script completed!"
