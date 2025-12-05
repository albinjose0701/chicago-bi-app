# Looker Studio Quick Start Guide - Chicago BI App
**Timeline:** 1-2 Days for Full Suite
**Approach:** MVP First (COVID + Traffic) → Complete Suite
**Date:** November 14, 2025

---

## 🚀 PHASE 1: SETUP (30-45 minutes)

### Step 1.1: Access Looker Studio

**Go to:** https://lookerstudio.google.com/

**Action Steps:**
1. Sign in with your Google account (same account with BigQuery access)
2. If prompted, accept Terms of Service
3. Click **"Create"** → **"Report"** (or "Data Source" to start)

✅ **Checkpoint:** You should see the Looker Studio home page

---

### Step 1.2: Connect to BigQuery

**Create Your First Data Source:**

1. Click **"Create"** → **"Data Source"**
2. In the connector gallery, search for **"BigQuery"**
3. Click the **BigQuery** connector
4. Authorize Looker Studio to access BigQuery (if first time)
5. You'll see three columns:
   - **MY PROJECTS** (left)
   - **DATASET** (middle)
   - **TABLE** (right)

**Select Your First Table:**
```
Project:  chicago-bi-app-msds-432-476520
Dataset:  gold_data
Table:    gold_covid_hotspots
```

6. Click **"CONNECT"** (top right)
7. You'll see the field list (zip_code, week_start, cases_weekly, etc.)
8. Click **"CREATE REPORT"** (top right)
9. When prompted "Add data to report?", click **"ADD TO REPORT"**

✅ **Checkpoint:** You should see a blank report canvas with a data panel on the right

**Name Your Data Source:**
- Top-left corner: Rename "Copy of gold_covid_hotspots" → **"COVID Hotspots Data"**

---

### Step 1.3: Test Connection with Simple Visualization

**Create a Test Chart:**

1. In the toolbar, click **"Add a chart"** → **"Table"**
2. Draw a rectangle on the canvas
3. In the **Data** panel (right side):
   - **Dimension:** zip_code
   - **Metric:** cases_weekly (aggregation: SUM)
4. You should see a table with ZIP codes and case counts

✅ **Checkpoint:** If you see data, your connection works!

**Delete this test chart** (we'll build properly structured dashboards next)

---

## 📊 PHASE 2: DATA SOURCE CONFIGURATION (1-2 hours)

We need to create 10 data sources for all dashboards. Let's start with the MVP sources first.

### Data Source Setup Order

**MVP (Dashboards 1 & 4):**
1. ✅ COVID Hotspots (already done above)
2. COVID Forecasts
3. Traffic Forecasts
4. Historical Traffic (Daily)
5. Forecast Model Metrics

**Full Suite (Dashboards 2, 3, 5):**
6. Airport Trips
7. CCVI High-Risk Areas
8. Socioeconomic Data
9. Building Permits
10. Loan Eligibility

---

### Data Source 2: COVID Forecasts

**Steps:**
1. Click **"Resource"** → **"Manage added data sources"**
2. Click **"+ ADD A DATA SOURCE"**
3. Select **BigQuery** connector
4. Navigate to:
   ```
   Project:  chicago-bi-app-msds-432-476520
   Dataset:  gold_data
   Table:    gold_covid_risk_forecasts
   ```
5. Click **"CONNECT"** → **"ADD TO REPORT"**
6. Rename: **"COVID Forecasts Data"**

**Key Fields to Note:**
- zip_code (dimension)
- forecast_date (dimension, type: Date)
- predicted_risk_score (metric)
- predicted_risk_category (dimension)
- alert_level (dimension)
- risk_score_lower (metric)
- risk_score_upper (metric)

✅ **Checkpoint:** Data source added successfully

---

### Data Source 3: Traffic Forecasts

**Steps:**
1. **"+ ADD A DATA SOURCE"** → **BigQuery**
2. Navigate to:
   ```
   Project:  chicago-bi-app-msds-432-476520
   Dataset:  gold_data
   Table:    gold_traffic_forecasts_by_zip
   ```
3. Click **"CONNECT"** → **"ADD TO REPORT"**
4. Rename: **"Traffic Forecasts Data"**

**Key Fields:**
- zip_code (dimension)
- forecast_date (dimension, type: Date)
- predicted_traffic_volume (metric)
- traffic_volume_lower (metric)
- traffic_volume_upper (metric)
- trend (metric)
- yearly (metric)
- weekly (metric)

✅ **Checkpoint:** Data source added

---

### Data Source 4: Historical Traffic (Daily)

**Steps:**
1. **"+ ADD A DATA SOURCE"** → **BigQuery**
2. Navigate to:
   ```
   Project:  chicago-bi-app-msds-432-476520
   Dataset:  gold_data
   Table:    gold_taxi_daily_by_zip
   ```
3. Click **"CONNECT"** → **"ADD TO REPORT"**
4. Rename: **"Historical Traffic Data"**

**Key Fields:**
- trip_date (dimension, type: Date)
- pickup_zip (dimension)
- dropoff_zip (dimension)
- total_trips (metric)
- avg_fare (metric)
- total_revenue (metric)

✅ **Checkpoint:** Data source added

---

### Data Source 5: Forecast Model Metrics

**Steps:**
1. **"+ ADD A DATA SOURCE"** → **BigQuery**
2. Navigate to:
   ```
   Project:  chicago-bi-app-msds-432-476520
   Dataset:  gold_data
   Table:    gold_forecast_model_metrics
   ```
3. Click **"CONNECT"** → **"ADD TO REPORT"**
4. Rename: **"Model Metrics Data"**

**Key Fields:**
- model_name (dimension)
- forecast_type (dimension)
- zip_code (dimension)
- mae (metric)
- mape (metric)
- r_squared (metric)

✅ **Checkpoint:** MVP data sources complete (5 of 10)

---

### Set Up Date Range Control (Global Filter)

**Add Date Range Filter:**
1. Click **"Add a control"** → **"Date range control"**
2. Place it at the top of your report
3. In properties panel:
   - **Default date range:** Last 90 days
   - **Show comparison date range:** OFF (for now)

This filter will apply to all charts on the page.

✅ **Checkpoint:** Date filter working

---

## 🎨 PHASE 3A: BUILD MVP - DASHBOARD 1 (COVID Alerts) (2-3 hours)

### Dashboard Setup

**Create New Report:**
1. Go back to Looker Studio home
2. Click **"Create"** → **"Report"**
3. Name it: **"Chicago BI - COVID-19 Alerts & Driver Safety"**

**Page Setup:**
1. Click **"Theme and layout"** (top right)
2. Choose a clean template (e.g., "Simple Light")
3. Set canvas size: **1600 x 1200** (or leave default)

---

### Visualization 1: Current Risk Map (Choropleth)

**IMPORTANT NOTE:** Looker Studio has limited native choropleth support. We'll use a workaround:

**Option A - Geo Chart (Simpler):**
1. Add chart → **"Geo chart"**
2. Draw on canvas (make it large, ~600x400)
3. **Data source:** COVID Hotspots Data
4. **Geo dimension:** zip_code
5. **Metric:** cases_weekly (SUM)
6. **Color metric:** Add → Choose cases_weekly
7. In **Style** tab:
   - **Color scale:** Red gradient
   - **Missing data color:** Gray
8. Click **"View"** mode to test

**Option B - Use Custom Query with Geography (Advanced):**
We'll do this if Option A doesn't work well.

✅ **Checkpoint:** Map showing ZIP codes colored by COVID cases

---

### Visualization 2: Top 10 High-Risk ZIPs (Bar Chart)

1. Add chart → **"Bar chart"**
2. **Data source:** COVID Hotspots Data
3. **Dimension:** zip_code
4. **Metric:** adjusted_risk_score (MAX or AVG)
5. **Sort:** By adjusted_risk_score DESC
6. **Filter:** Date dimension = Last 7 days (or latest week)
7. In **Style** tab:
   - **Number of bars shown:** 10
   - **Bar color:** Based on risk_category (Green/Yellow/Red)

**Add Color by Risk Category:**
1. In Data panel, click **"+ Add a field"**
2. Create calculated field:
   ```
   CASE
     WHEN risk_category = "Low" THEN "#10B981"
     WHEN risk_category = "Medium" THEN "#F59E0B"
     WHEN risk_category = "High" THEN "#EF4444"
     ELSE "#6B7280"
   END
   ```
3. Name: **"Risk Color"**
4. Use this as **Series color**

✅ **Checkpoint:** Bar chart showing top 10 ZIPs

---

### Visualization 3: 12-Week Risk Forecast (Line Chart)

1. Add chart → **"Time series chart"**
2. **Data source:** COVID Forecasts Data
3. **Date dimension:** forecast_date
4. **Metric:** predicted_risk_score (AVG)
5. **Breakdown dimension:** zip_code
6. **Filter:** Top 5 ZIPs by predicted_risk_score
7. In **Style** tab:
   - **Show data labels:** No
   - **Line smoothing:** Medium
   - **Line thickness:** 2px

**Add Confidence Bands (Optional - Advanced):**
- Add two more metrics: risk_score_lower, risk_score_upper
- Use "Area chart" instead of line chart
- Create layered effect

✅ **Checkpoint:** Line chart showing forecast trends

---

### Visualization 4: Taxi Correlation (Scatter Chart)

1. Add chart → **"Scatter chart"**
2. **Data source:** COVID Hotspots Data
3. **X-axis:** total_trips_to_zip (SUM)
4. **Y-axis:** cases_weekly (SUM)
5. **Bubble size:** population
6. **Bubble color:** risk_category
7. In **Style** tab:
   - **X-axis scale:** Logarithmic (if range is wide)
   - **Show regression line:** Yes (optional)

✅ **Checkpoint:** Scatter plot showing correlation

---

### Visualization 5: Historical Trends (Combo Chart)

1. Add chart → **"Combo chart"**
2. **Data source:** COVID Hotspots Data
3. **Date dimension:** week_start
4. **Left Y-axis (bars):** cases_weekly (SUM)
5. **Right Y-axis (line):** total_trips_to_zip (SUM)
6. **Filter:** Date range = Last 52 weeks (or all data)
7. In **Style** tab:
   - **Bar color:** Red
   - **Line color:** Blue
   - **Show axis titles:** Yes

**Add Annotations for Pandemic Waves:**
- Use "Annotation" feature to mark major waves (Nov 2020, Dec 2021, Jan 2022)

✅ **Checkpoint:** Dual-axis time series working

---

### Visualization 6: Alert Summary Table

1. Add chart → **"Table"**
2. **Data source:** COVID Forecasts Data
3. **Dimensions:**
   - zip_code
   - predicted_risk_category
   - alert_level
4. **Metrics:**
   - predicted_risk_score (AVG)
5. **Sort:** By alert_level (CRITICAL → NONE)
6. In **Style** tab:
   - **Conditional formatting:** Color rows by alert_level
   - **Show row numbers:** Yes

**Conditional Formatting:**
- alert_level = "CRITICAL" → Red background
- alert_level = "WARNING" → Orange background
- alert_level = "CAUTION" → Yellow background
- alert_level = "NONE" → White background

✅ **Checkpoint:** Dashboard 1 complete with 6 visualizations

---

## 🎨 PHASE 3B: BUILD MVP - DASHBOARD 4 (Traffic Forecasting) (2-3 hours)

### Create New Page

1. Click **"Page"** → **"New page"**
2. Name: **"Traffic Forecasting & Construction Planning"**

---

### Visualization 1: 90-Day Forecast (Line Chart with Bands)

1. Add chart → **"Time series chart"**
2. **Data source:** Traffic Forecasts Data
3. **Date dimension:** forecast_date
4. **Metric:** predicted_traffic_volume (SUM)
5. **Breakdown dimension:** zip_code
6. **Filter:** Top 5-10 ZIPs by predicted_traffic_volume

**Add Confidence Bands:**
1. Change chart type to **"Area chart"**
2. Add metrics:
   - traffic_volume_upper (lighter shade)
   - predicted_traffic_volume (main line)
   - traffic_volume_lower (lighter shade)
3. Use stacking: "None" (overlapping)

✅ **Checkpoint:** Forecast line chart with confidence bands

---

### Visualization 2: Seasonal Patterns (Bar Chart)

1. Add chart → **"Column chart"**
2. **Data source:** Traffic Forecasts Data
3. **Dimension:** MONTH(forecast_date)
4. **Metric:** AVG(predicted_traffic_volume)
5. **Breakdown:** YEAR(forecast_date)
6. In **Style** tab:
   - **Stacking:** None (grouped bars)
   - **Show data labels:** Yes

**Add Annotation:**
- Text box: "Construction Season: November - March (Low Traffic)"

✅ **Checkpoint:** Seasonal bar chart

---

### Visualization 3: Low-Traffic Windows (Horizontal Bar)

1. Add chart → **"Bar chart"**
2. **Data source:** Traffic Forecasts Data
3. **Dimension:** Custom field → DAYOFWEEK(forecast_date)
   - Create calculated field:
     ```
     CASE
       WHEN DAYOFWEEK(forecast_date) = 1 THEN "Sunday"
       WHEN DAYOFWEEK(forecast_date) = 2 THEN "Monday"
       WHEN DAYOFWEEK(forecast_date) = 3 THEN "Tuesday"
       WHEN DAYOFWEEK(forecast_date) = 4 THEN "Wednesday"
       WHEN DAYOFWEEK(forecast_date) = 5 THEN "Thursday"
       WHEN DAYOFWEEK(forecast_date) = 6 THEN "Friday"
       WHEN DAYOFWEEK(forecast_date) = 7 THEN "Saturday"
     END
     ```
4. **Metric:** AVG(predicted_traffic_volume)
5. **Sort:** By metric ASC (lowest first)
6. **Bar color:** Gradient (Green=Low, Red=High)

✅ **Checkpoint:** Day-of-week ranking

---

### Visualization 4: Day-of-Week Heatmap

1. Add chart → **"Pivot table"** (styled as heatmap)
2. **Data source:** Historical Traffic Data
3. **Row dimension:** DAYOFWEEK(trip_date)
4. **Column dimension:** HOUR(trip_date) [if hourly data available]
5. **Metric:** AVG(total_trips)
6. In **Style** tab:
   - **Heatmap colors:** Green (low) → Red (high)
   - **Show totals:** No

✅ **Checkpoint:** Heatmap showing traffic patterns

---

### Visualization 5: ZIP Comparison (Small Multiples)

**Note:** Looker Studio doesn't have native small multiples. Use alternative:

**Option A - Use Filters:**
1. Create standard time series chart
2. Add ZIP code filter dropdown
3. Users can switch between ZIPs

**Option B - Multiple Charts:**
1. Create 6-9 small time series charts
2. Each hard-coded to a specific ZIP
3. Arrange in grid layout

Choose **Option A** for flexibility.

✅ **Checkpoint:** ZIP comparison working

---

### Visualization 6: Model Performance (Scorecard)

1. Add chart → **"Scorecard"**
2. **Data source:** Model Metrics Data
3. **Metric:** AVG(mae)
4. **Filter:** forecast_type = "traffic"
5. Style:
   - **Compact numbers:** Yes
   - **Show comparison:** Optional

**Create 3 Scorecards:**
- MAE (average error)
- MAPE (percentage error)
- R² (model fit)

Arrange side-by-side.

✅ **Checkpoint:** Model metrics displayed

---

### Visualization 7: Uncertainty Analysis (Box Plot Alternative)

**Note:** Looker Studio doesn't have native box plots. Use bar chart:

1. Add chart → **"Bar chart"**
2. **Data source:** Traffic Forecasts Data
3. **Dimension:** zip_code
4. **Metric:** Custom field → Confidence band width
   ```
   traffic_volume_upper - traffic_volume_lower
   ```
5. **Sort:** By metric DESC (highest uncertainty first)
6. **Color:** Gradient (Red=high uncertainty, Green=low)

✅ **Checkpoint:** Dashboard 4 complete with 7 visualizations

---

## ✅ MVP CHECKPOINT (After ~4-6 hours)

You should now have:
- ✅ Dashboard 1: COVID-19 Alerts (6 visualizations)
- ✅ Dashboard 4: Traffic Forecasting (7 visualizations)
- ✅ 5 data sources configured
- ✅ Basic interactivity working

**Test Your MVP:**
1. Share with yourself via email (test sharing)
2. Click through all filters
3. Verify data is loading correctly
4. Check for any errors

**Decision Point:**
- ✅ MVP looks good → Continue to Dashboards 2, 3, 5
- ⚠️ Issues found → Debug before continuing

---

## 🚀 PHASE 3C: COMPLETE FULL SUITE (4-6 hours)

Now we'll build the remaining 3 dashboards following the same pattern.

### Set Up Remaining Data Sources (1 hour)

**Data Source 6: Airport Trips**
```
Project:  chicago-bi-app-msds-432-476520
Dataset:  silver_data
Table:    silver_trips_enriched

Key Filter: is_airport_trip = TRUE (set as default filter)
```

**Data Source 7: CCVI High-Risk Areas**
```
Dataset:  silver_data
Table:    silver_ccvi_high_risk
```

**Data Source 8: Socioeconomic Data**
```
Dataset:  raw_data
Table:    raw_public_health_stats
```

**Data Source 9: Building Permits**
```
Dataset:  silver_data
Table:    silver_permits_enriched
```

**Data Source 10: Loan Eligibility**
```
Dataset:  gold_data
Table:    gold_loan_targets
```

---

### Dashboard 2: Airport Traffic (1.5-2 hours)

**Create new page:** "Airport Traffic Monitoring"

**5 Visualizations:**
1. **Destination Heatmap:** Geo chart, dropoff_zip, color by trip count
2. **Traffic Trends:** Time series, airport trips over time, split by airport
3. **Top 10 Routes:** Bar chart, dropoff_neighborhood, sorted DESC
4. **COVID Overlay:** Combo chart, trips + COVID risk
5. **Time of Day:** Pivot table heatmap, hour x day of week

**Add Filter:** Community area = 76 (O'Hare) or 56 (Midway)

**Add Text Box:** "Note: Midway data may be under-represented (42K vs O'Hare's 8M trips)"

✅ **Checkpoint:** Dashboard 2 complete

---

### Dashboard 3: Vulnerable Communities (1-1.5 hours)

**Create new page:** "CCVI High-Risk Communities"

**5 Visualizations:**
1. **CCVI Map:** Geo chart, geography_id, color by ccvi_score
2. **Trip Trends:** Time series, trips from/to high CCVI areas
3. **Double Burden:** Geo chart, join CCVI + COVID data, color by both
4. **Pooled Rides:** Bar chart, % pooled by area
5. **Top 10 Table:** Table, ranked by CCVI score

✅ **Checkpoint:** Dashboard 3 complete

---

### Dashboard 5: Economic Development (1.5-2 hours)

**Create new page:** "Economic Development & Investment"

**6 Visualizations:**
1. **Investment Targets Map:** Geo chart, top 5 by unemployment+poverty
2. **Permit Activity:** Bar chart, permits by unemployment quintile
3. **Loan Eligibility Map:** Geo chart, filter is_loan_eligible=TRUE
4. **Income Scatter:** Scatter chart, income vs NEW CONSTRUCTION permits
5. **Fee Waiver Impact:** Bar chart, current vs proposed fees
6. **Trends:** Time series, NEW CONSTRUCTION by income level

✅ **Checkpoint:** Dashboard 5 complete

---

## ✅ PHASE 4: TESTING & REFINEMENT (2-3 hours)

### Performance Testing

Run these tests on each dashboard:

1. **Load Time Test:**
   - Clear browser cache
   - Time how long each dashboard takes to load
   - Target: <10 seconds
   - If slow: Reduce date range, add filters

2. **Query Performance:**
   - Watch bottom-right corner for query indicators
   - Target: <5 seconds per visualization
   - If slow: Use custom queries with optimizations

3. **Filter Test:**
   - Test date range picker
   - Test ZIP multi-select
   - Verify cross-filtering works
   - Check for errors

4. **Data Validation:**
   - Spot-check totals against BigQuery
   - Verify forecast dates are future, not past
   - Check for null values

**Fix any P0 (critical) issues before proceeding**

---

### UX Refinement

**Consistency Check:**
1. All dashboards use same color palette
2. All charts have clear titles
3. All axes are labeled
4. Tooltips are informative
5. Fonts are consistent

**Layout Optimization:**
1. Most important viz in top-left
2. Filters at top of page
3. White space between charts
4. Logical flow (overview → details)

**Add Context:**
1. Text boxes with key insights
2. Reference lines (e.g., $30K threshold)
3. Annotations (e.g., pandemic waves)
4. "Last Updated" timestamp (auto-updates)

---

## 📄 PHASE 5: DOCUMENTATION & DEPLOYMENT (2-3 hours)

### Create User Guide

Create file: `/dashboards/documentation/user_guide.md`

**Contents (10-15 pages):**
1. How to access dashboards
2. How to use filters
3. How to interpret each visualization
4. FAQs
5. Troubleshooting
6. Contact info

---

### Deploy & Share

**Share Settings:**
1. Click **"Share"** (top-right)
2. Choose sharing option:
   - **Specific people:** Enter email addresses
   - **Anyone with link:** Generate shareable link
   - **Public:** Make public (not recommended for internal data)
3. Set permissions: **Viewer** (not Editor)

**Embed in Website (Optional):**
1. Click **"File"** → **"Embed report"**
2. Copy iframe code
3. Paste into your website

---

### Set Up Scheduled Email Delivery (Optional)

1. Click **"File"** → **"Schedule email delivery"**
2. Set frequency: Daily, Weekly, or Monthly
3. Add recipients
4. Choose format: PDF or Link

---

## 🎉 COMPLETION CHECKLIST

**After 1-2 days, you should have:**

✅ **5 Dashboards:**
- [ ] Dashboard 1: COVID-19 Alerts & Safety (6 viz)
- [ ] Dashboard 2: Airport Traffic (5 viz)
- [ ] Dashboard 3: Vulnerable Communities (5 viz)
- [ ] Dashboard 4: Traffic Forecasting (7 viz)
- [ ] Dashboard 5: Economic Development (6 viz)

✅ **10 Data Sources:** All connected to BigQuery

✅ **29 Total Visualizations:** All rendering correctly

✅ **Filters & Interactivity:** Working across all dashboards

✅ **Documentation:** User guide created

✅ **Deployed:** Shared with stakeholders

✅ **Performance:** <10 sec load time, <5 sec queries

---

## 🆘 TROUBLESHOOTING

**Problem: "Can't connect to BigQuery"**
- Solution: Check you're signed in with correct Google account
- Verify account has BigQuery Data Viewer role

**Problem: "Query timeout"**
- Solution: Add date range filter (last 90 days)
- Use Custom Query with optimizations
- Reduce number of ZIPs displayed

**Problem: "No data showing"**
- Solution: Check filters aren't too restrictive
- Verify field types (Date fields should be Date type)
- Check data source connection

**Problem: "Charts loading slowly"**
- Solution: Enable **"Data freshness"** caching
- Reduce date range
- Use pre-aggregated tables

---

## 📞 NEXT STEPS

**You're ready to start!**

**Immediate Action:**
1. Go to: https://lookerstudio.google.com/
2. Create your first data source (COVID Hotspots)
3. Build your first visualization
4. Follow this guide step-by-step

**Timeline:**
- **Hours 1-2:** Phase 1-2 (Setup + Data Sources)
- **Hours 3-6:** Phase 3A-B (MVP Dashboards 1 & 4)
- **Hours 7-12:** Phase 3C (Dashboards 2, 3, 5)
- **Hours 13-15:** Phase 4 (Testing & Refinement)
- **Hours 16-19:** Phase 5 (Documentation & Deployment)

**Good luck! Let me know when you're ready to start or if you hit any blockers.**

---

**End of Quick Start Guide**
