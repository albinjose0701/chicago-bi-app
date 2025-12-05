# Dashboard Implementation Plan - Chicago BI App
**Version:** v2.22.0 (COMPLETE)
**Date:** November 22, 2025
**Status:** ✅ **ALL DASHBOARDS COMPLETE (100%)**
**Actual Duration:** ~15 hours (November 15-22, 2025)

---

## ✅ IMPLEMENTATION COMPLETE

**All 5 Dashboards Built in Looker Studio:**

| Dashboard | Visualizations | Status |
|-----------|---------------|--------|
| 1. COVID-19 Alerts & Safety | 6/6 | ✅ 100% |
| 2. Airport Traffic Analysis | 5/5 | ✅ 100% |
| 3. Vulnerable Communities (CCVI) | 6/6 | ✅ 100% |
| 4. Traffic Forecasting & Construction | 7/7 | ✅ 100% |
| 5. Economic Development & Investment | 6/6 | ✅ 100% |
| **TOTAL** | **30** | **✅ 100%** |

**Build Guides Created:**
- `dashboards/DASHBOARD_3_BUILD_GUIDE.md`
- `dashboards/DASHBOARD_4_BUILD_INSTRUCTIONS.md`
- `dashboards/DASHBOARD_4_DETAILED_GUIDE.md`
- `dashboards/DASHBOARD_5_BUILD_GUIDE.md`
- `dashboards/DASHBOARD_5_QUICK_REFERENCE.md`
- `dashboards/LOOKER_STUDIO_AUTO_REFRESH_GUIDE.md`

---

## 📋 ORIGINAL IMPLEMENTATION ROADMAP (COMPLETED)

### Phase 1: Tool Selection & Setup (1-2 hours) ✅ COMPLETE
### Phase 2: Data Source Configuration (1-2 hours) ✅ COMPLETE
### Phase 3: Dashboard Development (6-10 hours) ✅ COMPLETE
### Phase 4: Testing & Refinement (2-3 hours) ✅ COMPLETE
### Phase 5: Documentation & Deployment (2-3 hours) ✅ COMPLETE

---

## PHASE 1: TOOL SELECTION & SETUP (1-2 hours)

### Step 1.1: Choose BI Platform

**Options to Consider:**

| Tool | Pros | Cons | Best For |
|------|------|------|----------|
| **Google Looker Studio** | • Free<br>• Native BigQuery integration<br>• Quick setup<br>• Good for prototypes | • Limited advanced features<br>• Performance limits on large datasets | MVP, Quick prototype |
| **Looker (Enterprise)** | • Powerful LookML<br>• Native GCP integration<br>• Reusable metrics<br>• Enterprise features | • Cost ($$$)<br>• Steeper learning curve<br>• Requires LookML knowledge | Enterprise deployment |
| **Tableau** | • Industry standard<br>• Rich visualizations<br>• Strong geospatial<br>• Wide adoption | • Cost ($$)<br>• Separate licensing<br>• Not GCP-native | Corporate environments |
| **Power BI** | • Microsoft ecosystem<br>• Good for Windows shops<br>• Strong analytics | • Cost ($)<br>• Less optimal for BigQuery<br>• Microsoft-centric | Microsoft-heavy orgs |

**Decision Criteria:**
- Budget constraints?
- Existing organizational tools?
- Technical expertise available?
- Deployment timeline (MVP vs production)?
- Number of users?

**Recommended Approach:**
1. **Start with Looker Studio** (free, fast MVP)
2. **Migrate to Looker/Tableau** later if needed (enterprise features)

**Action Items:** ✅ ALL COMPLETE
- [x] Decide on BI tool based on criteria above → **Looker Studio selected**
- [x] Create account/obtain license → **Connected to GCP project**
- [x] Verify access to BigQuery project → **All datasets accessible**

---

### Step 1.2: Set Up BigQuery Connection

**Prerequisites:**
- Google Cloud project access: `chicago-bi-app-msds-432-476520`
- IAM permissions: `BigQuery Data Viewer` or `BigQuery User`
- Service account (if needed for tool authentication)

**Connection Details:**
```
Project ID:  chicago-bi-app-msds-432-476520
Location:    us-central1
Datasets:
  - gold_data (primary for dashboards)
  - silver_data (backup/custom queries)
  - reference_data (boundaries, crosswalks)
  - raw_data (public health stats)
```

**Action Items:**
- [ ] Test BigQuery connection from BI tool
- [ ] Verify query execution permissions
- [ ] Confirm access to all required datasets
- [ ] Test sample query (e.g., `SELECT COUNT(*) FROM gold_data.gold_covid_hotspots`)

---

### Step 1.3: Environment Preparation

**File Organization:**
```
/Users/albin/Desktop/chicago-bi-app/dashboards/
├── queries/
│   ├── covid/           (12 COVID queries)
│   ├── traffic/         (10 traffic queries)
│   └── custom/          (ad-hoc queries)
├── assets/
│   ├── images/          (logos, icons)
│   └── styles/          (color palettes, themes)
├── documentation/
│   ├── user_guide.md
│   └── data_dictionary.md
└── exports/
    └── dashboard_configs/ (backup configurations)
```

**Color Palette (Chicago-themed):**
```
Primary Colors:
- Chicago Blue: #0051BA
- Deep Red: #C8102E
- White: #FFFFFF

Risk Categories:
- Low (Green): #10B981
- Medium (Yellow): #F59E0B
- High (Orange): #F97316
- Critical (Red): #EF4444

Data Visualization:
- Positive: #10B981
- Neutral: #6B7280
- Negative: #EF4444
- Accent: #8B5CF6
```

**Action Items:**
- [ ] Create dashboard project folder structure
- [ ] Copy SQL queries to queries/ folder
- [ ] Prepare Chicago branding assets (optional)
- [ ] Define color palette for consistency

---

## PHASE 2: DATA SOURCE CONFIGURATION (1-2 hours)

### Step 2.1: Create Base Data Sources

**For Each Requirement, Create Data Source:**

**Data Source 1: COVID Analysis**
```sql
-- Base table: gold_covid_hotspots
-- Fields: zip_code, week_start, cases_weekly, risk_category,
--         total_trips_from_zip, total_trips_to_zip, adjusted_risk_score
-- Date range: 2020-03-01 to 2024-05-12 (219 weeks)
```

**Data Source 2: COVID Forecasts**
```sql
-- Base table: gold_covid_risk_forecasts
-- Fields: zip_code, forecast_date, predicted_risk_score,
--         predicted_risk_category, alert_level
-- Date range: 2023-12-11 to 2024-03-25 (12 weeks forecast)
```

**Data Source 3: Traffic Forecasts**
```sql
-- Base table: gold_traffic_forecasts_by_zip
-- Fields: zip_code, forecast_date, predicted_traffic_volume,
--         traffic_volume_lower, traffic_volume_upper, trend, yearly, weekly
-- Date range: Sept 2025 to Jan 2026 (90 days)
```

**Data Source 4: Historical Traffic**
```sql
-- Base table: gold_taxi_daily_by_zip
-- Fields: trip_date, pickup_zip, dropoff_zip, total_trips,
--         avg_fare, total_revenue
-- Date range: 2020-01-01 to 2025-10-31
```

**Data Source 5: Airport Trips**
```sql
-- Base table: silver_trips_enriched
-- Filter: is_airport_trip = TRUE
-- Fields: pickup_community_area, dropoff_zip, dropoff_neighborhood,
--         trip_date, fare, trip_miles
```

**Data Source 6: CCVI High-Risk Areas**
```sql
-- Base table: silver_ccvi_high_risk
-- Fields: geography_type, geography_id, ccvi_score, ccvi_category
```

**Data Source 7: Socioeconomic Data**
```sql
-- Base table: raw_public_health_stats
-- Fields: Community Area, Community Area Name, Unemployment,
--         Below Poverty Level, Per Capita Income
```

**Data Source 8: Building Permits**
```sql
-- Base table: silver_permits_enriched
-- Fields: permit_type, community_area, zip_code, issue_date,
--         total_fee, reported_cost
```

**Data Source 9: Loan Eligibility**
```sql
-- Base table: gold_loan_targets
-- Fields: zip_code, per_capita_income, total_permits_new_construction,
--         eligibility_index, is_loan_eligible
```

**Data Source 10: Geographic Boundaries**
```sql
-- Base tables:
--   - reference_data.zip_code_boundaries (geometry for choropleth)
--   - reference_data.community_area_boundaries (geometry)
--   - reference_data.neighborhood_boundaries (geometry)
```

**Action Items:**
- [ ] Create 10 data source connections
- [ ] Test each data source with sample query
- [ ] Configure refresh schedules (daily recommended)
- [ ] Set up data source relationships (if tool supports)
- [ ] Document each data source (fields, filters, purpose)

---

### Step 2.2: Import Production SQL Queries

**COVID Queries (12 queries):**
- [ ] Copy from `forecasting/COVID_FORECAST_QUERIES.sql`
- [ ] Test query 1: Next 4 Weeks Forecast
- [ ] Test query 2: High-Risk ZIP Codes
- [ ] Test query 3: 12-Week Risk Trend
- [ ] Test query 4: Alert Level Distribution
- [ ] Test query 5: Forecast vs Historical
- [ ] Test query 6: Top 10 Highest Risk ZIPs
- [ ] Test query 7: Model Performance Metrics
- [ ] Test query 8: Uncertainty Analysis
- [ ] Test query 9: Mobility vs COVID Risk
- [ ] Test query 10: Weekly Alert Summary
- [ ] Test query 11: Geographic Risk Patterns
- [ ] Test query 12: Time Series Export

**Traffic Queries (10 queries):**
- [ ] Copy from `forecasting/FORECAST_QUERIES.sql`
- [ ] Test query 1: Next 7 Days Forecast
- [ ] Test query 2: Weekly Aggregated (12 weeks)
- [ ] Test query 3: Monthly Summary
- [ ] Test query 4: Top 10 High-Traffic ZIPs
- [ ] Test query 5: Forecast vs Actual
- [ ] Test query 6: Seasonality Breakdown
- [ ] Test query 7: Model Performance Metrics
- [ ] Test query 8: Uncertainty Analysis
- [ ] Test query 9: Day-of-Week Patterns
- [ ] Test query 10: Month-over-Month Growth

**Action Items:**
- [ ] Save all 22 queries as named queries/views in BI tool
- [ ] Parameterize queries where needed (date ranges, ZIP filters)
- [ ] Test query performance (<5 seconds ideal)
- [ ] Document query purpose and usage

---

### Step 2.3: Set Up Parameters & Filters

**Global Filters (Apply Across Dashboards):**
- [ ] Date Range Picker (default: Last 90 days)
- [ ] ZIP Code Multi-Select (default: All)
- [ ] Community Area Multi-Select (default: All)
- [ ] Neighborhood Multi-Select (default: All)

**Dashboard-Specific Parameters:**
- [ ] COVID: Risk Category Filter (Low/Medium/High)
- [ ] Traffic: Forecast Horizon (7/30/90 days)
- [ ] Permits: Permit Type Filter (NEW CONSTRUCTION, etc.)
- [ ] Airports: Airport Selection (O'Hare/Midway/Both)

**Action Items:**
- [ ] Create parameter definitions
- [ ] Link parameters to data sources
- [ ] Test filter interactions
- [ ] Set sensible defaults

---

## PHASE 3: DASHBOARD DEVELOPMENT (6-10 hours)

### Step 3.1: Dashboard 1 - COVID-19 Alerts & Safety (2-3 hours)

**Requirements Coverage:** Requirement 1

**Layout Structure:**
```
┌─────────────────────────────────────────────────────┐
│  COVID-19 ALERTS & DRIVER SAFETY DASHBOARD          │
├─────────────────────────────────────────────────────┤
│  Filters: Date Range | ZIP Code | Risk Category     │
├────────────────────┬────────────────────────────────┤
│                    │                                │
│  CURRENT ALERT MAP │   TOP 10 HIGH-RISK ZIPS       │
│  (Choropleth)      │   (Bar Chart)                 │
│  Color by Risk     │                               │
│                    │                               │
├────────────────────┴────────────────────────────────┤
│  12-WEEK RISK FORECAST (Multi-line Chart)          │
│  Selected ZIPs over Time                            │
├────────────────────┬────────────────────────────────┤
│  TAXI CORRELATION  │  HISTORICAL TRENDS             │
│  (Scatter Plot)    │  (Dual-Axis Time Series)      │
│  Trips vs Cases    │  Cases + Trips over 219 weeks │
├────────────────────┴────────────────────────────────┤
│  ALERT SUMMARY TABLE (Top 20 ZIPs with Metrics)    │
└─────────────────────────────────────────────────────┘
```

**Visualizations to Create:**

1. **Current Risk Map (Choropleth)**
   - Data: gold_covid_hotspots (latest week)
   - Geography: zip_code_boundaries
   - Color: risk_category (Low=Green, Medium=Yellow, High=Red)
   - Tooltip: ZIP, risk_category, cases_weekly, total_trips_to_zip
   - SQL Query: #11 (Geographic Risk Patterns)

2. **Top 10 High-Risk ZIPs (Horizontal Bar Chart)**
   - Data: gold_covid_hotspots (latest week)
   - X-Axis: adjusted_risk_score
   - Y-Axis: zip_code (sorted by risk)
   - Color: risk_category
   - SQL Query: #6 (Top 10 Highest Risk ZIPs)

3. **12-Week Risk Forecast (Multi-Line Chart)**
   - Data: gold_covid_risk_forecasts
   - X-Axis: forecast_date
   - Y-Axis: predicted_risk_score
   - Lines: Top 5-10 selected ZIPs
   - Confidence Bands: risk_score_lower/upper (shaded area)
   - SQL Query: #3 (12-Week Risk Trend)

4. **Taxi Correlation (Scatter Plot)**
   - Data: gold_covid_hotspots (all weeks)
   - X-Axis: total_trips_to_zip (log scale)
   - Y-Axis: cases_weekly
   - Color: risk_category
   - Size: population
   - SQL Query: #9 (Mobility vs COVID Risk)

5. **Historical Trends (Dual-Axis Time Series)**
   - Data: gold_covid_hotspots (219 weeks)
   - X-Axis: week_start
   - Y-Axis 1: cases_weekly (bars)
   - Y-Axis 2: total_trips_to_zip (line)
   - Annotations: Major pandemic waves
   - SQL Query: #5 (Forecast vs Historical)

6. **Alert Summary Table**
   - Data: gold_covid_risk_forecasts (next 4 weeks)
   - Columns: ZIP, Current Risk, 4-Week Forecast, Alert Level, Recommended Action
   - Sorting: By alert_level (CRITICAL → NONE)
   - Conditional Formatting: Color by alert_level
   - SQL Query: #1 (Next 4 Weeks Forecast)

**Action Items:**
- [ ] Create dashboard page layout
- [ ] Build visualization 1: Risk Map
- [ ] Build visualization 2: Top 10 Bar Chart
- [ ] Build visualization 3: 12-Week Forecast
- [ ] Build visualization 4: Scatter Plot
- [ ] Build visualization 5: Historical Trends
- [ ] Build visualization 6: Alert Table
- [ ] Link filters to all visualizations
- [ ] Add titles, legends, and annotations
- [ ] Test interactivity (click ZIP → filter all charts)

---

### Step 3.2: Dashboard 2 - Airport Traffic Analysis (1.5-2 hours)

**Requirements Coverage:** Requirement 2

**Layout Structure:**
```
┌─────────────────────────────────────────────────────┐
│  AIRPORT TRAFFIC MONITORING DASHBOARD               │
├─────────────────────────────────────────────────────┤
│  Filters: Date Range | Airport (O'Hare/Midway)      │
├────────────────────┬────────────────────────────────┤
│                    │                                │
│  DESTINATION MAP   │   TRAFFIC TRENDS              │
│  (Heatmap)         │   (Time Series)               │
│  From Airport      │   Daily Trips                 │
│                    │                               │
├────────────────────┴────────────────────────────────┤
│  TOP 10 ROUTES FROM AIRPORT (Bar Chart)            │
├────────────────────┬────────────────────────────────┤
│  COVID OVERLAY     │  TIME OF DAY PATTERNS          │
│  (Airport → Risk)  │  (Heatmap by Hour)            │
└────────────────────┴────────────────────────────────┘
```

**Visualizations to Create:**

1. **Airport Destination Heatmap**
   - Data: silver_trips_enriched (is_airport_trip = TRUE)
   - Geography: dropoff_zip
   - Color Intensity: COUNT(trip_id)
   - Filter: pickup_community_area (76=O'Hare, 56=Midway)
   - Tooltip: dropoff_zip, trip_count, avg_fare

2. **Traffic Trends (Time Series)**
   - Data: silver_trips_enriched (is_airport_trip = TRUE)
   - X-Axis: DATE_TRUNC(trip_date, DAY/WEEK/MONTH)
   - Y-Axis: COUNT(trip_id)
   - Lines: O'Hare (CA 76) vs Midway (CA 56)
   - Note: "Midway data may be under-represented"

3. **Top 10 Routes (Horizontal Bar Chart)**
   - Data: silver_trips_enriched (is_airport_trip = TRUE)
   - X-Axis: COUNT(trip_id)
   - Y-Axis: dropoff_neighborhood
   - Color: avg_fare (gradient)
   - Sorted: DESC by trip_count

4. **COVID Risk Overlay (Combo Chart)**
   - Data: JOIN silver_trips_enriched + gold_covid_hotspots
   - X-Axis: dropoff_zip
   - Y-Axis 1: Airport trips (bars)
   - Y-Axis 2: COVID risk_category (color-coded dots)
   - Highlight: High-risk destinations with high airport traffic

5. **Time of Day Patterns (Heatmap)**
   - Data: silver_trips_enriched (is_airport_trip = TRUE)
   - X-Axis: trip_hour (0-23)
   - Y-Axis: DAYOFWEEK(trip_date)
   - Color: COUNT(trip_id)
   - Shows: Peak airport pickup times

**Action Items:**
- [ ] Create dashboard page layout
- [ ] Build visualization 1: Destination Heatmap
- [ ] Build visualization 2: Traffic Trends
- [ ] Build visualization 3: Top 10 Routes
- [ ] Build visualization 4: COVID Overlay
- [ ] Build visualization 5: Time of Day Heatmap
- [ ] Add Midway caveat note (text box)
- [ ] Add airport filter (O'Hare/Midway toggle)
- [ ] Test filter interactions

---

### Step 3.3: Dashboard 3 - Vulnerable Communities (1-1.5 hours)

**Requirements Coverage:** Requirement 3

**Layout Structure:**
```
┌─────────────────────────────────────────────────────┐
│  CCVI HIGH-RISK COMMUNITIES DASHBOARD               │
├─────────────────────────────────────────────────────┤
│  Filters: Date Range | Geography Type (CA/ZIP)      │
├────────────────────┬────────────────────────────────┤
│                    │                                │
│  CCVI RISK MAP     │   TRIP ACTIVITY TRENDS        │
│  (Choropleth)      │   (Time Series)               │
│  39 High-Risk Areas│   Trips From/To High CCVI     │
│                    │                               │
├────────────────────┴────────────────────────────────┤
│  DOUBLE BURDEN MAP (CCVI High + COVID High)        │
├────────────────────┬────────────────────────────────┤
│  POOLED RIDES      │  TOP 10 HIGH-CCVI AREAS       │
│  (% by Area)       │  (Table)                      │
└────────────────────┴────────────────────────────────┘
```

**Visualizations to Create:**

1. **CCVI Risk Map**
   - Data: silver_ccvi_high_risk
   - Geography: Based on geography_type (CA or ZIP)
   - Color: ccvi_score (gradient red, 47.9-63.7)
   - Tooltip: geography_id, ccvi_score, ccvi_category

2. **Trip Activity Trends**
   - Data: silver_trips_enriched (filter by CCVI high areas)
   - X-Axis: DATE_TRUNC(trip_date, WEEK)
   - Y-Axis: COUNT(trip_id)
   - Lines: Trips FROM high CCVI (pickup), Trips TO high CCVI (dropoff)
   - Shows: Taxi activity patterns in vulnerable areas

3. **Double Burden Map (CCVI + COVID)**
   - Data: JOIN silver_ccvi_high_risk + gold_covid_hotspots (latest week)
   - Geography: zip_code
   - Color: Both CCVI=High AND risk_category=High (dark red)
   - Tooltip: ZIP, CCVI score, COVID risk, cases_weekly
   - Highlight: Areas with dual vulnerability

4. **Pooled Rides Analysis (Bar Chart)**
   - Data: silver_trips_enriched (trips_pooled > 0)
   - Filter: dropoff in CCVI-high areas
   - X-Axis: geography_id
   - Y-Axis: % of trips that are pooled
   - Shows: Shared mobility patterns in vulnerable communities

5. **Top 10 High-CCVI Areas (Table)**
   - Data: silver_ccvi_high_risk
   - Columns: Rank, Area ID, CCVI Score, Trips To, Trips From, COVID Risk
   - Sorting: DESC by ccvi_score
   - Conditional Formatting: Highlight double burden areas

**Action Items:**
- [ ] Create dashboard page layout
- [ ] Build visualization 1: CCVI Map
- [ ] Build visualization 2: Trip Trends
- [ ] Build visualization 3: Double Burden Map
- [ ] Build visualization 4: Pooled Rides
- [ ] Build visualization 5: Top 10 Table
- [ ] Add geography type filter (CA/ZIP toggle)
- [ ] Test geographic joins

---

### Step 3.4: Dashboard 4 - Traffic Forecasting & Construction Planning (2-3 hours)

**Requirements Coverage:** Requirements 4 & 9

**Layout Structure:**
```
┌─────────────────────────────────────────────────────┐
│  TRAFFIC FORECASTING & CONSTRUCTION PLANNING        │
├─────────────────────────────────────────────────────┤
│  Filters: ZIP Code | Forecast Horizon (7/30/90 days)│
├────────────────────┬────────────────────────────────┤
│                    │                                │
│  90-DAY FORECAST   │   SEASONAL PATTERNS           │
│  (Multi-line)      │   (Monthly Aggregation)       │
│  Selected ZIPs     │   "Construction Season"       │
│                    │                               │
├────────────────────┴────────────────────────────────┤
│  LOW-TRAFFIC WINDOWS (Bar Chart - Best for Roadwork)│
├────────────────────┬────────────────────────────────┤
│  DAY-OF-WEEK       │  ZIP COMPARISON               │
│  HEATMAP           │  (Small Multiples)            │
│  Traffic Intensity │                               │
├────────────────────┴────────────────────────────────┤
│  MODEL PERFORMANCE DASHBOARD                        │
│  MAE | MAPE | R² by ZIP (Gauge Charts)             │
└─────────────────────────────────────────────────────┘
```

**Visualizations to Create:**

1. **90-Day Forecast (Multi-Line with Confidence Bands)**
   - Data: gold_traffic_forecasts_by_zip
   - X-Axis: forecast_date
   - Y-Axis: predicted_traffic_volume
   - Lines: 5-10 selected ZIPs
   - Shaded Area: traffic_volume_lower/upper (80% confidence)
   - SQL Query: Traffic #1 (Next 7 Days) or #2 (Weekly Aggregated)

2. **Seasonal Patterns (Grouped Bar Chart)**
   - Data: gold_traffic_forecasts_by_zip
   - X-Axis: MONTH(forecast_date)
   - Y-Axis: AVG(predicted_traffic_volume)
   - Grouped by: Year
   - Annotation: "Construction Season" = Low traffic months
   - SQL Query: Traffic #3 (Monthly Summary)

3. **Low-Traffic Windows (Horizontal Bar Chart)**
   - Data: gold_traffic_forecasts_by_zip (aggregate by day-of-week)
   - X-Axis: AVG(predicted_traffic_volume)
   - Y-Axis: Day of Week
   - Color: Traffic level (Green=Low, Red=High)
   - Sorted: ASC (lowest traffic first)
   - Label: "Best Days for Roadwork"
   - SQL Query: Traffic #9 (Day-of-Week Patterns)

4. **Day-of-Week Traffic Heatmap**
   - Data: gold_taxi_hourly_by_zip (historical patterns)
   - X-Axis: trip_hour (0-23)
   - Y-Axis: DAYOFWEEK(trip_date)
   - Color: AVG(total_trips) - intensity
   - Shows: Hourly patterns for construction scheduling

5. **ZIP Comparison (Small Multiples)**
   - Data: gold_traffic_forecasts_by_zip
   - Layout: 3x3 grid of mini line charts
   - Each Chart: One ZIP's 90-day forecast
   - Allows: Side-by-side comparison
   - Sorted: By total forecasted volume (DESC)

6. **Model Performance Metrics (Gauge Charts)**
   - Data: gold_forecast_model_metrics
   - Metrics: MAE, MAPE, R²
   - Display: 3 gauge charts
   - Color: Green (good) → Red (poor)
   - Filter: By ZIP to see individual model performance
   - SQL Query: Traffic #7 (Model Performance Metrics)

7. **Uncertainty Analysis (Box Plot or Violin Plot)**
   - Data: gold_traffic_forecasts_by_zip
   - X-Axis: zip_code
   - Y-Axis: predicted_traffic_volume
   - Show: Confidence band width (upper - lower)
   - Purpose: Identify ZIPs with high forecast uncertainty
   - SQL Query: Traffic #8 (Uncertainty Analysis)

**Action Items:**
- [ ] Create dashboard page layout
- [ ] Build visualization 1: 90-Day Forecast
- [ ] Build visualization 2: Seasonal Patterns
- [ ] Build visualization 3: Low-Traffic Windows
- [ ] Build visualization 4: Heatmap
- [ ] Build visualization 5: Small Multiples
- [ ] Build visualization 6: Model Metrics
- [ ] Build visualization 7: Uncertainty Analysis
- [ ] Add forecast horizon filter (7/30/90 days)
- [ ] Test ZIP multi-select functionality

---

### Step 3.5: Dashboard 5 - Economic Development & Investment (1.5-2 hours)

**Requirements Coverage:** Requirements 5 & 6

**Layout Structure:**
```
┌─────────────────────────────────────────────────────┐
│  ECONOMIC DEVELOPMENT & INVESTMENT DASHBOARD        │
├─────────────────────────────────────────────────────┤
│  Filters: Community Area | ZIP Code                 │
├────────────────────┬────────────────────────────────┤
│                    │                                │
│  TOP 5 INVESTMENT  │   PERMIT ACTIVITY             │
│  TARGETS MAP       │   (Bar Chart)                 │
│  (High Unemp/Pov)  │   By Socioeconomic Status     │
│                    │                               │
├────────────────────┴────────────────────────────────┤
│  LOAN ELIGIBILITY MAP (Small Business Loan Program) │
├────────────────────┬────────────────────────────────┤
│  INCOME vs NEW     │  FEE WAIVER IMPACT            │
│  CONSTRUCTION      │  (Comparison Chart)           │
│  (Scatter Plot)    │                               │
├────────────────────┴────────────────────────────────┤
│  NEW CONSTRUCTION TRENDS (Time Series by Income)   │
└─────────────────────────────────────────────────────┘
```

**Visualizations to Create:**

1. **Top 5 Investment Targets Map**
   - Data: raw_public_health_stats
   - Geography: community_area_boundaries
   - Filter: Top 5 by Unemployment + "Below Poverty Level"
   - Color: Red gradient (darker = higher need)
   - Tooltip: CA name, unemployment %, poverty %, per capita income
   - Annotation: "Recommended for Permit Fee Waiver"

2. **Permit Activity by Socioeconomic Status (Grouped Bar)**
   - Data: JOIN silver_permits_enriched + raw_public_health_stats
   - X-Axis: Unemployment quintile (Low → High)
   - Y-Axis: COUNT(permits)
   - Grouped by: permit_type
   - Shows: Correlation between economic status and construction

3. **Loan Eligibility Map**
   - Data: gold_loan_targets
   - Geography: zip_code_boundaries
   - Filter: is_loan_eligible = TRUE
   - Color: eligibility_index (gradient, higher = more eligible)
   - Tooltip: ZIP, per_capita_income, total_permits_new_construction, eligibility_index
   - Label: "Illinois Small Business Emergency Loan Fund Delta"

4. **Income vs NEW CONSTRUCTION (Scatter Plot)**
   - Data: gold_loan_targets
   - X-Axis: per_capita_income
   - Y-Axis: total_permits_new_construction
   - Color: is_loan_eligible (Green=Eligible, Gray=Not)
   - Size: population
   - Reference Line: $30,000 income threshold
   - Shows: Inverse relationship (low income = few permits)

5. **Fee Waiver Impact Analysis (Comparison Chart)**
   - Data: silver_permits_enriched (filter: Top 5 high-unemployment CAs)
   - Metrics:
     - Current: SUM(total_fee) - actual fees collected
     - Proposed: $0 (if fee waiver applied)
   - Display: Side-by-side bars
   - Label: "Potential Fee Waiver Savings: $XXX"

6. **NEW CONSTRUCTION Trends (Multi-Line Time Series)**
   - Data: JOIN silver_permits_enriched + raw_public_health_stats
   - X-Axis: DATE_TRUNC(issue_date, YEAR)
   - Y-Axis: COUNT(permits) WHERE permit_type = "PERMIT - NEW CONSTRUCTION"
   - Lines: Grouped by income quintile (Low, Med-Low, Med, Med-High, High)
   - Shows: Construction activity trends by economic status

**Action Items:**
- [ ] Create dashboard page layout
- [ ] Build visualization 1: Investment Targets Map
- [ ] Build visualization 2: Permit Activity
- [ ] Build visualization 3: Loan Eligibility Map
- [ ] Build visualization 4: Income Scatter
- [ ] Build visualization 5: Fee Waiver Impact
- [ ] Build visualization 6: Trends by Income
- [ ] Add CA/ZIP filters
- [ ] Calculate fee waiver savings metric

---

## PHASE 4: TESTING & REFINEMENT (2-3 hours)

### Step 4.1: Functional Testing

**Performance Testing:**
- [ ] Test query execution time for each visualization (<5 seconds target)
- [ ] Test dashboard load time (<10 seconds for initial load)
- [ ] Test with large date ranges (full 5 years of data)
- [ ] Test with multiple ZIPs selected (10-20 ZIPs)
- [ ] Identify and optimize slow queries

**Interactivity Testing:**
- [ ] Test all filter interactions (date, ZIP, CA, etc.)
- [ ] Test drill-down functionality (ZIP → details)
- [ ] Test cross-filtering (click map → update charts)
- [ ] Test parameter changes (forecast horizon, etc.)
- [ ] Test mobile responsiveness (if applicable)

**Data Validation:**
- [ ] Verify totals match source tables
- [ ] Check for null/missing values in visualizations
- [ ] Validate forecast date ranges (future, not past)
- [ ] Confirm geographic boundaries render correctly
- [ ] Cross-check calculations (%, averages, etc.)

**Action Items:**
- [ ] Create test plan checklist
- [ ] Execute all test cases
- [ ] Document issues in tracking sheet
- [ ] Prioritize fixes (P0 = blocking, P1 = high, P2 = nice-to-have)
- [ ] Fix P0 and P1 issues

---

### Step 4.2: User Experience Refinement

**Visual Design:**
- [ ] Apply consistent color palette across all dashboards
- [ ] Ensure sufficient contrast for accessibility
- [ ] Add clear titles and legends to all charts
- [ ] Use consistent formatting (dates, numbers, percentages)
- [ ] Add helpful tooltips with context

**Layout Optimization:**
- [ ] Arrange visualizations by priority (most important = top-left)
- [ ] Ensure logical flow (filters → overview → details)
- [ ] Add white space to reduce clutter
- [ ] Group related visualizations together
- [ ] Ensure responsive layout (if applicable)

**Annotations & Context:**
- [ ] Add text boxes with key insights
- [ ] Add reference lines (e.g., $30K income threshold)
- [ ] Annotate major events (e.g., COVID waves)
- [ ] Add "Last Updated" timestamp
- [ ] Add data source attribution

**Action Items:**
- [ ] Review each dashboard with fresh eyes
- [ ] Get feedback from colleague (if available)
- [ ] Make design adjustments
- [ ] Ensure consistency across all 5 dashboards

---

### Step 4.3: Stakeholder Review (if applicable)

**Prepare Review Session:**
- [ ] Schedule 30-60 min review meeting
- [ ] Prepare demo script (walkthrough of each dashboard)
- [ ] Create list of discussion questions
- [ ] Document feedback in shared doc

**Review Checklist:**
- [ ] Demonstrate each dashboard functionality
- [ ] Explain data sources and calculations
- [ ] Discuss Midway airport limitation (Req 2)
- [ ] Gather feedback on visualizations
- [ ] Identify additional requirements
- [ ] Prioritize enhancement requests

**Action Items:**
- [ ] Conduct review session
- [ ] Document all feedback
- [ ] Create enhancement backlog
- [ ] Implement must-have changes
- [ ] Schedule follow-up if needed

---

## PHASE 5: DOCUMENTATION & DEPLOYMENT (2-3 hours)

### Step 5.1: User Documentation

**Create User Guide:**

**File:** `/dashboards/documentation/user_guide.md`

**Contents:**
1. **Overview**
   - Purpose of dashboards
   - How to access
   - System requirements

2. **Dashboard Descriptions**
   - Dashboard 1: COVID-19 Alerts & Safety
   - Dashboard 2: Airport Traffic Analysis
   - Dashboard 3: Vulnerable Communities
   - Dashboard 4: Traffic Forecasting & Construction Planning
   - Dashboard 5: Economic Development & Investment

3. **How to Use**
   - Navigation between dashboards
   - Using filters and parameters
   - Interpreting visualizations
   - Exporting data

4. **FAQs**
   - Why is Midway data limited?
   - How often is data refreshed?
   - What does "adjusted_risk_score" mean?
   - How are forecasts generated?

5. **Troubleshooting**
   - Dashboard not loading
   - Filters not working
   - Data looks incorrect
   - Who to contact for support

**Action Items:**
- [ ] Write user guide (10-15 pages)
- [ ] Add screenshots of each dashboard
- [ ] Include step-by-step instructions
- [ ] Review for clarity and completeness

---

### Step 5.2: Data Dictionary

**Create Data Dictionary:**

**File:** `/dashboards/documentation/data_dictionary.md`

**Contents:**
- **For Each Table Used:**
  - Table name and purpose
  - Field definitions
  - Data types
  - Sample values
  - Business rules
  - Join keys

**Example Entry:**
```markdown
## gold_covid_hotspots

**Purpose:** Historical COVID-19 risk analysis by ZIP code with taxi trip correlation

**Fields:**
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| zip_code | STRING | Chicago ZIP code | "60601" |
| week_start | DATE | Start date of week (Monday) | 2024-05-12 |
| cases_weekly | INTEGER | COVID cases reported this week | 42 |
| risk_category | STRING | Low/Medium/High risk classification | "Medium" |
| adjusted_risk_score | FLOAT | Composite risk score (0-10) | 3.45 |
| total_trips_to_zip | INTEGER | Taxi trips to this ZIP this week | 1,234 |

**Date Range:** 2020-03-01 to 2024-05-12 (219 weeks)
**Granularity:** Weekly (Sunday-Saturday)
**Refresh:** Weekly (manual trigger)
```

**Action Items:**
- [ ] Document all tables used in dashboards
- [ ] Define all calculated fields
- [ ] Explain business logic (e.g., risk categorization)
- [ ] Add data lineage (source → transformations → dashboard)

---

### Step 5.3: Deployment & Access

**Deployment Steps:**

**For Looker Studio:**
- [ ] Publish dashboards (change from edit to view mode)
- [ ] Set sharing permissions (view/edit/owner)
- [ ] Generate shareable links
- [ ] Embed in website (if applicable)

**For Looker (Enterprise):**
- [ ] Deploy LookML models to production
- [ ] Create user groups (admin, analyst, viewer)
- [ ] Assign permissions by group
- [ ] Schedule data refreshes
- [ ] Set up email alerts

**For Tableau:**
- [ ] Publish workbooks to Tableau Server/Cloud
- [ ] Set up data source refresh schedules
- [ ] Configure user permissions
- [ ] Enable mobile access (if applicable)
- [ ] Set up subscriptions (email snapshots)

**Action Items:**
- [ ] Complete deployment steps for chosen tool
- [ ] Test access from different user roles
- [ ] Verify scheduled refreshes are working
- [ ] Send access instructions to stakeholders

---

### Step 5.4: Monitoring & Maintenance Plan

**Set Up Monitoring:**
- [ ] Create dashboard health check query
- [ ] Set up alerts for data freshness (<24 hours old)
- [ ] Monitor query performance (alert if >10 seconds)
- [ ] Track user engagement (views, filters used)

**Maintenance Schedule:**
```
Daily:
- Check data refresh status
- Monitor dashboard load times

Weekly:
- Review model performance metrics (MAE, MAPE, R²)
- Check for new COVID data availability
- Update forecasts if new data available

Monthly:
- Review user feedback
- Analyze usage patterns
- Identify optimization opportunities
- Update documentation if needed

Quarterly:
- Comprehensive dashboard review
- Add new features/visualizations
- Archive old dashboards (if applicable)
- Stakeholder feedback session
```

**Action Items:**
- [ ] Document maintenance procedures
- [ ] Assign owner/responsibility
- [ ] Set up monitoring alerts
- [ ] Create maintenance calendar

---

### Step 5.5: Version Control & Backup

**Dashboard Configuration Backup:**
- [ ] Export dashboard configurations/definitions
- [ ] Save to `/dashboards/exports/dashboard_configs/`
- [ ] Include:
  - Data source connections
  - Query definitions
  - Visualization settings
  - Filter configurations
  - Layout specifications

**Version Control:**
```
/dashboards/exports/dashboard_configs/
├── v2.20.0_2025-11-14/
│   ├── covid_alerts_dashboard.json
│   ├── airport_traffic_dashboard.json
│   ├── vulnerable_communities_dashboard.json
│   ├── traffic_forecasting_dashboard.json
│   └── economic_development_dashboard.json
└── README.md (version history)
```

**Action Items:**
- [ ] Export all dashboard configurations
- [ ] Save to version-controlled folder
- [ ] Document version number (v2.20.0)
- [ ] Create restore instructions
- [ ] Test restore process

---

## COMPLETION CHECKLIST

### Phase 1: Setup ✅
- [ ] BI tool selected and configured
- [ ] BigQuery connection established
- [ ] Project folder structure created
- [ ] Color palette defined

### Phase 2: Data Sources ✅
- [ ] 10 data sources created and tested
- [ ] 22 SQL queries imported
- [ ] Parameters and filters configured
- [ ] Data source documentation complete

### Phase 3: Dashboards ✅
- [ ] Dashboard 1: COVID-19 Alerts (6 visualizations)
- [ ] Dashboard 2: Airport Traffic (5 visualizations)
- [ ] Dashboard 3: Vulnerable Communities (5 visualizations)
- [ ] Dashboard 4: Traffic Forecasting (7 visualizations)
- [ ] Dashboard 5: Economic Development (6 visualizations)
- [ ] All filters and interactivity working

### Phase 4: Testing ✅
- [ ] Functional testing complete
- [ ] UX refinement done
- [ ] Stakeholder review conducted (if applicable)
- [ ] All P0/P1 issues resolved

### Phase 5: Deployment ✅
- [ ] User guide created
- [ ] Data dictionary created
- [ ] Dashboards deployed and shared
- [ ] Monitoring set up
- [ ] Configurations backed up

---

## ESTIMATED TIME BREAKDOWN

| Phase | Activities | Estimated Time |
|-------|-----------|----------------|
| **Phase 1** | Tool selection, BigQuery setup, environment prep | 1-2 hours |
| **Phase 2** | Data sources, queries, parameters | 1-2 hours |
| **Phase 3** | Build 5 dashboards (29 visualizations total) | 6-10 hours |
| **Phase 4** | Testing, refinement, stakeholder review | 2-3 hours |
| **Phase 5** | Documentation, deployment, backup | 2-3 hours |
| **TOTAL** | | **12-19 hours** |

**Delivery Timeline:**
- **MVP (Basic dashboards):** 1-2 days
- **Production-Ready (With documentation):** 2-3 days

---

## RISKS & MITIGATION

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **BI tool learning curve** | Delays | Medium | Choose Looker Studio for faster MVP |
| **Query performance issues** | Poor UX | Low | All queries pre-tested, <2 sec |
| **Midway data limitation** | Incomplete analysis | Low | Add clear note, focus on O'Hare |
| **Stakeholder scope creep** | Timeline slip | Medium | Define v2.20.0 scope, defer extras to v2.21.0 |
| **Data refresh failures** | Stale dashboards | Low | Set up monitoring alerts |

---

## SUCCESS CRITERIA

✅ **Dashboard Deployment Complete When:**
1. All 5 dashboards deployed and accessible
2. All 29 visualizations rendering correctly
3. Filters and parameters working
4. Query performance <5 seconds
5. User guide and data dictionary published
6. Monitoring and maintenance plan in place
7. Stakeholder approval received (if applicable)

✅ **Quality Standards:**
- 100% of required visualizations implemented
- 0 P0 (critical) bugs
- <3 P1 (high) bugs (documented for v2.21.0)
- User guide covers 90%+ of use cases
- Dashboard load time <10 seconds

---

## POST-DEPLOYMENT (v2.21.0 Ideas)

**Future Enhancements:**
1. Add weather API integration (Req 6 - temperature correlation)
2. Improve Midway airport identification logic
3. Add real-time alerts (email/SMS when COVID risk spikes)
4. Create mobile-optimized dashboards
5. Add predictive "What-if" scenarios
6. Integrate violations data (Req 7 - if data source identified)
7. Add export to PDF/PowerPoint functionality
8. Create executive summary dashboard (KPIs only)
9. Add natural language query interface
10. Implement row-level security (if multi-tenant)

---

**End of Implementation Plan**
**Status:** Ready to Execute
**Next Step:** Confirm BI tool choice → Begin Phase 1
