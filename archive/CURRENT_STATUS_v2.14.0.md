# Chicago BI App - Current Status Documentation v2.14.0

**Last Updated:** November 13, 2025
**Status:** ✅ Production Ready - Gold Layer Complete

---

## 📊 Data Pipeline Status Overview

### Complete Data Layers

**Raw Layer (raw_data):** 202.7M records across 8 datasets
- Taxi Trips: 32.3M trips (2020-2025, 2,101 days)
- TNP Trips: 170M trips (2020-2022, 1,096 days)
- Building Permits: 211,894 permits (2020-2025, 99.7% coverage)
- COVID-19 Cases: 13,132 records (219 weeks, 60 ZIP codes)
- CCVI: 135 records (vulnerability indices)
- Public Health: 77 records (community area statistics)

**Bronze Layer (bronze_data):** 168M quality-filtered records ✅
- **Taxi Trips:** 25.3M (21.6% filtered for quality)
  - Valid coordinates within Chicago bounds (41.6-42.1°N, -87.95 to -87.5°W)
  - Trip miles ≤ 500, fare ≤ $1K, duration ≤ 100K seconds

- **TNP Trips:** 142.5M (16.2% filtered for quality)
  - Same quality filters as taxi trips
  - 100% already within Chicago geographic bounds

- **COVID-19 Cases:** 13,132 (100% retained)
- **Building Permits:** 207,984 (1.8% filtered)
- **CCVI:** 135 (100% retained)
- **Public Health:** 77 (100% retained)

**Quality Improvement:** 17% filtering rate (34.5M invalid records removed)

**Reference Data (reference_data):** 7 spatial tables
- 3 boundary files (77 Community Areas, 59 ZIP Codes, 98 Neighborhoods)
- 4 crosswalk tables (272+ spatial relationships with overlap percentages)

**Silver Layer (silver_data):** 168M+ enriched records ✅
- **Trips Enriched:** 167.8M (25.3M taxi + 142.5M TNP combined)
  - Spatial enrichment: 100% ZIP match, 99.99% neighborhood match
  - Business logic: 14.2M airport trips identified (19.9% taxi, 6.4% TNP)
  - Partitioned by trip_date, clustered by source/community areas

- **Permits Enriched:** 207,984
  - Spatial enrichment: 99.2-99.6% ZIP and neighborhood match
  - Derived fields: permit_year, permit_month
  - Partitioned by issue_date, clustered by community area/type

- **COVID Weekly Historical:** 13,132 (219 weeks × 60 ZIPs)
  - All pandemic waves with risk categorization (High/Medium/Low)
  - Peak: Dec 26, 2021 (1,872 cases/100K, Omicron surge)
  - Partitioned by week_start, clustered by zip_code/risk

- **CCVI High Risk:** 39 (26 Community Areas + 13 ZIPs)
  - High vulnerability areas only (score 47.9-63.7)

**Gold Layer (gold_data):** 52M+ aggregated records ✅
- **Trip Aggregations:** 39.4M records (35.4M hourly + 4M daily)
  - Partitioned by trip_date, clustered by pickup_zip, dropoff_zip

- **Route Pairs:** 10 rows (top 10 most popular routes with revenue)

- **Permits ROI:** 59 rows (one per ZIP code, 192,435 permits aggregated)

- **COVID Hotspots:** 13,132 rows (60 ZIPs × 219 weeks)
  - Complex risk scoring: Mobility + Epidemiological + CCVI vulnerability
  - Time series tracking (March 2020 - May 2024)

- **Loan Targets:** 60 rows (35 eligible ZIPs from 60 total)
  - Weighted per_capita_income via spatial crosswalk
  - 4-component eligibility index

- **Forecasts:** 1,650 rows (55 ZIPs × 30 days)
  - Prophet-ready structure with confidence intervals

---

## 🏗️ Bronze Layer Details

### Purpose
Quality-filtered data with geographic bounds validation and basic data type corrections.

### Tables Created (6)

1. **bronze_taxi_trips** - 25.3M rows
   - Geographic bounds: Chicago proper only
   - Trip validation: miles ≤ 500, fare ≤ $1K, duration ≤ 100K sec
   - 21.6% filtering rate from raw data

2. **bronze_tnp_trips** - 142.5M rows
   - Same validation as taxi
   - 16.2% filtering rate
   - All records already within Chicago bounds

3. **bronze_covid_cases** - 13,132 rows
   - All required fields validated
   - 100% retention (all records valid)

4. **bronze_building_permits** - 207,984 rows
   - Both lat & lon must be present
   - Coordinates within Chicago bounds
   - 1.8% filtering rate

5. **bronze_ccvi** - 135 rows
   - All required fields validated
   - 100% retention

6. **bronze_public_health** - 77 rows
   - Per capita income validated
   - 100% retention

### Quality Improvements
- **Total Filtered:** 34.5M records (17% of 202.7M raw)
- **Geographic Validation:** Chicago bounds (41.6-42.1°N, -87.95 to -87.5°W)
- **Optimization:** Smart filtering (90% faster - 59 sec vs 5-10 min)
- **Partitioning:** All tables partitioned/clustered for performance

---

## 🥈 Silver Layer Details

### Purpose
Spatially enriched data with business logic and derived fields ready for analytics.

### Tables Created (4)

1. **silver_trips_enriched** - 167.8M rows
   - **Spatial Enrichment:** ST_CONTAINS with 4 boundary types
     - ZIP code: 100% match rate
     - Neighborhood: 99.99% match rate
     - Community Area: 99.99% match rate
     - Ward: 99.99% match rate

   - **Business Logic:**
     - Airport trips identified: 14.2M total (8.5% of all trips)
       - Taxi: 19.9% airport trips (5M trips)
       - TNP: 6.4% airport trips (9.2M trips)
     - O'Hare Airport coordinates: (41.9742, -87.9073)
     - Midway Airport coordinates: (41.7868, -87.7522)

   - **Performance:** 8-minute spatial join on 168M records
   - **Partitioning:** trip_date (DATE)
   - **Clustering:** trip_source, pickup_community_area, dropoff_community_area

2. **silver_permits_enriched** - 207,984 rows
   - **Spatial Enrichment:**
     - ZIP code match: 99.2%
     - Neighborhood match: 99.6%
     - Community Area match: 99.4%

   - **Derived Fields:**
     - permit_year (EXTRACT YEAR from issue_date)
     - permit_month (EXTRACT MONTH from issue_date)

   - **Partitioning:** issue_date (DATE)
   - **Clustering:** community_area, permit_type

3. **silver_covid_weekly_historical** - 13,132 rows
   - **Time Series:** All 219 weeks (March 2020 - May 2024)
   - **Coverage:** 60 ZIP codes

   - **Pandemic Waves Documented:**
     - First Wave: Spring 2020
     - Fall 2020 Surge: Oct-Dec 2020 (170 high-risk ZIP-weeks)
     - Delta Variant: Aug-Dec 2021
     - Omicron Peak: Dec 26, 2021 (57 ZIPs at High risk, 1,872 cases/100K avg)
     - Endemic Phase: 2023-2024 (mostly Low risk)

   - **Risk Categorization:**
     - High: case_rate_weekly > 400 per 100K
     - Medium: 200-400 per 100K
     - Low: < 200 per 100K

   - **Partitioning:** week_start (DATE)
   - **Clustering:** zip_code, risk_category

4. **silver_ccvi_high_risk** - 39 rows
   - **Filtering:** Only high vulnerability areas (CCVI score > 40)
   - **Coverage:**
     - 26 Community Areas
     - 13 ZIP codes
   - **Score Range:** 47.9 to 63.7 (out of 100)

### Spatial Join Performance
- **Total Records Processed:** 168M
- **Joins Per Record:** 4 (ZIP, Neighborhood, Community Area, Ward)
- **Total Join Operations:** 672M
- **Execution Time:** 8 minutes
- **Match Rates:** 99.99%+ across all boundaries

---

## 🥇 Gold Layer Details

### Purpose
Analytics-ready aggregations with complex risk scoring and derived business metrics.

### Tables Created (7)

1. **gold_taxi_hourly_by_zip** - 35.4M rows
   - **Aggregation:** Hourly trip counts by pickup/dropoff ZIP pairs
   - **Date Range:** 2020-01-01 to 2025-10-01
   - **Metrics:** trip_count, avg_miles, avg_fare
   - **Partitioning:** trip_date (DATE)
   - **Clustering:** pickup_zip, dropoff_zip, trip_hour
   - **Use Cases:** Peak hour analysis, time-of-day pricing

2. **gold_taxi_daily_by_zip** - 4M rows
   - **Aggregation:** Daily trip counts by pickup/dropoff ZIP pairs
   - **Metrics:** trip_count, avg_miles, avg_fare
   - **Partitioning:** trip_date (DATE)
   - **Clustering:** pickup_zip, dropoff_zip
   - **Use Cases:** Daily trends, seasonal patterns

3. **gold_route_pairs** - 10 rows
   - **Aggregation:** Top 10 most popular routes (all-time)
   - **Metrics:** trip_count, avg_fare, avg_miles, total_revenue, rank
   - **Use Cases:** Route optimization, high-value corridor identification

4. **gold_permits_roi** - 59 rows
   - **Aggregation:** Building permits by ZIP code
   - **Total Permits:** 192,435
   - **Metrics:** total_permits, total_permit_value, avg_permit_value
   - **Use Cases:** Construction activity hotspots, investment patterns

5. **gold_covid_hotspots** - 13,132 rows ⭐ COMPLEX
   - **Coverage:** 60 ZIPs × 219 weeks (March 2020 - May 2024)

   - **Risk Score Formulas:**
     ```
     1. Mobility Risk Rate:
        = 0.7 × norm_trips_from_zip
        + 1.0 × norm_trips_to_zip
        + 1.5 × norm_pooled_trips_to_zip

     2. Epidemiological Risk:
        = 0.7 × norm_cases_weekly
        + 0.3 × norm_tests_weekly

     3. CCVI Adjustment:
        = 1 + (0.5 × norm_ccvi_score)
        Range: 1.0 (low vulnerability) to 1.5 (high vulnerability)

     4. Adjusted Risk Score:
        = (Mobility Risk + Epi Risk) × CCVI Adjustment
     ```

   - **Metrics:** case_rate_weekly, total_trips, mobility_risk_rate, epi_risk, ccvi_adjustment, adjusted_risk_score
   - **Partitioning:** week_start (DATE)
   - **Clustering:** zip_code, risk_category
   - **Use Cases:** Pandemic impact analysis, mobility-COVID correlation

6. **gold_loan_targets** - 60 rows ⭐ COMPLEX
   - **Purpose:** Illinois Small Business Emergency Loan Fund Delta eligibility
   - **Eligible ZIPs:** 35 (58.3%)

   - **Index Formulas:**
     ```
     Eligibility Index =
       0.5 × inverted_income_index +
       0.4 × inverted_new_construction_index +
       0.1 × inverted_permits_index -
       0.03 × permit_value_index

     is_loan_eligible = per_capita_income < $30,000
     ```

   - **Weighted Income Calculation:**
     - Per capita income mapped from Community Area to ZIP
     - Uses spatial crosswalk with overlap percentages
     - Formula: SUM(income × pct_of_zip) / SUM(pct_of_zip)

   - **Metrics:** population, per_capita_income, eligibility_index, is_loan_eligible
   - **Use Cases:** Small business loan targeting, economic development

7. **gold_forecasts** - 1,650 rows
   - **Coverage:** 55 ZIPs × 30 days forward
   - **Forecast Range:** 2025-10-02 to 2025-10-31
   - **Current Status:** Sample data (7-day moving average)
   - **Model:** prophet_sample (placeholder for actual Prophet ML)
   - **Metrics:** predicted_trip_count, lower_bound, upper_bound, model_name
   - **Use Cases:** Demand forecasting, capacity planning, anomaly detection

### Gold Layer Performance
- **Total Execution Time:** ~3 minutes for all 7 tables
- **Data Scanned:** ~20 GB
- **Estimated Cost:** $0.10 per full refresh
- **Query Performance:** 95%+ scan reduction with partitioning, 10-100x improvement with clustering

---

## 🚀 Key Achievements Summary

### Data Ingestion (v2.0-v2.9)
- ✅ 4 extractors deployed (Taxi, TNP, Building Permits, COVID-19)
- ✅ 202.7M raw records ingested
- ✅ 5+ years historical data (2020-2025)
- ✅ 99.7%+ backfill coverage
- ✅ Network-resilient execution (multi-hour backfills successful)

### Data Quality (v2.12)
- ✅ 17% data quality improvement
- ✅ Geographic bounds validation
- ✅ Smart filtering optimization (90% faster)
- ✅ 168M clean records from 202.7M raw

### Spatial Enrichment (v2.11, v2.13)
- ✅ 7 reference tables (boundaries + crosswalks)
- ✅ 100% ZIP match, 99.99% neighborhood match
- ✅ 8-minute spatial join on 168M records
- ✅ BigQuery Geography instead of Cloud SQL (cost savings)

### Analytics Aggregations (v2.14)
- ✅ 7 Gold tables with 52M+ aggregated records
- ✅ Complex risk scoring (3-factor COVID risk model)
- ✅ Loan eligibility with 4-component index
- ✅ Time series analysis (219 weeks COVID tracking)
- ✅ 3-minute total execution time

---

## 📁 Project Files Structure (Updated)

```
chicago-bi-app/
├── extractors/                        # 4 Cloud Run extractors
│   ├── taxi/                          # Taxi trips (wrvz-psew, m6dm-c72p 2024+)
│   ├── tnp/                           # TNP rideshare (m6dm-c72p)
│   ├── permits/                       # Building permits (ydr8-5enu)
│   └── covid/                         # COVID-19 (yhhz-zm2v)
│
├── boundaries/                        # Boundary files & crosswalks
│   ├── 01_create_zip_boundaries.sql
│   ├── 02_create_neighborhood_boundaries.sql
│   ├── 03_create_community_area_boundaries.sql
│   └── 04_create_crosswalk_tables.sql
│
├── bronze-layer/                      # Quality filtering (v2.12)
│   ├── 01_bronze_taxi_trips.sql
│   ├── 02_bronze_tnp_trips.sql
│   ├── 03_bronze_covid_cases.sql
│   ├── 04_bronze_building_permits.sql
│   ├── 05_bronze_ccvi.sql
│   ├── 06_bronze_public_health.sql
│   └── README.md
│
├── silver-layer/                      # Spatial enrichment (v2.13)
│   ├── 01_silver_trips_enriched.sql
│   ├── 02_silver_permits_enriched.sql
│   ├── 03_silver_covid_weekly_historical.sql
│   ├── 04_silver_ccvi_high_risk.sql
│   └── README.md
│
├── gold-layer/                        # Analytics aggregations (v2.14)
│   ├── 02_gold_taxi_hourly_by_zip.sql
│   ├── 03_gold_taxi_daily_by_zip.sql
│   ├── 04_gold_route_pairs.sql
│   ├── 05_gold_permits_roi.sql
│   ├── 06_gold_covid_hotspots.sql
│   ├── 07_gold_loan_targets.sql
│   ├── 08_gold_forecasts.sql
│   └── README.md
│
├── backfill/                          # Historical data loading
│   ├── quarterly_backfill_q1_2020.sh
│   ├── permits_backfill_2020_2025.sh
│   └── covid_backfill.sh
│
├── session-contexts/                  # Session documentation (external)
│   └── (See /Users/albin/Desktop/session-contexts/)
│
└── docs/                              # Project documentation
    ├── CHANGELOG.md
    ├── DATA_QUALITY_STRATEGY.md
    └── START_HERE.md
```

---

## 🎯 Next Steps

### Immediate (Ready to Execute)
1. **Build Looker/Tableau dashboards**
   - COVID risk heatmap (by ZIP and week)
   - Trip volume trends (hourly patterns)
   - Route optimization (top pairs analysis)
   - Loan eligibility map (choropleth by index)

2. **Implement Prophet forecasting**
   - Export historical trip data for training
   - Train Prophet models (one per ZIP via Vertex AI)
   - Load predictions to gold_forecasts
   - Schedule weekly retraining

3. **Create business views**
   - High-risk mobility hotspots
   - Monthly KPI summaries
   - Executive dashboard tables

### Short Term (This Week)
4. **Cross-dataset analysis queries**
   - Trips during high-risk COVID weeks
   - Permit activity in loan-eligible ZIPs
   - Airport traffic vs COVID risk
   - Income correlation with transportation patterns

5. **Incremental loading strategy**
   - Daily refresh for trip aggregations
   - Weekly refresh for COVID hotspots
   - Monthly refresh for loan targets
   - Optimize with MERGE statements vs full rebuild

### Long Term (Next Sprint)
6. **Dashboard development**
   - Connect Looker/Tableau/Data Studio
   - Build interactive visualizations
   - Set up scheduled refreshes
   - Create user documentation

7. **Additional Gold tables**
   - gold_neighborhood_trends
   - gold_monthly_summary
   - gold_kpis
   - gold_anomalies (outlier detection)

---

**Document Version:** v2.14.0
**Last Updated:** November 13, 2025
**Status:** ✅ Production Ready - Gold Layer Complete
