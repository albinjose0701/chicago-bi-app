# Chicago BI App - Folder Structure

**Last Updated:** December 5, 2025
**Status:** Organized and optimized for sharing

---

## Overview

This document describes the organized folder structure of the Chicago BI App project. Each main folder contains organized subfolders (scripts/, logs/, docs/, sql/, archive/) to maintain clarity and accessibility.

---

## Root Level Structure

```
chicago-bi-app/
├── scripts/                    # Root-level setup and infrastructure scripts
├── archive/                    # Archived status reports and deprecated files
├── docs/                       # Main project documentation
├── config/                     # Configuration files
├── extractors/                 # Data extraction services
├── transformations/            # Data transformation pipelines
├── bronze-layer/               # Quality-filtered data layer
├── silver-layer/               # Enriched data layer
├── gold-layer/                 # Aggregated analytics layer
├── dashboards/                 # Dashboard build guides and queries
├── forecasting/                # ML forecasting models
├── backfill/                   # Historical data backfill operations
├── boundaries/                 # Geographic boundary data
├── geospatial/                 # Geospatial processing tools
├── bigquery/                   # BigQuery schemas and setup
├── archival/                   # Data archival utilities
├── scheduler/                  # Scheduling scripts
└── workflows/                  # Workflow definitions
```

---

## Detailed Folder Organization

### 1. Root Level (`/`)

**Purpose:** Main project documentation and infrastructure setup

**Files:**
- `README.md` - Project overview
- `CHANGELOG.md` - Version history
- `LICENSE` - Project license
- `.gitignore` - Git ignore rules

**Subfolders:**
- `scripts/` - Infrastructure setup scripts
  - `setup_gcp_infrastructure.sh`
  - `setup_budget_shutdown.sh`
- `archive/` - Old status reports
  - `CURRENT_STATUS_v2.14.0.md`
  - `CURRENT_STATUS_v2.19.0.md`
- `docs/` - All project documentation
  - `START_HERE.md` - Getting started guide
  - `reference/CURRENT_STATUS_v2.22.0.md` - Current status
  - `reference/FOLDER_STRUCTURE.md` - This document
  - `reference/DATA_QUALITY_STRATEGY.md` - Quality strategy
  - Other organized documentation

---

### 2. Extractors (`/extractors/`)

**Purpose:** Data extraction services (Go-based Cloud Run services)

**Structure:**
```
extractors/
├── covid/                      # COVID-19 data extractor
│   ├── Dockerfile
│   ├── cloudbuild.yaml
│   ├── main.go
│   └── README.md
├── permits/                    # Building permits extractor
│   ├── Dockerfile
│   ├── cloudbuild.yaml
│   ├── main.go
│   └── README.md
├── taxi/                       # Taxi trips extractor
│   ├── scripts/               # Deployment and testing scripts
│   ├── docs/                  # Documentation and guides
│   ├── archive/               # Backup files (.bak)
│   ├── Dockerfile
│   ├── cloudbuild.yaml
│   └── main.go
├── tnp/                        # TNP trips extractor
│   ├── scripts/               # Deployment scripts
│   ├── Dockerfile
│   ├── cloudbuild.yaml
│   └── main.go
└── tnp-local/                  # Local testing version
    ├── scripts/               # Performance test scripts
    ├── logs/                  # Test execution logs
    ├── Dockerfile
    └── main.go
```

---

### 3. Transformations (`/transformations/`)

**Purpose:** Data transformation pipelines

**Structure:**
```
transformations/
└── permits/                    # Permits pipeline (Cloud Run)
    ├── scripts/               # Orchestration scripts
    │   ├── run_pipeline.py
    │   └── deploy.sh
    ├── sql/                   # Transformation queries
    │   ├── 01_bronze_permits_incremental.sql
    │   ├── 02_silver_permits_incremental.sql
    │   └── 03_gold_permits_aggregates.sql
    ├── docs/                  # Documentation
    │   ├── AUTOMATION_GUIDE.md
    │   ├── QUICK_START.md
    │   └── README.md
    ├── Dockerfile
    ├── cloudbuild.yaml
    └── requirements.txt
```

---

### 4. Data Layers

#### Bronze Layer (`/bronze-layer/`)

**Purpose:** Quality-filtered raw data

**Structure:**
```
bronze-layer/
├── scripts/                   # Table creation scripts
│   ├── 00_create_all_bronze_tables.sh
│   ├── create_remaining_bronze_tables.sh
│   └── recreate_trips_with_geo_bounds.sh
├── sql/                       # SQL table definitions
│   ├── 01_create_bronze_dataset.sql
│   ├── 02_bronze_taxi_trips.sql
│   ├── 03_bronze_tnp_trips.sql
│   ├── 04_bronze_covid_cases.sql
│   ├── 05_bronze_building_permits.sql
│   ├── 06_bronze_ccvi.sql
│   └── 07_bronze_public_health.sql
├── logs/                      # Execution logs
└── docs/                      # Documentation
    └── README.md
```

#### Silver Layer (`/silver-layer/`)

**Purpose:** Spatially enriched and business-logic transformed data

**Structure:**
```
silver-layer/
├── scripts/                   # Table creation scripts
│   └── 00_create_all_silver_tables.sh
├── sql/                       # SQL transformations
│   ├── 01_create_silver_dataset.sql
│   ├── 02_silver_trips_enriched.sql
│   ├── 03_silver_permits_enriched.sql
│   ├── 04_silver_covid_latest.sql
│   ├── 04_silver_covid_weekly_historical.sql
│   └── 05_silver_ccvi_high_risk.sql
└── docs/                      # Documentation
    └── README.md
```

#### Gold Layer (`/gold-layer/`)

**Purpose:** Aggregated analytics tables

**Structure:**
```
gold-layer/
├── scripts/                   # Table creation scripts
│   └── 00_create_all_gold_tables.sh
├── sql/                       # SQL aggregations
│   ├── 01_create_gold_dataset.sql
│   ├── 02_gold_taxi_hourly_by_zip.sql
│   ├── 03_gold_taxi_daily_by_zip.sql
│   ├── 04_gold_route_pairs.sql
│   ├── 05_gold_permits_roi.sql
│   ├── 06_gold_covid_hotspots.sql
│   ├── 07_gold_loan_targets.sql
│   └── 08_gold_forecasts.sql
├── logs/                      # Execution logs
└── docs/                      # Documentation
    └── README.md
```

---

### 5. Dashboards (`/dashboards/`)

**Purpose:** Looker Studio dashboard build guides and queries

**Structure:**
```
dashboards/
├── docs/                      # Build guides
│   ├── DASHBOARD_3_BUILD_GUIDE.md
│   ├── DASHBOARD_4_BUILD_INSTRUCTIONS.md
│   ├── DASHBOARD_4_DETAILED_GUIDE.md
│   ├── DASHBOARD_5_BUILD_GUIDE.md
│   ├── DASHBOARD_5_QUICK_REFERENCE.md
│   ├── DASHBOARD_IMPLEMENTATION_PLAN.md
│   ├── DASHBOARD_READINESS_ANALYSIS.md
│   ├── LOOKER_STUDIO_AUTO_REFRESH_GUIDE.md
│   └── LOOKER_STUDIO_QUICKSTART.md
└── queries/                   # Dashboard SQL queries
    ├── create_dashboard_3_views.sql
    ├── create_dashboard_5_views.sql
    ├── dashboard_1_covid_queries.sql
    ├── dashboard_2_airport_queries.sql
    └── dashboard_4_traffic_queries.sql
```

---

### 6. Forecasting (`/forecasting/`)

**Purpose:** ML forecasting models (Prophet-based)

**Structure:**
```
forecasting/
├── scripts/                   # Python forecasting scripts
│   ├── covid_alert_forecasting.py
│   ├── covid_alert_forecasting_retrospective.py
│   ├── covid_alert_forecasting_simple.py
│   └── run_all_forecasts.sh
├── sql/                       # Forecast table setup
│   ├── 01_create_forecast_tables.sql
│   ├── COVID_FORECAST_QUERIES.sql
│   └── FORECAST_QUERIES.sql
├── logs/                      # Execution logs
├── docs/                      # Documentation
│   ├── README.md
│   └── SESSION_SUMMARY_v2.19.0.md
├── requirements.txt
└── venv/                      # Python virtual environment
```

---

### 7. Backfill (`/backfill/`)

**Purpose:** Historical data backfill operations

**Structure:**
```
backfill/
├── scripts/                   # 41 backfill shell scripts
│   ├── auto_start_q3_q4_after_q2.sh
│   ├── quarterly_backfill_*.sh
│   └── ... (various backfill scripts)
├── logs/                      # 82 execution logs
│   ├── *.log files
│   └── *.log.summary files
├── docs/                      # Documentation
│   ├── README.md
│   ├── 2023_TAXI_BACKFILL_README.md
│   ├── 2024_2025_TAXI_BACKFILL_README.md
│   ├── PERMITS_COVID_BACKFILL_README.md
│   ├── UNATTENDED_MODE_README.md
│   └── *.txt info files
├── archive/                   # Temporary files
│   └── extraction_output.tmp
└── frames-setup/              # Frame extraction setup
```

---

### 8. Supporting Folders

#### Boundaries (`/boundaries/`)

**Purpose:** Geographic boundary data processing

**Structure:**
```
boundaries/
├── scripts/                   # Loading scripts
│   └── 01_load_boundaries.sh
├── sql/                       # Boundary tables
│   ├── 02_create_crosswalk_tables.sql
│   └── 03_enrich_raw_datasets.sql
└── docs/                      # Documentation
    └── README.md
```

#### Geospatial (`/geospatial/`)

**Purpose:** Geospatial validation and processing

**Structure:**
```
geospatial/
├── scripts/                   # Python validation scripts
│   ├── validate_geometries.py
│   ├── validate_neighborhoods.py
│   └── view_geometries.py
├── docs/                      # Validation reports
│   ├── GEOMETRY_VALIDATION_REPORT.md
│   ├── NEIGHBORHOODS_VALIDATION_REPORT.md
│   └── QUICK_SUMMARY.md
└── geopandas/                 # GeoPandas utilities
```

#### BigQuery (`/bigquery/`)

**Purpose:** BigQuery schema setup

**Structure:**
```
bigquery/
└── schemas/
    ├── scripts/               # Deployment scripts
    │   └── deploy_schemas.sh
    └── sql/                   # Schema definitions
        └── bronze_layer.sql
```

#### Archival (`/archival/`)

**Purpose:** Data archival utilities

**Structure:**
```
archival/
├── scripts/                   # Archive scripts
│   └── archive_quarter.sh
└── docs/                      # Documentation
    └── README.md
```

#### Scheduler (`/scheduler/`)

**Purpose:** Scheduling scripts

**Structure:**
```
scheduler/
└── scripts/                   # Scheduling scripts
    └── daily_extract.sh
```

#### Workflows (`/workflows/`)

**Purpose:** Workflow definitions

**Structure:**
```
workflows/
├── scripts/                   # Workflow scripts
│   ├── deploy_workflow.sh
│   └── quarterly_backfill_workflow.yaml
└── docs/                      # Documentation
    └── README.md
```

---

## Folder Organization Conventions

### Standard Subfolders

Each main folder follows a consistent organization pattern:

1. **`scripts/`** - Shell scripts (.sh), Python scripts (.py), orchestration scripts
2. **`sql/`** - SQL files for table creation, transformations, queries
3. **`logs/`** - Execution logs, test outputs, error logs
4. **`docs/`** - README files, guides, documentation
5. **`archive/`** - Deprecated files, backups, temporary files

### Benefits of This Structure

1. **Clarity** - Easy to find specific types of files
2. **Maintainability** - Organized structure simplifies updates
3. **Shareability** - Clean structure makes onboarding easier
4. **Scalability** - Consistent pattern across all modules
5. **Professionalism** - Production-ready organization

---

## Quick Navigation

### Finding Scripts
```bash
find . -type d -name scripts
```

### Finding Documentation
```bash
find . -type d -name docs
```

### Finding SQL Files
```bash
find . -type d -name sql
```

### Finding Logs
```bash
find . -type d -name logs
```

---

## Removed Empty Folders

The following empty folders were removed during reorganization:

- `/tests/`
- `/bigquery/queries/`
- `/bigquery/reference-data/`
- `/.github/workflows/`
- `/monitoring/`
- `/silver-layer/logs/` (was empty)
- `/forecasting/archive/` (was empty)
- `/geospatial/reference-maps/` (was empty)

---

## Documentation Updates

The following documentation files were updated to reflect the new folder structure:

1. **CHANGELOG.md** - Updated script paths
2. **bronze-layer/docs/README.md** - Updated execution commands
3. **silver-layer/docs/README.md** - Updated execution commands
4. **gold-layer/docs/README.md** - Updated execution commands

---

## Version Control

**Reorganization Date:** December 5, 2025
**Project Version:** v2.22.0
**Total Folders Created:** 44+ organized subfolders
**Empty Folders Removed:** 8

---

## Next Steps

When adding new components to the project:

1. Follow the established folder structure pattern
2. Create appropriate subfolders (scripts/, docs/, logs/, etc.)
3. Update relevant documentation
4. Remove any empty folders
5. Update docs/reference/FOLDER_STRUCTURE.md file

---

**End of Folder Structure Documentation**
