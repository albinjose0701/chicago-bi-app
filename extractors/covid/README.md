# Chicago COVID-19 Cases Extractor

**Version:** 1.0.0
**Dataset:** COVID-19 Cases, Tests, and Deaths by ZIP Code (yhhz-zm2v)
**Status:** ✅ Production Ready
**Last Updated:** November 5, 2025

---

## Overview

This extractor fetches COVID-19 case, testing, and mortality data aggregated by ZIP code and week from the Chicago Data Portal and loads it into BigQuery. The dataset provides weekly and cumulative metrics for tracking pandemic trends across Chicago neighborhoods.

## Dataset Information

**Chicago Data Portal:**
- Dataset ID: `yhhz-zm2v`
- API Endpoint: `https://data.cityofchicago.org/resource/yhhz-zm2v.json`
- Update Frequency: Weekly
- Data Range: March 2020 to May 2024 (historical)
- Data Source: Illinois National Electronic Disease Surveillance System

**BigQuery Table:**
- Project: `chicago-bi-app-msds-432-476520`
- Dataset: `raw_data`
- Table: `raw_covid19_cases_by_zip`
- Partition: `week_start` (daily granularity)
- Clustering: `zip_code`

## Data Schema

### Core Fields (20 total)
- **Geographic & Temporal:** zip_code, week_number, week_start, week_end, population
- **Case Metrics:** cases_weekly, cases_cumulative, case_rate_weekly, case_rate_cumulative
- **Testing Data:** tests_weekly, tests_cumulative, test_rate_weekly, test_rate_cumulative
- **Positivity:** percent_tested_positive_weekly, percent_tested_positive_cumulative
- **Mortality:** deaths_weekly, deaths_cumulative, death_rate_weekly, death_rate_cumulative
- **Identity:** row_id

### Data Organization
- **By Week:** Data aggregated by week (Sunday to Saturday)
- **By ZIP Code:** Chicago residential ZIP codes (~59 ZIPs)
- **Rates:** Per 100,000 population
- **Privacy:** Counts <5 suppressed (shown as NULL)

## Architecture

### Extraction Flow
```
Chicago Data Portal (Socrata API)
    ↓ (Concurrent paginated requests - 5 workers)
Cloud Storage (GCS Landing)
    ↓ (Newline-delimited JSON)
BigQuery (raw_covid19_cases_by_zip)
    ↓ (Verification query)
Success / Failure Log
```

### Key Features
- **Concurrent Extraction:** 5 parallel workers with semaphore-based rate limiting
- **Automatic Pagination:** Handles unlimited records (50k batch size)
- **Retry Logic:** 3 attempts with 5-second backoff
- **Secret Management:** Socrata credentials from GCP Secret Manager
- **Data Quality:** Filters by week_start for weekly extractions
- **Idempotent:** Can safely re-run for same week (append mode)

## Configuration

### Environment Variables
| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `MODE` | Extraction mode | `incremental` | No |
| `START_DATE` | Week start date (YYYY-MM-DD) | Last week | No |
| `END_DATE` | End date (not used yet) | Yesterday | No |
| `OUTPUT_BUCKET` | GCS path | `gs://.../covid19/` | No |
| `DATASET` | Dataset identifier | `covid` | No |

### Secrets Required
- `socrata-key-id` - Socrata API app token (username)
- `socrata-key-secret` - Socrata API secret (password)

## Deployment

### Build Image
```bash
cd extractors/covid
gcloud builds submit --config cloudbuild.yaml
```

Build time: ~1m 25s
Image: `gcr.io/chicago-bi-app-msds-432-476520/extractor-covid:v1.0.0`

### Create Cloud Run Job
```bash
gcloud run jobs create extractor-covid \
  --image=gcr.io/chicago-bi-app-msds-432-476520/extractor-covid:v1.0.0 \
  --region=us-central1 \
  --max-retries=0 \
  --task-timeout=3600 \
  --memory=2Gi \
  --cpu=1 \
  --service-account=cloud-run@chicago-bi-app-msds-432-476520.iam.gserviceaccount.com \
  --set-env-vars="MODE=incremental,DATASET=covid"
```

### Execute Single Week
```bash
gcloud run jobs execute extractor-covid \
  --region=us-central1 \
  --update-env-vars="START_DATE=2024-01-21,DATASET=covid" \
  --wait
```

## Usage Examples

### Extract Specific Week
```bash
gcloud run jobs execute extractor-covid \
  --region=us-central1 \
  --update-env-vars="START_DATE=2024-01-21" \
  --wait
```

### Verify Data Loaded
```sql
SELECT
  COUNT(*) as zip_count,
  DATE(week_start) as week,
  SUM(cases_weekly) as total_cases,
  SUM(deaths_weekly) as total_deaths,
  AVG(percent_tested_positive_weekly) as avg_positivity
FROM `chicago-bi-app-msds-432-476520.raw_data.raw_covid19_cases_by_zip`
WHERE DATE(week_start) = '2024-01-21'
GROUP BY week;
```

### Sample Query - Weekly Trends
```sql
SELECT
  DATE(week_start) as week,
  SUM(cases_weekly) as cases,
  SUM(tests_weekly) as tests,
  AVG(percent_tested_positive_weekly) as positivity_rate,
  SUM(deaths_weekly) as deaths
FROM `chicago-bi-app-msds-432-476520.raw_data.raw_covid19_cases_by_zip`
WHERE DATE(week_start) BETWEEN '2023-01-01' AND '2024-01-01'
GROUP BY week
ORDER BY week;
```

### Sample Query - ZIP Code Analysis
```sql
SELECT
  zip_code,
  population,
  SUM(cases_cumulative) as total_cases,
  SUM(deaths_cumulative) as total_deaths,
  ROUND(SUM(deaths_cumulative) * 100.0 / NULLIF(SUM(cases_cumulative), 0), 2) as mortality_rate
FROM `chicago-bi-app-msds-432-476520.raw_data.raw_covid19_cases_by_zip`
WHERE DATE(week_start) BETWEEN '2020-03-01' AND '2024-05-31'
GROUP BY zip_code, population
HAVING SUM(cases_cumulative) > 0
ORDER BY total_cases DESC
LIMIT 20;
```

## Testing

### Test Results (Week of 2024-01-21)
- **Records Extracted:** 59 records (59 ZIP codes)
- **Execution Time:** ~30 seconds
- **Geographic Coverage:** All Chicago residential ZIP codes
- **Status:** ✅ Success

### Data Quality Checks
```sql
-- Check data completeness
SELECT
  COUNT(*) as total_records,
  COUNT(DISTINCT zip_code) as zip_codes,
  COUNTIF(population IS NOT NULL) as has_population,
  COUNTIF(cases_weekly IS NOT NULL) as has_cases,
  COUNTIF(tests_weekly IS NOT NULL) as has_tests
FROM `chicago-bi-app-msds-432-476520.raw_data.raw_covid19_cases_by_zip`
WHERE DATE(week_start) = '2024-01-21';
```

## Performance Metrics

| Metric | Value |
|--------|-------|
| Records/Week | ~59 (one per ZIP) |
| Batch Size | 50,000 records |
| Concurrent Workers | 5 |
| Timeout | 3600s (1 hour) |
| Memory | 2 GiB |
| CPU | 1 vCPU |
| Retry Attempts | 3 |
| Retry Delay | 5 seconds |

## Data Interpretation

### Privacy Protections
**Suppression Rules:**
- Counts <5 are suppressed (NULL) for privacy
- Applies to cases, tests, and deaths
- Both weekly and cumulative may be suppressed

### Rate Calculations
- **Case Rate:** Cases per 100,000 population
- **Test Rate:** Tests per 100,000 population
- **Death Rate:** Deaths per 100,000 population

### Week Definitions
- **Week Start:** Sunday at 00:00:00
- **Week End:** Saturday at 23:59:59
- **Week Number:** 1-52 (or 53 in some years)

## Understanding NULL Values

### Expected NULLs
1. **Privacy Suppression:** <5 cases/deaths/tests
2. **No Activity:** No cases/tests/deaths that week
3. **ZIP Code Issues:** Non-residential ZIPs (60666 - O'Hare)
4. **Data Not Available:** Some metrics discontinued after certain dates

### Example from Test Data (2024-01-21)
```
60827: population=28,577, cases_weekly=2, deaths=NULL (suppressed)
60666: population=NULL (O'Hare - non-residential)
60603: population=1,174, cases=NULL (suppressed or none)
```

## Troubleshooting

### No Data Extracted
- Check if week_start is a Sunday
- Verify date is within dataset range (2020-03 to 2024-05)
- Dataset may be historical only (no new updates after May 2024)

### Unexpected NULL Values
- **Expected:** Privacy suppression for low counts
- **Expected:** Some ZIP codes have NULL population
- **Check:** Verify data exists for that week on data portal

### API Rate Limits
- Free tier: 1,000 requests/day
- With app token: 5,000 requests/hour
- COVID data is small (~59 records/week), rate limits not an issue

## Data Timeline

### Key Periods
- **March 2020:** Pandemic begins, data collection starts
- **2020 Q2:** Peak first wave
- **2021:** Vaccination rollout begins
- **2022:** Omicron surge
- **2023-2024:** Endemic phase
- **May 2024:** Dataset marked as historical

### Update Status
⚠️ **Note:** This dataset appears to be historical only. Last update: May 23, 2024.
No new data expected after this date.

## Backfill Strategy

### Historical Data Range
- **Start Date:** 2020-03-01 (first week of pandemic)
- **End Date:** 2024-05-31 (last available week)
- **Total Weeks:** ~220 weeks
- **Total Records:** ~13,000 records (59 ZIPs × 220 weeks)

### Recommended Approach
```bash
# Extract by year quarters for manageability
# Q1 2020 (partial - starting March)
# Q2 2020 through Q2 2024
# Each extraction: ~780 records (59 ZIPs × 13 weeks)
```

### Backfill Script Example
```bash
#!/bin/bash
# Extract weekly data for Q1 2024
for week_start in 2024-01-07 2024-01-14 2024-01-21 2024-01-28 \
                  2024-02-04 2024-02-11 2024-02-18 2024-02-25 \
                  2024-03-03 2024-03-10 2024-03-17 2024-03-24 2024-03-31
do
  echo "Extracting week starting $week_start"
  gcloud run jobs execute extractor-covid \
    --region=us-central1 \
    --update-env-vars="START_DATE=$week_start" \
    --wait
  sleep 5  # Rate limiting
done
```

## Monitoring

### Success Indicators
- Extraction completes without errors
- Row count = ~59 (one per ZIP code)
- At least some non-NULL case/test/death data
- Verification query returns expected count

### Log Locations
- Cloud Run execution logs: GCP Console
- BigQuery job history: BigQuery Console

## Use Cases

### Public Health Analysis
1. **Pandemic Timeline:** Weekly case trends across Chicago
2. **Geographic Hotspots:** Identify high-case ZIP codes
3. **Testing Adequacy:** Test positivity rates by area
4. **Mortality Tracking:** Death rates by neighborhood

### Data Science Projects
1. **Predictive Modeling:** Forecast case trends
2. **Correlation Analysis:** Relate to socioeconomic data
3. **Geospatial Analysis:** Map pandemic spread
4. **Time Series:** Identify waves and surges

## Future Enhancements

### Potential Improvements
1. Add support for date range extraction (multiple weeks)
2. Join with ZIP code demographic data
3. Calculate 7-day rolling averages
4. Create aggregated city-wide metrics
5. Build alerting for unusual patterns (if data resumes)

---

## Quick Reference

**Test Single Week:**
```bash
gcloud run jobs execute extractor-covid --region=us-central1 \
  --update-env-vars="START_DATE=2024-01-21" --wait
```

**Verify:**
```bash
bq query --use_legacy_sql=false "
SELECT COUNT(*) FROM \`chicago-bi-app-msds-432-476520.raw_data.raw_covid19_cases_by_zip\`
WHERE DATE(week_start) = '2024-01-21'
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

**⚠️ Data Status:** Historical dataset - Last updated May 2024
