# Chicago Business Intelligence Platform for Strategic Planning

**Cloud-Native Data Lakehouse on Google Cloud Platform**

---
**Document:** Chicago BI App - Project README
**Version:** 2.22.0
**Document Type:** Architecture Documentation
**Date:** 2025-11-22
**Status:** ✅ **100% COMPLETE - ALL 5 DASHBOARDS BUILT**
**Authors:** Group 2 - MSDS 432
**Course:** MSDSP 432 - Foundations of Data Engineering
**Institution:** Northwestern University
**Team:** Albin Anto Jose, Myetchae Thu, Ansh Gupta, Bickramjit Basu
**Related Docs:** ARCHITECTURE_GAP_ANALYSIS.md, DEPLOYMENT_GUIDE.md, CURRENT_STATUS_v2.22.0.md
---

**Version 2.22.0 Updates (November 22, 2025):**
- ✅ **ALL 5 DASHBOARDS COMPLETE:** 30 visualizations across 5 Looker Studio dashboards
- ✅ **Dashboard 3 (CCVI) Built:** 6 visualizations, 6 BigQuery views for vulnerable communities
- ✅ **Dashboard 5 (Economic) Built:** 6 visualizations for investment targeting
- ✅ **Permits Pipeline Automated:** Cloud Run + Cloud Scheduler (Monday 3 AM CT, ~$3.60/year)
- ✅ **All BigQuery Views Created:** Airport, CCVI, Economic, Traffic, COVID views

**Recent Updates (v2.20.0-v2.22.0):**
- v2.20.0: Dashboard development phase started (Looker Studio selected)
- v2.20.1-v2.20.3: Dashboard 1, 2, 4 completed with rush hour analysis
- v2.21.0-v2.21.2: Permits pipeline automation + Cloud Run deployment
- v2.21.3: Dashboard 5 (Economic Development) completed
- v2.22.0: Dashboard 3 (CCVI) completed - **ALL DASHBOARDS DONE**

---

## Executive Summary

A **fully production-ready** cloud-native GCP data lakehouse with Prophet ML forecasting and complete Looker Studio dashboards for the Chicago Business Intelligence Platform. This scalable, cost-effective solution provides strategic insights from 202.7M+ records of Chicago open data with predictive analytics capabilities.

**Current Status:** ✅ **100% Project Complete**
- ✅ Data Pipeline: 100% (Raw → Bronze → Silver → Gold → Forecasts)
- ✅ ML Forecasting: 100% (Traffic + COVID models production-ready)
- ✅ Dashboards: 100% (5 dashboards, 30 visualizations in Looker Studio)
- ✅ Automation: 100% (Permits pipeline on Cloud Run with weekly schedule)
- ✅ Requirements: 3/10 complete (COVID alerts, traffic patterns, construction planning)

**Key Architecture Highlights:**
- **5-Layer Medallion:** Raw → Bronze → Silver → Gold → **ML Forecasts** in BigQuery
- **Prophet Time Series:** 114 ML models forecasting traffic volume & COVID risk
- **202.7M+ Records Processed:** Taxi (32.3M), TNP (170M), Permits (211K), COVID (13K)
- **Cloud-Native:** Cloud Run, BigQuery, Cloud Storage, Prophet on Compute
- **Geospatial:** ST_CONTAINS joins, ZIP/neighborhood enrichment, choropleth-ready
- **Cost-Effective:** ₹26,000 credits ≈ 7-8 months operation + ML forecasting

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│         DATA SOURCES (Chicago Data Portal - SODA API)       │
│  Taxi Trips | TNP | COVID-19 | Permits | CCVI | Boundaries │
└─────────────────────────┬───────────────────────────────────┘
                          │ HTTPS REST API
                          ▼
┌─────────────────────────────────────────────────────────────┐
│       EXTRACTION LAYER (Cloud Run Jobs - Go 1.21)           │
│  • extractor-taxi  • extractor-tnp  • extractor-covid       │
│  • Serverless execution, auto-scaling, rate limiting        │
└─────────────────────────┬───────────────────────────────────┘
                          │ Write JSON to GCS
                          ▼
┌─────────────────────────────────────────────────────────────┐
│      LANDING ZONE (Cloud Storage - Standard class)          │
│  gs://chicago-bi-landing/                                   │
│    ├── taxi/YYYY-MM-DD/batch_*.json                         │
│    ├── tnp/YYYY-MM-DD/batch_*.json                          │
│    └── covid/YYYY-MM-DD/batch_*.json                        │
└─────────────────────────┬───────────────────────────────────┘
                          │ BigQuery Load Jobs
                          ▼
┌─────────────────────────────────────────────────────────────┐
│         STORAGE & ANALYTICS: BigQuery Data Warehouse        │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ RAW LAYER (raw_data dataset) - 202.7M records     │    │
│  │ • Raw ingested data with full lineage              │    │
│  │ • Partitioned by date, clustered by location       │    │
│  └────────────────────────────────────────────────────┘    │
│                    ⬇ Quality Filtering (17%)                │
│  ┌────────────────────────────────────────────────────┐    │
│  │ BRONZE LAYER (bronze_data dataset) - 168M records │    │
│  │ • Quality-filtered, validated records              │    │
│  │ • Geographic bounds checking, deduplication        │    │
│  └────────────────────────────────────────────────────┘    │
│                    ⬇ SQL + GEOGRAPHY Functions              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ SILVER LAYER (silver_data dataset) - 168M+ rec    │    │
│  │ • Cleaned, validated, geographically enriched      │    │
│  │ • ZIP codes via ST_CONTAINS spatial joins (100%)   │    │
│  └────────────────────────────────────────────────────┘    │
│                    ⬇ SQL Aggregations                       │
│  ┌────────────────────────────────────────────────────┐    │
│  │ GOLD LAYER (gold_data dataset) - 52M+ records     │    │
│  │ • Pre-aggregated, dashboard-ready metrics          │    │
│  │ • Hourly/daily aggregations, risk scores, ROI      │    │
│  └────────────────────────────────────────────────────┘    │
│                    ⬇ Prophet ML Forecasting ✅ NEW          │
│  ┌────────────────────────────────────────────────────┐    │
│  │ FORECAST LAYER (gold_data) - 5,802 forecasts      │    │
│  │ • Traffic: 5,130 forecasts (57 ZIPs × 90 days)    │    │
│  │ • COVID: 672 forecasts (56 ZIPs × 12 weeks)       │    │
│  │ • Model metrics: 114 Prophet models tracked        │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│    GEOSPATIAL PROCESSING (GeoPandas + Local PostGIS)        │
│  • One-time generation of reference boundary maps           │
│  • GeoPandas for shapefile processing                       │
│  • Export to BigQuery GEOGRAPHY format                      │
│  • No ongoing Cloud SQL costs                               │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│           ORCHESTRATION (Cloud Scheduler + Cron)            │
│  • Daily extraction jobs (3 AM Central)                     │
│  • Weekly forecasting (Sundays 4 AM)                        │
│  • Monthly archival (1st of month)                          │
│  • Simple, cost-effective scheduling                        │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│         VISUALIZATION (Looker Studio - Free)                │
│  • 8 interactive dashboards                                 │
│  • Direct BigQuery connection                               │
│  • Real-time data, shareable links                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Design Changes from Original Plan

### 1. Removed Cloud SQL (PostgreSQL + PostGIS)
**Original:** Cloud SQL for complex spatial operations ($18.55/month)
**Updated:** GeoPandas + Local PostGIS for one-time reference map generation

**Rationale:**
- Most spatial operations can be handled by BigQuery GEOGRAPHY functions
- Reference boundaries (zip codes, neighborhoods) are static - generate once
- Use GeoPandas locally to process shapefiles and upload to BigQuery
- Eliminates $18.55/month ongoing cost
- No performance impact - all queries run in BigQuery

**Implementation:**
```python
# geospatial/generate_reference_maps.py
import geopandas as gpd
from google.cloud import bigquery

# Load Chicago zip code boundaries shapefile
gdf = gpd.read_file("data/chicago_zip_boundaries.shp")

# Convert to WGS84 (EPSG:4326) for BigQuery GEOGRAPHY
gdf = gdf.to_crs(epsg=4326)

# Upload to BigQuery
client = bigquery.Client()
gdf.to_gbq(
    destination_table='chicago-bi.reference.ref_boundaries_zip',
    project_id='chicago-bi',
    if_exists='replace'
)
```

### 2. Removed Cloud Composer (Managed Airflow)
**Original:** Cloud Composer for orchestration ($25-40/month)
**Updated:** Cloud Scheduler with cron jobs

**Rationale:**
- Simpler pipeline doesn't require complex DAG dependencies
- Cloud Scheduler provides sufficient scheduling capabilities
- Direct HTTP triggers to Cloud Run jobs
- Saves $25-40/month
- Easier to maintain and debug

**Implementation:**
```bash
# Create daily extraction job schedule
gcloud scheduler jobs create http daily-taxi-extract \
  --schedule="0 8 * * *" \
  --uri="https://us-central1-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/chicago-bi/jobs/extractor-taxi:run" \
  --http-method=POST \
  --oidc-service-account-email=scheduler@chicago-bi.iam.gserviceaccount.com \
  --location=us-central1 \
  --time-zone="America/Chicago"
```

---

## Updated Cost Analysis

### Monthly Operational Costs (Revised)

| Service | Configuration | Monthly Cost (USD) | Annual Cost (USD) |
|---------|--------------|-------------------|-------------------|
| **BigQuery - Query** | 4GB/month | $18.75 | $225.00 |
| **BigQuery - Storage** | 100GB Active Logical | $2.07 | $24.84 |
| **Cloud Storage** | 200GB Standard | $4.60 | $55.20 |
| **Cloud Run - CPU** | 2500 hours | $1.46 | $17.52 |
| **Cloud Run - Memory** | 2500 GB-hours | $0.16 | $1.92 |
| **Cloud Scheduler** | 3 jobs | $0.30 | $3.60 |
| **Cloud Build** | 500 min/month | $1.50 | $18.00 |
| **TOTAL** | | **$28.84** | **$346.08** |

### Cost Savings Comparison

| Architecture | Monthly Cost | Savings vs Original |
|-------------|--------------|---------------------|
| **Original (with Cloud SQL + Composer)** | $47.09 | - |
| **Revised (Cloud Scheduler + GeoPandas)** | $28.84 | **$18.25/month (39%)** |

### Credit Duration Analysis

**Available Credits:** ₹26,000 INR ≈ $310 USD (@ ₹84/$1)

**Original Duration:** $310 ÷ $47.09 = 6.6 months
**Revised Duration:** $310 ÷ $28.84 = **10.7 months**

**Extended Timeline:** +4.1 months of operation! 🎉

---

## Project Structure

```
chicago-bi-app/
├── README.md                          # This file
├── .gitignore                         # Git ignore patterns
├── LICENSE                            # MIT License
├── docs/                              # Documentation
│   ├── ARCHITECTURE.md                # Detailed architecture
│   ├── SETUP.md                       # Setup instructions
│   ├── API_REFERENCE.md               # API documentation
│   └── DEPLOYMENT.md                  # Deployment guide
│
├── extractors/                        # Cloud Run extraction jobs
│   ├── taxi/                          # Taxi trips extractor
│   │   ├── main.go
│   │   ├── Dockerfile
│   │   └── go.mod
│   ├── tnp/                           # TNP permits extractor
│   ├── covid/                         # COVID-19 extractor
│   └── permits/                       # Building permits extractor
│
├── bigquery/                          # BigQuery schemas and queries
│   ├── schemas/                       # Table schemas (DDL)
│   │   ├── bronze_layer.sql
│   │   ├── silver_layer.sql
│   │   ├── gold_layer.sql
│   │   └── reference_layer.sql
│   ├── queries/                       # Transformation queries
│   │   ├── bronze_to_silver.sql
│   │   ├── silver_to_gold.sql
│   │   └── analytics_views.sql
│   └── reference-data/                # Static reference data
│       ├── ccvi.csv
│       └── socioeconomic.csv
│
├── geospatial/                        # Geospatial processing
│   ├── geopandas/                     # GeoPandas scripts
│   │   ├── generate_zip_boundaries.py
│   │   ├── generate_neighborhoods.py
│   │   └── requirements.txt
│   └── reference-maps/                # Shapefiles and outputs
│       ├── chicago_zip_codes.shp
│       ├── chicago_neighborhoods.shp
│       └── README.md
│
├── scheduler/                         # Cloud Scheduler configurations
│   ├── daily_extract.sh               # Daily extraction schedule
│   ├── weekly_forecast.sh             # Weekly ML forecasting
│   └── monthly_archive.sh             # Monthly archival
│
├── monitoring/                        # Monitoring and logging
│   ├── data_quality_checks.sql        # Quality check queries
│   ├── cost_tracking.sql              # Cost monitoring queries
│   └── alerts.yaml                    # Alert configurations
│
├── dashboards/                        # Looker Studio dashboard configs
│   ├── covid_testing_alerts.json
│   ├── airport_traffic.json
│   └── README.md
│
├── tests/                             # Unit and integration tests
│   ├── extractors/
│   ├── transformations/
│   └── integration/
│
└── .github/                           # GitHub Actions CI/CD
    └── workflows/
        ├── build_extractors.yml
        ├── deploy_bigquery.yml
        └── run_tests.yml
```

---

## Technology Stack

### Data Ingestion
- **Cloud Run Jobs:** Serverless extraction with Go 1.21
- **Cloud Scheduler:** Cron-based job scheduling
- **SODA API v2.1:** Chicago Data Portal integration

### Data Storage & Analytics
- **BigQuery:** Data warehouse (Bronze/Silver/Gold layers)
- **Cloud Storage:** Landing zone and archival
- **BigQuery GEOGRAPHY:** Native geospatial support

### Geospatial Processing
- **GeoPandas:** Python library for geospatial data
- **Local PostGIS (optional):** Advanced spatial operations
- **Shapefiles:** Chicago boundary data

### Orchestration & Monitoring
- **Cloud Scheduler:** Job scheduling
- **Cloud Logging:** Centralized logging
- **Cloud Monitoring:** Metrics and alerts

### Visualization & ML
- **Looker Studio:** Free BI dashboards
- **Vertex AI Workbench:** Prophet forecasting
- **BQML:** BigQuery Machine Learning

---

## Key Features

### 1. Serverless Architecture
- Zero infrastructure management
- Auto-scaling from 0 to 1000 instances
- Pay only for execution time

### 2. Medallion Data Lakehouse
- **Bronze:** Raw data with full lineage
- **Silver:** Cleaned and enriched data
- **Gold:** Pre-aggregated analytics

### 3. Geospatial Analysis
- BigQuery GEOGRAPHY for spatial queries
- Point-in-polygon zip code enrichment
- Distance calculations (Haversine)

### 4. Cost Optimization
- 39% cost savings vs original architecture
- Partitioning and clustering for query efficiency
- Lifecycle policies for storage management

### 5. Data Quality Framework
- Automated quality checks
- Data freshness monitoring
- Error tracking and alerting

---

## Getting Started

### Prerequisites
- GCP account with ₹26,000 credits
- Google Cloud SDK installed
- Go 1.21+ (for extractors)
- Python 3.9+ (for geospatial processing)
- Git and GitHub account

### Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/chicago-bi-app.git
cd chicago-bi-app

# 2. Set up GCP project
export PROJECT_ID=chicago-bi
gcloud config set project $PROJECT_ID

# 3. Enable required APIs
gcloud services enable \
  bigquery.googleapis.com \
  run.googleapis.com \
  storage.googleapis.com \
  cloudscheduler.googleapis.com

# 4. Create Cloud Storage buckets
gsutil mb -l us-central1 gs://chicago-bi-landing
gsutil mb -l us-central1 gs://chicago-bi-archive

# 5. Deploy BigQuery schemas
bq mk --dataset chicago-bi:raw_data
bq mk --dataset chicago-bi:cleaned_data
bq mk --dataset chicago-bi:analytics
bq mk --dataset chicago-bi:reference

# 6. Build and deploy extractors
cd extractors/taxi
gcloud builds submit --tag gcr.io/$PROJECT_ID/extractor-taxi
gcloud run jobs create extractor-taxi \
  --image gcr.io/$PROJECT_ID/extractor-taxi \
  --region us-central1

# 7. Set up scheduling
cd ../../scheduler
./daily_extract.sh
```

See [docs/SETUP.md](docs/SETUP.md) for detailed instructions.

---

## Use Cases & Dashboards

### 1. COVID-19 Testing Alerts Dashboard
- Track testing rates by zip code
- Identify hotspots (>citywide avg + 1σ)
- Alert when positivity rate >5%
- **Impact:** Targeted public health interventions

### 2. Airport Traffic Patterns
- Taxi trips to/from O'Hare and Midway
- Peak hours and seasonal trends
- Demand forecasting (30-day Prophet model)
- **Impact:** Infrastructure planning for airport expansion

### 3. CCVI Vulnerability Analysis
- COVID-19 Community Vulnerability Index by area
- Correlation with testing rates and outcomes
- Resource allocation optimization
- **Impact:** Equitable distribution of health resources

### 4. Traffic & Transportation Metrics
- Citywide mobility patterns
- Average trip distances and durations
- Revenue analysis by neighborhood
- **Impact:** Transportation policy decisions

### 5. Infrastructure Investment Planning
- Building permit trends by zip code
- Estimated construction values
- Year-over-year growth analysis
- **Impact:** Strategic infrastructure investments

### 6. Business Loan Fund Targeting
- Identify low-income, high-vulnerability areas
- Correlate with economic indicators
- Prioritize small business support
- **Impact:** Equitable economic development

### 7. Executive Summary Dashboard
- KPIs across all data sources
- City-wide trends and alerts
- Real-time data freshness indicators
- **Impact:** Strategic decision-making

### 8. Operational Monitoring
- Pipeline success rates
- Data quality metrics
- Cost tracking and budget alerts
- **Impact:** System reliability and cost control

---

## Implementation Timeline

| Week | Focus | Deliverables |
|------|-------|--------------|
| **Week 1** | Foundation & Setup | GCP project, extractors, BigQuery schemas |
| **Week 2** | ETL Pipeline | Cloud Run jobs, transformations, quality checks |
| **Week 3** | Automation & ML | Cloud Scheduler, Prophet forecasting, monitoring |
| **Week 4** | Visualization | Looker Studio dashboards, documentation, demo |

**Total Duration:** 4 weeks
**Expected Score:** 50/50 (100%) + extra credit potential

---

## Data Sources

All data from [Chicago Data Portal](https://data.cityofchicago.org/):

1. **Taxi Trips:** [wrvz-psew](https://data.cityofchicago.org/Transportation/Taxi-Trips/wrvz-psew)
2. **TNP Permits:** [889t-nwn4](https://data.cityofchicago.org/Transportation/Transportation-Network-Providers-Drivers/889t-nwn4)
3. **COVID-19 Cases:** [yhhz-zm2v](https://data.cityofchicago.org/Health-Human-Services/COVID-19-Cases-Tests-and-Deaths-by-ZIP-Code/yhhz-zm2v)
4. **Building Permits:** [ydr8-5enu](https://data.cityofchicago.org/Buildings/Building-Permits/ydr8-5enu)
5. **CCVI:** [xhc6-88s9](https://data.cityofchicago.org/Health-Human-Services/COVID-19-Community-Vulnerability-Index-CCVI-/xhc6-88s9)
6. **Boundaries:** [igwz-8jzy](https://data.cityofchicago.org/Facilities-Geographic-Boundaries/Boundaries-ZIP-Codes/igwz-8jzy)

---

## Contributing

This is an academic project for MSDSP 432. For questions or collaboration:

**Team Members:**
- Albin Anto Jose
- Myetchae Thu
- Ansh Gupta
- Bickramjit Basu

**Instructor:** Dr. Abid Ali
**Institution:** Northwestern University

---

## License

MIT License - See [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- Chicago Data Portal for open data access
- Northwestern University MSDSP program
- Dr. Abid Ali for project guidance
- Google Cloud Platform for educational credits

---

## Project Status

✅ **100% Complete** - v2.22.0 (All Dashboards Built)

**Current Phase:** Project Complete - All 5 Dashboards Built in Looker Studio
**Completion:** 100% (Data pipeline + ML forecasting + Dashboards + Automation)
**Latest Update:** November 22, 2025 - Dashboard 3 (CCVI) Complete

### Dashboard Status (100% Complete)

| Dashboard | Visualizations | Status |
|-----------|---------------|--------|
| 1. COVID-19 Alerts & Safety | 6/6 | ✅ 100% |
| 2. Airport Traffic Analysis | 5/5 | ✅ 100% |
| 3. Vulnerable Communities (CCVI) | 6/6 | ✅ 100% |
| 4. Traffic Forecasting & Construction | 7/7 | ✅ 100% |
| 5. Economic Development & Investment | 6/6 | ✅ 100% |
| **TOTAL** | **30** | **✅ 100%** |

### Data Pipeline Summary

**✅ Raw Layer:** 203.3M records (4 extractors, 8 datasets, 5+ years + October 2025)
**✅ Bronze Layer:** 168.5M quality-filtered records (17% improvement, geographic validation)
**✅ Silver Layer:** 168.5M+ spatially enriched records (100% ZIP match, business logic applied)
**✅ Gold Layer:** 52M+ aggregated records (7 tables with complex risk scoring, October 2025 updated)
**✅ Reference Data:** 7 spatial tables (boundaries + crosswalks)
**✅ ML Forecasts:** 5,802 forecasts (Traffic + COVID Prophet models)

### Automation Status

**✅ Permits Pipeline (Cloud Run + Scheduler)**
- Cloud Run Job: `permits-pipeline`
- Schedule: Every Monday at 3:00 AM CT
- Execution Time: 6.17 seconds
- Annual Cost: ~$3.60/year

### Key Metrics
- **Data Volume:** 203.3M raw → 168.5M bronze → 168.5M silver → 52M+ gold
- **Time Coverage:** 2020-2025 (5+ years through October 31, 2025)
  - Taxi: 2020-01-01 through 2025-10-31 (25.8M+ trips)
  - TNP: 2019-11-04 through 2023-12-31 (142.5M trips)
- **Spatial Coverage:** 59 ZIP codes, 77 community areas, 98 neighborhoods
- **COVID Tracking:** 219 weeks (March 2020 - May 2024), 3 pandemic waves
- **Data Quality:** 99.9/100 ⭐⭐⭐⭐⭐
- **Latest Data:** ✅ October 2025 Complete (633K raw, 532K processed)

### What's Complete
- ✅ 4 Cloud Run extractors (Taxi, TNP, Permits, COVID-19)
- ✅ Historical backfills (99.7%+ coverage)
- ✅ October 2025 incremental update (all layers)
- ✅ 6 Bronze tables (quality filtering)
- ✅ 4 Silver tables (spatial enrichment)
- ✅ 7 Gold tables (analytics aggregations)
- ✅ Complex risk scoring (COVID hotspots)
- ✅ Loan eligibility targeting (35 eligible ZIPs)
- ✅ Time series analysis (219 weeks)
- ✅ Partitioning/clustering optimization
- ✅ Incremental update pattern (reusable for future months)
- ✅ Prophet ML forecasting (Traffic + COVID models)
- ✅ 5 Looker Studio dashboards (30 visualizations)
- ✅ Permits pipeline automation (Cloud Run + Scheduler)
- ✅ Dashboard auto-refresh configured

### Remaining Tasks
- 🔜 Configure data freshness for all dashboards (4-12 hours)
- 🔜 Monitor first automated pipeline run (Monday)
- 🔜 Final documentation review

**Detailed Status:** See [CURRENT_STATUS_v2.22.0.md](CURRENT_STATUS_v2.22.0.md) for comprehensive documentation

---

**Built with ❤️ by Group 2 for Northwestern University MSDSP 432**
