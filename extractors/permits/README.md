# Chicago Building Permits Extractor

**Version:** 1.0.0
**Dataset:** Building Permits (ydr8-5enu)
**Status:** ✅ Production Ready
**Last Updated:** November 5, 2025

---

## Overview

This extractor fetches building permit data from the Chicago Data Portal and loads it into BigQuery. The dataset includes all building permits issued by the City of Chicago from 2006 to present, with detailed information about permit types, fees, work descriptions, and contractor information.

## Dataset Information

**Chicago Data Portal:**
- Dataset ID: `ydr8-5enu`
- API Endpoint: `https://data.cityofchicago.org/resource/ydr8-5enu.json`
- Update Frequency: Daily
- Data Range: 2006 to present

**BigQuery Table:**
- Project: `chicago-bi-app-msds-432-476520`
- Dataset: `raw_data`
- Table: `raw_building_permits`
- Partition: `issue_date` (daily)
- Clustering: None

## Data Schema

### Core Fields (64 total)
- **Identity:** id, permit_, row_id
- **Status:** permit_status, permit_milestone, permit_type, review_type
- **Dates:** application_start_date, issue_date, processing_time
- **Location:** street_number, street_direction, street_name, community_area, census_tract, ward
- **Coordinates:** xcoordinate, ycoordinate, latitude, longitude
- **Work Details:** work_type, work_description, permit_condition, reported_cost
- **Fees (12 fields):** building, zoning, other (paid, unpaid, waived, subtotal)
- **Fee Totals:** subtotal_paid, subtotal_unpaid, subtotal_waived, total_fee
- **Contacts (25 fields):** contact_1 through contact_5 (type, name, city, state, zipcode)
- **PIN:** pin_list

## Architecture

### Extraction Flow
```
Chicago Data Portal (Socrata API)
    ↓ (Concurrent paginated requests - 5 workers)
Cloud Storage (GCS Landing)
    ↓ (Newline-delimited JSON)
BigQuery (raw_building_permits)
    ↓ (Verification query)
Success / Failure Log
```

### Key Features
- **Concurrent Extraction:** 5 parallel workers with semaphore-based rate limiting
- **Automatic Pagination:** Handles unlimited records (50k batch size)
- **Retry Logic:** 3 attempts with 5-second backoff
- **Secret Management:** Socrata credentials from GCP Secret Manager
- **Data Quality:** Filters by issue_date for daily extractions
- **Idempotent:** Can safely re-run for same date (append mode)

## Configuration

### Environment Variables
| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `MODE` | Extraction mode | `incremental` | No |
| `START_DATE` | Issue date (YYYY-MM-DD) | Yesterday | No |
| `END_DATE` | End date (not used yet) | Yesterday | No |
| `OUTPUT_BUCKET` | GCS path | `gs://.../permits/` | No |
| `DATASET` | Dataset identifier | `permits` | No |

### Secrets Required
- `socrata-key-id` - Socrata API app token (username)
- `socrata-key-secret` - Socrata API secret (password)

## Deployment

### Build Image
```bash
cd extractors/permits
gcloud builds submit --config cloudbuild.yaml
```

Build time: ~1m 30s
Image: `gcr.io/chicago-bi-app-msds-432-476520/extractor-permits:v1.0.0`

### Create Cloud Run Job
```bash
gcloud run jobs create extractor-permits \
  --image=gcr.io/chicago-bi-app-msds-432-476520/extractor-permits:v1.0.0 \
  --region=us-central1 \
  --max-retries=0 \
  --task-timeout=3600 \
  --memory=2Gi \
  --cpu=1 \
  --service-account=cloud-run@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com \
  --set-env-vars="MODE=incremental,DATASET=permits"
```

### Execute Single Date
```bash
gcloud run jobs execute extractor-permits \
  --region=us-central1 \
  --update-env-vars="START_DATE=2024-11-01,DATASET=permits" \
  --wait
```

## Usage Examples

### Extract Today's Permits
```bash
gcloud run jobs execute extractor-permits --region=us-central1 --wait
```

### Extract Specific Date
```bash
gcloud run jobs execute extractor-permits \
  --region=us-central1 \
  --update-env-vars="START_DATE=2024-10-15" \
  --wait
```

### Verify Data Loaded
```sql
SELECT
  COUNT(*) as permits_count,
  DATE(issue_date) as date,
  COUNT(DISTINCT permit_type) as permit_types
FROM `chicago-bi-app-msds-432-476520.raw_data.raw_building_permits`
WHERE DATE(issue_date) = '2024-11-01'
GROUP BY date;
```

### Sample Query - Permits by Type
```sql
SELECT
  permit_type,
  COUNT(*) as count,
  AVG(total_fee) as avg_fee,
  AVG(processing_time) as avg_processing_days
FROM `chicago-bi-app-msds-432-476520.raw_data.raw_building_permits`
WHERE DATE(issue_date) BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY permit_type
ORDER BY count DESC
LIMIT 10;
```

## Testing

### Test Results (2024-11-01)
- **Records Extracted:** 107 permits
- **Execution Time:** ~45 seconds
- **Geographic Coverage:** 100% (all records have coordinates)
- **Status:** ✅ Success

### Data Quality Checks
```sql
-- Check for missing geographical data
SELECT
  COUNT(*) as total,
  COUNTIF(latitude IS NULL) as missing_lat,
  COUNTIF(longitude IS NULL) as missing_lon,
  COUNTIF(community_area IS NULL) as missing_community,
  COUNTIF(ward IS NULL) as missing_ward
FROM `chicago-bi-app-msds-432-476520.raw_data.raw_building_permits`
WHERE DATE(issue_date) = '2024-11-01';
```

## Performance Metrics

| Metric | Value |
|--------|-------|
| Avg Records/Day | ~100-300 permits |
| Batch Size | 50,000 records |
| Concurrent Workers | 5 |
| Timeout | 3600s (1 hour) |
| Memory | 2 GiB |
| CPU | 1 vCPU |
| Retry Attempts | 3 |
| Retry Delay | 5 seconds |

## Common Permit Types
1. **PERMIT - RENOVATION/ALTERATION** - Most common
2. **PERMIT - NEW CONSTRUCTION**
3. **PERMIT - ELECTRICAL**
4. **PERMIT - SIGNS**
5. **PERMIT - ELEVATOR EQUIPMENT**
6. **PERMIT - WRECKING/DEMOLITION**

## Troubleshooting

### No Data Extracted
- Check if permits were issued on that date (some dates have 0 permits)
- Verify date format is YYYY-MM-DD
- Check API status: https://data.cityofchicago.org/

### API Rate Limits
- Free tier: 1,000 requests/day
- With app token: 5,000 requests/hour
- Solution: Using app token with 5 concurrent workers

### Memory Issues
- Current allocation: 2 GiB (sufficient for daily loads)
- Increase if extracting large date ranges

## Data Notes

### Fee Fields
- Building fees, zoning fees, and other fees tracked separately
- Each has: paid, unpaid, waived, subtotal components
- Total fee = sum of all subtotals

### Geographic Data
- **State Plane Coordinates:** xcoordinate, ycoordinate (Illinois State Plane)
- **Lat/Lon:** Standard WGS84 coordinates
- **Administrative:** community_area (1-77), ward (1-50), census_tract

### Contact Information
- Up to 5 contacts per permit
- Typical contacts: owner, architect, contractor, applicant
- Each contact: type, name, city, state, zipcode

## Backfill Strategy

### Recommended Approach
1. **Daily Incremental:** Run daily for previous day
2. **Weekly Catch-up:** Run for any missed dates
3. **Historical Backfill:** Process by year or quarter

### Date Range Considerations
- Dataset available: 2006 to present
- Recommend starting from: 2020 (recent data)
- Total estimated records: ~500K+ permits

## Monitoring

### Success Indicators
- Extraction completes without errors
- Row count > 0 (unless legitimately no permits)
- Geographic fields populated (>95%)
- Verification query returns expected count

### Log Locations
- Cloud Run execution logs: GCP Console
- BigQuery job history: BigQuery Console

## Future Enhancements

### Potential Improvements
1. Add support for date range extraction (START_DATE to END_DATE)
2. Implement incremental updates (check existing dates)
3. Add data quality metrics logging
4. Create aggregated tables for faster queries
5. Add permit status change tracking

### Analytics Use Cases
- Permit processing time analysis
- Geographic distribution of construction
- Fee analysis by permit type
- Contractor activity tracking
- Construction trend analysis

---

## Quick Reference

**Test Single Date:**
```bash
gcloud run jobs execute extractor-permits --region=us-central1 \
  --update-env-vars="START_DATE=2024-11-01" --wait
```

**Verify:**
```bash
bq query --use_legacy_sql=false "
SELECT COUNT(*) FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_building_permits\`
WHERE DATE(issue_date) = '2024-11-01'
"
```

**View Logs:**
```bash
gcloud run jobs executions describe [EXECUTION_ID] --region=us-central1
```

---

**Maintainer:** Chicago BI App Team
**Contact:** Support via GitHub Issues
**License:** MIT
