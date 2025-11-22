# Dashboard 4: Traffic Forecasting - Step-by-Step Build Instructions

**Date Created:** November 19, 2025
**For:** Looker Studio
**Data Source:** BigQuery - gold_traffic_forecasts_by_zip
**Total Visualizations:** 7

---

## SETUP: Add Title & Filters

### Dashboard Title
1. Click **Text** → Add text box at top
2. Text: "Dashboard 4: Traffic Forecasting & Construction Planning"
3. Font: 24pt, Bold
4. Position: (50, 20)

### Global Filters
1. **Date Range Filter**
   - Click **Add a control** → **Date range control**
   - Position: (50, 60)
   - Default: All time (Sept 2025 - Jan 2026)
   - Link to: forecast_date

2. **ZIP Code Filter**
   - Click **Add a control** → **Drop-down list**
   - Position: (400, 60)
   - Control field: zip_code
   - Metric: None
   - Allow multiple selections: Yes
   - Default: All ZIPs

---

## VISUALIZATION 1: Next 7 Days Traffic Forecast (Line Chart)

**Position:** Top-left (0, 100)
**Size:** 750 × 400

### Steps:
1. Click **Add a chart** → **Time series chart**
2. Drag to position (0, 100), resize to 750 × 400

### DATA Tab Configuration:

**Date Range Dimension:**
- `forecast_date`

**Dimension:**
- `forecast_date` (Date type)

**Metrics** (add all 4):
1. `yhat`
   - Rename: "Predicted Trips"
   - Aggregation: SUM
   - Type: Number
2. `yhat_lower`
   - Rename: "Lower Bound"
   - Aggregation: SUM
3. `yhat_upper`
   - Rename: "Upper Bound"
   - Aggregation: SUM
4. `trend`
   - Rename: "Trend Component"
   - Aggregation: SUM

**Default Date Range:**
- Custom: Current date to Current date + 7 days

**Sort:**
- `forecast_date` Ascending

**Optional Breakdown:**
- Add `zip_code` as breakdown dimension (shows multiple ZIPs)

### STYLE Tab:

**Chart Style:**
- Smoothing: None

**Line Settings:**
- Line 1 (Predicted Trips):
  - Color: #0051BA (Chicago Blue)
  - Width: 3px
  - Style: Solid
- Line 2 (Lower Bound):
  - Color: #6B7280 (Gray)
  - Width: 1px
  - Style: Dashed
- Line 3 (Upper Bound):
  - Color: #6B7280 (Gray)
  - Width: 1px
  - Style: Dashed
- Line 4 (Trend):
  - Color: #F59E0B (Orange)
  - Width: 2px
  - Style: Dotted

**Axis:**
- X-Axis Title: "Forecast Date"
- Y-Axis Title: "Predicted Taxi Trips"
- Y-Axis Format: Number, 0 decimals, comma separator

**Legend:**
- Position: Bottom
- Alignment: Center

**Chart Header:**
- Title: "Next 7 Days Traffic Forecast"
- Subtitle: "Predicted taxi trips with confidence intervals"

---

## VISUALIZATION 2: Weekly Traffic Trends (12 Weeks)

**Position:** Top-right (800, 100)
**Size:** 750 × 400

### Steps:
1. Click **Add a chart** → **Time series chart**
2. Position: (800, 100), Size: 750 × 400

### DATA Tab:

**Date Range Dimension:**
- `week_start` (calculated field)

**Dimension:**
- `week_start`

**Metrics:**
1. Create calculated field `weekly_predicted_trips`:
   - Formula: `SUM(yhat)`
   - Rename: "Weekly Trips"

**Breakdown Dimension (optional):**
- `zip_code` (limit to top 10 ZIPs by volume)

**Date Range:**
- Custom: Current date to Current date + 12 weeks

**Sort:**
- `week_start` Ascending

### STYLE Tab:

**Line Settings:**
- Multiple lines by ZIP (if breakdown used)
- Width: 2px
- Color: Auto (distinct colors per ZIP)

**Axis:**
- X-Axis Title: "Week Starting"
- X-Axis Format: MMM dd, yyyy
- Y-Axis Title: "Weekly Predicted Trips"

**Legend:**
- Position: Right
- Max items: 10

**Chart Header:**
- Title: "12-Week Traffic Trends by ZIP"
- Subtitle: "Medium-term planning and resource allocation"

---

## VISUALIZATION 3: Monthly Traffic Summary (Bar Chart)

**Position:** Middle-left (0, 520)
**Size:** 500 × 350

### Steps:
1. Click **Add a chart** → **Column chart**
2. Position: (0, 520), Size: 500 × 350

### DATA Tab:

**Dimension:**
- `forecast_month` (calculated field)

**Metrics:**
1. `monthly_predicted_trips`:
   - Formula: `SUM(yhat)`
   - Rename: "Monthly Trips"
2. `avg_daily_trips`:
   - Formula: `AVG(yhat)`
   - Rename: "Avg Daily Trips"

**Sort:**
- `forecast_month` Ascending

### STYLE Tab:

**Bar Settings:**
- Color: #0051BA (Chicago Blue)
- Bar style: Vertical bars
- Spacing: 10%

**Data Labels:**
- Show labels: Yes
- Position: Outside end
- Format: Number, 0 decimals

**Axis:**
- X-Axis Title: "Forecast Month"
- X-Axis Format: MMM yyyy
- Y-Axis Title: "Predicted Trips"

**Chart Header:**
- Title: "Monthly Traffic Forecast Summary"
- Subtitle: "Long-term strategic planning"

---

## VISUALIZATION 4: Top 10 High-Traffic ZIPs (Horizontal Bar)

**Position:** Middle-center (520, 520)
**Size:** 500 × 350

### Steps:
1. Click **Add a chart** → **Bar chart** (horizontal)
2. Position: (520, 520), Size: 500 × 350

### DATA Tab:

**Dimension:**
- `zip_code`

**Metrics:**
1. `total_predicted_trips_30d`:
   - Formula: `SUM(yhat)`
   - Rename: "30-Day Forecast"
2. `avg_daily_trips`:
   - Formula: `AVG(yhat)`
   - Rename: "Daily Average"

**Date Range Filter:**
- Custom: Current date to Current date + 30 days

**Sort:**
- By metric: `total_predicted_trips_30d` Descending
- **Row limit: 10** (Top 10 only)

### STYLE Tab:

**Bar Settings:**
- Color: Gradient (#10B981 to #0051BA)
- Orientation: Horizontal

**Data Labels:**
- Show labels: Yes
- Position: Inside end

**Axis:**
- X-Axis Title: "Predicted Trips (Next 30 Days)"
- Y-Axis Title: "ZIP Code"

**Chart Header:**
- Title: "Top 10 High-Traffic ZIP Codes"
- Subtitle: "Next 30 days - Hotspot identification"

---

## VISUALIZATION 5: Forecast Uncertainty Analysis (Scatter Plot)

**Position:** Middle-right (1040, 520)
**Size:** 500 × 350

### Steps:
1. Click **Add a chart** → **Scatter chart**
2. Position: (1040, 520), Size: 500 × 350

### DATA Tab:

**Dimension:**
- `zip_code`

**Metrics:**
1. `avg_prediction`:
   - Formula: `AVG(yhat)`
   - Rename: "Avg Prediction"
   - Use as: X-axis
2. `uncertainty_range`:
   - Formula: `AVG(yhat_upper - yhat_lower)`
   - Rename: "Uncertainty Range"
   - Use as: Y-axis
3. `uncertainty_pct` (calculated field):
   - Use as: Bubble size

**Date Range:**
- Custom: Current date to Current date + 30 days

**Sort:**
- By `uncertainty_pct` Descending
- Row limit: 20 (top 20 most uncertain)

### STYLE Tab:

**Bubble Settings:**
- Color: Red gradient (#F97316 to #EF4444)
- Size: Based on `uncertainty_pct`
- Min size: 5px
- Max size: 20px

**Axis:**
- X-Axis Title: "Average Predicted Trips"
- Y-Axis Title: "Uncertainty Range (trips)"

**Chart Header:**
- Title: "Forecast Uncertainty by ZIP Code"
- Subtitle: "Larger bubbles = higher forecast uncertainty"

---

## VISUALIZATION 6: Day-of-Week Pattern (Column Chart)

**Position:** Bottom-left (0, 910)
**Size:** 750 × 250

### Steps:
1. Click **Add a chart** → **Column chart**
2. Position: (0, 910), Size: 750 × 250

### DATA Tab:

**Dimension:**
- `day_name` (calculated field: FORMAT_DATE("%A", forecast_date))

**Metric:**
1. `avg_predicted_trips`:
   - Formula: `AVG(yhat)`
   - Rename: "Avg Daily Trips"

**Date Range:**
- Custom: Current date to Current date + 28 days (4 weeks)

**Sort:**
- Custom sort order: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday

### STYLE Tab:

**Bar Settings:**
- Color: #0051BA
- Width: Auto

**Data Labels:**
- Show labels: Yes
- Position: Outside end

**Axis:**
- X-Axis Title: "Day of Week"
- Y-Axis Title: "Average Predicted Trips"

**Chart Header:**
- Title: "Day-of-Week Traffic Pattern"
- Subtitle: "Next 4 weeks - Best days for roadwork"

**Annotations:**
- Add text annotation: "Lowest traffic days = best for construction"

---

## VISUALIZATION 7: Traffic Growth Rate (Month-over-Month)

**Position:** Bottom-right (800, 910)
**Size:** 750 × 250

### Steps:
1. Click **Add a chart** → **Time series chart**
2. Position: (800, 910), Size: 750 × 250

### DATA Tab:

**Dimension:**
- `forecast_month` (calculated field)

**Metrics:**
1. `monthly_trips`:
   - Formula: `SUM(yhat)`
   - Rename: "Monthly Trips"

**Breakdown Dimension (optional):**
- `zip_code` (limit to top 5 ZIPs)

**Sort:**
- `forecast_month` Ascending

### STYLE Tab:

**Line Settings:**
- Color: #10B981 (green for growth)
- Width: 2px
- Show trendline: Yes

**Axis:**
- X-Axis Title: "Forecast Month"
- X-Axis Format: MMM yyyy
- Y-Axis Title: "Predicted Monthly Trips"

**Chart Header:**
- Title: "Month-over-Month Traffic Growth Forecast"
- Subtitle: "Identify growing/declining areas"

---

## POST-BUILD CHECKLIST

After building all 7 visualizations:

- [ ] All charts positioned correctly
- [ ] Titles and subtitles added
- [ ] Axes labeled with proper units
- [ ] Legends positioned appropriately
- [ ] Colors consistent with Chicago theme
- [ ] Date range filters working
- [ ] ZIP code filter working (test with 1-3 ZIPs)
- [ ] Data refreshes correctly (refresh data source)
- [ ] Test on different date ranges
- [ ] Verify numbers match BigQuery (spot-check 2-3 ZIPs)
- [ ] Add dashboard description text box (purpose, data source, last updated)

---

## LAYOUT DIAGRAM

```
┌──────────────────────────────────────────────────────────┐
│  DASHBOARD 4: TRAFFIC FORECASTING & CONSTRUCTION         │
│  Filters: [Date Range] [ZIP Code]                       │
├───────────────────────────┬──────────────────────────────┤
│                           │                              │
│  VIZ 1: Next 7 Days       │  VIZ 2: 12-Week Trends      │
│  (Line Chart)             │  (Multi-line)               │
│  750 × 400                │  750 × 400                  │
│                           │                              │
├────────────┬──────────────┼──────────────────────────────┤
│ VIZ 3:     │ VIZ 4:       │ VIZ 5: Uncertainty          │
│ Monthly    │ Top 10 ZIPs  │ Analysis (Scatter)          │
│ Summary    │ (Horiz Bar)  │ 500 × 350                   │
│ 500 × 350  │ 500 × 350    │                             │
├────────────┴──────────────┴──────────────────────────────┤
│ VIZ 6: Day-of-Week Pattern (Column Chart)               │
│ 750 × 250                                                │
├────────────────────────────────────┬─────────────────────┤
│ VIZ 7: MoM Growth (Line Chart)    │                     │
│ 750 × 250                          │                     │
└────────────────────────────────────┴─────────────────────┘
```

**Total Canvas:** 1600 × 1200 px

---

## TROUBLESHOOTING

### Issue: "No data available"
- **Check:** Date range includes Sept 2025 - Jan 2026 (forecast period)
- **Fix:** Change date range to "All time" or custom range

### Issue: Too many ZIPs cluttering charts
- **Check:** Breakdown dimension not limited
- **Fix:** Add row limit (top 10) or use ZIP filter to select specific ZIPs

### Issue: Calculated fields not showing
- **Check:** Fields created in data source editor
- **Fix:** Go to Resource → Manage added data sources → Edit → Add calculated fields

### Issue: Numbers don't match BigQuery
- **Check:** Aggregation method (SUM vs AVG)
- **Fix:** Refresh data source: Resource → Manage data sources → Refresh fields

---

## DATA REFRESH SCHEDULE

- **Forecast data updates:** Weekly (Mondays)
- **Dashboard cache:** 4 hours
- **Manual refresh:** Resource → Manage data sources → Refresh

---

**Build Time Estimate:** 2-3 hours
**Complexity:** Medium (7 visualizations)
**Prerequisites:** BigQuery access, Looker Studio account
**Data Coverage:** 5,130 forecasts (57 ZIPs × 90 days)

**Created by:** Claude Code
**Version:** 1.0
**Last Updated:** November 19, 2025
