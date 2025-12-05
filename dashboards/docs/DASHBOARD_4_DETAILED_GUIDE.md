# Dashboard 4: Traffic Forecasting - Complete Build Guide
## Step-by-Step Instructions for All 7 Visualizations

**Created:** November 19, 2025
**Data Source:** `v_traffic_dashboard_full` (BigQuery View)
**Total Build Time:** 2-3 hours
**Difficulty:** Medium

---

## PREREQUISITES

### Before You Start:

1. **Open Looker Studio:** https://lookerstudio.google.com/
2. **Create New Report:**
   - Click **Create** → **Report**
   - Name: "Dashboard 4 - Traffic Forecasting & Construction Planning"
3. **Add Data Source:**
   - Click **Add data** → **BigQuery**
   - Project: `chicago-bi-app-msds-432-476520`
   - Dataset: `gold_data`
   - Table: **`v_traffic_dashboard_full`**
   - Click **Add** → **Add to report**

### Page Setup:

1. Click **File** → **Page settings**
2. Set canvas size: **1600 × 1200 px**
3. Background: White or light gray (#F9FAFB)
4. Grid: 20px (optional, helps alignment)

---

## DASHBOARD HEADER & FILTERS

### Add Dashboard Title (5 minutes)

1. Click **Insert** → **Text**
2. Position: X=50, Y=20
3. Size: Width=1500, Height=40
4. Text: **"Dashboard 4: Traffic Forecasting & Construction Planning"**
5. **STYLE Tab:**
   - Font: Arial or Roboto
   - Size: 24pt
   - Weight: Bold
   - Color: #0051BA (Chicago Blue)
   - Alignment: Left

### Add Subtitle (Optional)

1. Insert another text box below title
2. Position: X=50, Y=60
3. Text: "90-day traffic forecasts for construction planning | Data: Sept 2025 - Jan 2026"
4. Font: 14pt, Regular, Gray (#6B7280)

### Filter 1: Date Range Control

1. Click **Add a control** → **Date range control**
2. Position: X=50, Y=80
3. Size: Width=200, Height=40
4. **SETUP Tab:**
   - Control field: `forecast_date`
   - Default date range: **All time**
   - Auto period: Off
5. **STYLE Tab:**
   - Show label: Yes
   - Label: "Forecast Period"

### Filter 2: ZIP Code Multi-Select

1. Click **Add a control** → **Drop-down list**
2. Position: X=270, Y=80
3. Size: Width=200, Height=40
4. **SETUP Tab:**
   - Control field: `zip_code`
   - Metric: Record Count
   - Sort: zip_code Ascending
   - Allow multiple selections: **Yes** ✅
   - Include "All" option: **Yes** ✅
5. **STYLE Tab:**
   - Show label: Yes
   - Label: "Select ZIP Codes"
   - Border: On

---

## VISUALIZATION 1: Next 7 Days Traffic Forecast
### Time Series Chart with Confidence Bands

**Purpose:** Short-term operational planning (daily predictions)
**Position:** X=0, Y=140
**Size:** Width=750, Height=400
**Estimated Time:** 15 minutes

### Step-by-Step:

1. **Add Chart:**
   - Click **Add a chart** → **Time series chart**
   - Drag to position (0, 140)
   - Resize: Width=750, Height=400

2. **DATA Tab Configuration:**

   **Date Range Dimension:**
   - Click dropdown → Select `forecast_date`

   **Dimension:**
   - `forecast_date` (should auto-populate)

   **Breakdown Dimension (Optional):**
   - Add `zip_code` if you want to show multiple ZIPs
   - Limit to 5-10 ZIPs for readability

   **Metrics:** (Click **Add metric** for each)

   **Metric 1:**
   - Field: `predicted_trips`
   - Rename to: "Predicted Trips"
   - Aggregation: **SUM**
   - Type: Number

   **Metric 2:**
   - Field: `lower_bound`
   - Rename to: "Lower Bound (80% CI)"
   - Aggregation: **SUM**

   **Metric 3:**
   - Field: `upper_bound`
   - Rename to: "Upper Bound (80% CI)"
   - Aggregation: **SUM**

   **Metric 4:**
   - Field: `trend`
   - Rename to: "Trend Component"
   - Aggregation: **SUM**

   **Default Date Range:**
   - Click **Default date range** dropdown
   - Select **Custom**
   - Start: Current date (or select 2025-11-19)
   - End: 7 days from start (or 2025-11-26)

   **Sort:**
   - Sort by: `forecast_date`
   - Direction: **Ascending**

3. **STYLE Tab Configuration:**

   **Chart Style:**
   - Line chart style: Smooth or Sharp (your preference)
   - Show data points: No (cleaner look)

   **Series Colors:** (Click on each series to customize)

   **Series 1 (Predicted Trips):**
   - Color: **#0051BA** (Chicago Blue)
   - Line weight: **3px**
   - Line style: Solid

   **Series 2 (Lower Bound):**
   - Color: **#9CA3AF** (Gray)
   - Line weight: **1px**
   - Line style: Dashed

   **Series 3 (Upper Bound):**
   - Color: **#9CA3AF** (Gray)
   - Line weight: **1px**
   - Line style: Dashed

   **Series 4 (Trend):**
   - Color: **#F59E0B** (Orange)
   - Line weight: **2px**
   - Line style: Dotted

   **X-Axis:**
   - Show axis title: **Yes**
   - Title: "Forecast Date"
   - Show axis line: Yes
   - Show gridlines: Yes (light gray)

   **Y-Axis:**
   - Show axis title: **Yes**
   - Title: "Predicted Taxi Trips"
   - Min value: Auto (or 0)
   - Max value: Auto
   - Show axis line: Yes
   - Show gridlines: Yes
   - Number format: Number, 0 decimals, comma separator

   **Legend:**
   - Position: **Bottom**
   - Alignment: **Center**
   - Font size: 12pt

   **Chart Header:**
   - Title: "Next 7 Days Traffic Forecast"
   - Subtitle: "Predicted taxi trips with 80% confidence intervals"
   - Font: 16pt Bold

4. **Final Adjustments:**
   - Click **View** to preview
   - Adjust colors if needed
   - Test date filter interaction

---

## VISUALIZATION 2: 12-Week Traffic Trends
### Multi-Line Chart by ZIP Code

**Purpose:** Medium-term planning and resource allocation
**Position:** X=800, Y=140
**Size:** Width=750, Height=400
**Estimated Time:** 15 minutes

### Step-by-Step:

1. **Add Chart:**
   - Click **Add a chart** → **Time series chart**
   - Position: (800, 140)
   - Size: 750 × 400

2. **DATA Tab:**

   **Date Range Dimension:**
   - `week_start` ✅ (pre-calculated!)

   **Dimension:**
   - `week_start`

   **Breakdown Dimension:**
   - `zip_code`
   - **Important:** Add a filter to limit to top ZIPs (see below)

   **Metric:**
   - Field: `predicted_trips`
   - Rename: "Weekly Predicted Trips"
   - Aggregation: **SUM** (sums daily forecasts into weekly totals)

   **Filter (to limit ZIPs shown):**
   - Click **Add a filter** → **Create a filter**
   - Name: "Top 10 ZIPs by Volume"
   - Include: `zip_code` → Top 10 by `predicted_trips` (SUM)
   - Click **Save**

   **Default Date Range:**
   - Custom: Current date to +12 weeks
   - Or: All time (shows all 20 weeks available)

   **Sort:**
   - `week_start` Ascending

3. **STYLE Tab:**

   **Line Chart:**
   - Line weight: **2px**
   - Colors: Auto (Looker will assign distinct colors per ZIP)
   - Show data points: No

   **X-Axis:**
   - Title: "Week Starting"
   - Format: MMM dd, yyyy (e.g., "Nov 19, 2025")

   **Y-Axis:**
   - Title: "Weekly Predicted Trips"
   - Number format: Number, 0 decimals, comma

   **Legend:**
   - Position: **Right**
   - Alignment: Top
   - Max items: 10

   **Chart Header:**
   - Title: "12-Week Traffic Trends by ZIP Code"
   - Subtitle: "Medium-term planning • Top 10 high-traffic ZIPs"

4. **Pro Tips:**
   - If too many lines are cluttered, reduce to Top 5 ZIPs
   - Users can select specific ZIPs using the ZIP filter you created earlier

---

## VISUALIZATION 3: Monthly Traffic Summary
### Column Chart (Vertical Bars)

**Purpose:** Long-term strategic planning
**Position:** X=0, Y=560
**Size:** Width=500, Height=350
**Estimated Time:** 10 minutes

### Step-by-Step:

1. **Add Chart:**
   - Click **Add a chart** → **Column chart**
   - Position: (0, 560)
   - Size: 500 × 350

2. **DATA Tab:**

   **Dimension:**
   - `forecast_month` ✅ (pre-calculated!)

   **Metrics:**

   **Metric 1:**
   - Field: `predicted_trips`
   - Rename: "Monthly Trips"
   - Aggregation: **SUM**

   **Metric 2 (Optional - shows average):**
   - Field: `predicted_trips`
   - Rename: "Avg Daily Trips"
   - Aggregation: **AVERAGE**

   **Sort:**
   - `forecast_month` Ascending

   **Filter (optional):**
   - If user selected specific ZIPs, this will auto-filter
   - Otherwise shows all ZIPs combined

3. **STYLE Tab:**

   **Bar Style:**
   - Color: **#0051BA** (Chicago Blue)
   - Border: None
   - Bar spacing: 20%

   **Data Labels:**
   - Show labels: **Yes**
   - Position: **Outside end** (above bars)
   - Font: 12pt, Bold
   - Format: Number, 0 decimals

   **X-Axis:**
   - Title: "Forecast Month"
   - Label format: MMM yyyy (e.g., "Nov 2025")
   - Slant labels: 0° (horizontal)

   **Y-Axis:**
   - Title: "Predicted Trips"
   - Number format: Number, 0 decimals, comma

   **Chart Header:**
   - Title: "Monthly Traffic Forecast Summary"
   - Subtitle: "Long-term strategic planning"

4. **Testing:**
   - Should show 5 bars (Sept, Oct, Nov, Dec, Jan)
   - Verify numbers are in thousands (e.g., 15,000 - 50,000 range)

---

## VISUALIZATION 4: Top 10 High-Traffic ZIP Codes
### Horizontal Bar Chart

**Purpose:** Identify hotspots for targeted interventions
**Position:** X=520, Y=560
**Size:** Width=500, Height=350
**Estimated Time:** 10 minutes

### Step-by-Step:

1. **Add Chart:**
   - Click **Add a chart** → **Bar chart** (horizontal orientation)
   - Position: (520, 560)
   - Size: 500 × 350

2. **DATA Tab:**

   **Dimension:**
   - `zip_code`

   **Metrics:**

   **Metric 1:**
   - Field: `predicted_trips`
   - Rename: "30-Day Forecast"
   - Aggregation: **SUM**

   **Metric 2 (Optional):**
   - Field: `predicted_trips`
   - Rename: "Daily Average"
   - Aggregation: **AVERAGE**

   **Date Range Filter:**
   - Click **Date range** at top
   - Change to **Custom**
   - Start: Current date
   - End: Current date + 30 days
   - This limits to next 30 days only

   **Sort:**
   - Sort by: `30-Day Forecast` (Metric 1)
   - Direction: **Descending** (highest first)
   - **Row limit: 10** ⚠️ Important!

3. **STYLE Tab:**

   **Bar Style:**
   - Orientation: **Horizontal** (should be default)
   - Color gradient: Two-color gradient
     - Min color: **#10B981** (Green - low traffic)
     - Max color: **#0051BA** (Blue - high traffic)

   **Data Labels:**
   - Show labels: **Yes**
   - Position: **Inside end** (inside bar, right side)
   - Font: 12pt, White color
   - Format: Number, 0 decimals

   **X-Axis:**
   - Title: "Predicted Trips (Next 30 Days)"
   - Number format: Number, 0 decimals, comma

   **Y-Axis:**
   - Title: "ZIP Code"
   - Show axis title: Optional

   **Chart Header:**
   - Title: "Top 10 High-Traffic ZIP Codes"
   - Subtitle: "Next 30 days • Hotspot identification"

4. **Verify:**
   - Should show exactly 10 bars
   - Sorted highest to lowest
   - Numbers should be in 5,000 - 30,000 range (30 days of trips)

---

## VISUALIZATION 5: Forecast Uncertainty Analysis
### Scatter Plot (Bubble Chart)

**Purpose:** Assess forecast confidence and identify high-uncertainty areas
**Position:** X=1040, Y=560
**Size:** Width=500, Height=350
**Estimated Time:** 15 minutes

### Step-by-Step:

1. **Add Chart:**
   - Click **Add a chart** → **Scatter chart**
   - Position: (1040, 560)
   - Size: 500 × 350

2. **DATA Tab:**

   **Dimension:**
   - `zip_code`

   **Metrics:**

   **Metric 1 (X-Axis):**
   - Field: `predicted_trips`
   - Rename: "Avg Prediction"
   - Aggregation: **AVERAGE**

   **Metric 2 (Y-Axis):**
   - Field: `uncertainty_range` ✅ (pre-calculated!)
   - Rename: "Uncertainty Range"
   - Aggregation: **AVERAGE**

   **Metric 3 (Bubble Size) - Create calculated field:**
   - Click **Add metric** → **Create field**
   - Name: "Uncertainty Percent"
   - Formula: `AVG(uncertainty_range) / AVG(predicted_trips) * 100`
   - Click **Save**
   - This metric controls bubble size

   **Date Range:**
   - Custom: Next 30 days (for consistency with Viz 4)

   **Sort:**
   - Sort by: "Uncertainty Percent" (Metric 3)
   - Direction: **Descending**
   - Row limit: **20** (top 20 most uncertain ZIPs)

3. **STYLE Tab:**

   **Bubble Settings:**
   - Size: Based on "Uncertainty Percent"
   - Min size: **5px**
   - Max size: **25px**
   - Color: Single color gradient
     - Color: **#EF4444** (Red - indicates high uncertainty)
     - Or gradient: #F97316 (Orange) to #EF4444 (Red)

   **X-Axis:**
   - Title: "Average Predicted Trips"
   - Number format: Number, 0 decimals

   **Y-Axis:**
   - Title: "Uncertainty Range (trips)"
   - Number format: Number, 0 decimals

   **Data Labels:**
   - Show labels: **Yes** (shows ZIP code on each bubble)
   - Font: 10pt

   **Chart Header:**
   - Title: "Forecast Uncertainty by ZIP Code"
   - Subtitle: "Larger bubbles = higher uncertainty • Top 20 shown"

4. **Interpretation Guide (add as text box below chart):**
   - Top-right quadrant: High traffic + high uncertainty = Monitor closely
   - Bottom-right: High traffic + low uncertainty = Reliable forecasts
   - Top-left: Low traffic + high uncertainty = Less critical
   - Bottom-left: Low traffic + low uncertainty = Stable areas

---

## VISUALIZATION 6: Day-of-Week Traffic Pattern
### Column Chart (Grouped by Day)

**Purpose:** Identify weekly patterns for resource scheduling
**Position:** X=0, Y=930
**Size:** Width=750, Height=250
**Estimated Time:** 10 minutes

### Step-by-Step:

1. **Add Chart:**
   - Click **Add a chart** → **Column chart**
   - Position: (0, 930)
   - Size: 750 × 250

2. **DATA Tab:**

   **Dimension:**
   - `day_name` ✅ (pre-calculated!)

   **Metric:**
   - Field: `predicted_trips`
   - Rename: "Avg Daily Trips"
   - Aggregation: **AVERAGE**

   **Date Range:**
   - Custom: Next 28 days (4 weeks)
   - This averages 4 Mondays, 4 Tuesdays, etc.

   **Sort:**
   - **IMPORTANT:** Need custom sort order
   - Click **Sort** → **Manual sort**
   - Order: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday
   - (By default it may sort alphabetically)

   **Alternative Sort (if manual not available):**
   - Add `day_of_week_num` as a hidden dimension
   - Sort by `day_of_week_num` Ascending

3. **STYLE Tab:**

   **Bar Style:**
   - Color: **#0051BA** (Chicago Blue)
   - Gradient: Optional - use gradient from green (low) to blue (high)

   **Data Labels:**
   - Show labels: **Yes**
   - Position: **Outside end** (above bars)
   - Font: 12pt, Bold
   - Format: Number, 0 decimals

   **X-Axis:**
   - Title: "Day of Week"
   - Label rotation: 0° (horizontal)

   **Y-Axis:**
   - Title: "Average Predicted Trips"
   - Number format: Number, 0 decimals, comma

   **Chart Header:**
   - Title: "Day-of-Week Traffic Pattern"
   - Subtitle: "Next 4 weeks • Lowest days = Best for construction"

4. **Add Annotation (Text Box):**
   - Position below chart
   - Text: "📌 Tip: Schedule roadwork on lowest-traffic days (typically Sundays/Mondays)"
   - Font: 12pt, Italic, Gray

---

## VISUALIZATION 7: Month-over-Month Traffic Growth
### Time Series Line Chart

**Purpose:** Identify growing/declining areas for strategic planning
**Position:** X=800, Y=930
**Size:** Width=750, Height=250
**Estimated Time:** 10 minutes

### Step-by-Step:

1. **Add Chart:**
   - Click **Add a chart** → **Time series chart**
   - Position: (800, 930)
   - Size: 750 × 250

2. **DATA Tab:**

   **Date Range Dimension:**
   - `forecast_month`

   **Dimension:**
   - `forecast_month`

   **Breakdown Dimension (Optional):**
   - `zip_code` (to show multiple ZIPs)
   - Filter to top 5 ZIPs for clarity

   **Metric:**
   - Field: `predicted_trips`
   - Rename: "Monthly Trips"
   - Aggregation: **SUM**

   **Sort:**
   - `forecast_month` Ascending

3. **STYLE Tab:**

   **Line Chart:**
   - Line weight: **2px**
   - Colors: Auto (or set specific colors per ZIP)
   - **Show trendline: Yes** ⭐ (important feature!)

   **Trendline Settings:**
   - Type: Linear
   - Color: #6B7280 (Gray, dashed)
   - Show label: Yes

   **X-Axis:**
   - Title: "Forecast Month"
   - Format: MMM yyyy

   **Y-Axis:**
   - Title: "Predicted Monthly Trips"
   - Number format: Number, 0 decimals, comma

   **Legend:**
   - Position: **Right** (if showing multiple ZIPs)
   - Or **None** (if showing all ZIPs combined)

   **Chart Header:**
   - Title: "Month-over-Month Traffic Growth Forecast"
   - Subtitle: "Strategic planning • Trendline shows overall direction"

4. **Optional Enhancement:**
   - Add reference line at average value
   - Highlight months with >10% growth

---

## FINAL TOUCHES

### Add Dashboard Description (Top Right)

1. **Insert Text Box:**
   - Position: X=1200, Y=80
   - Size: Width=350, Height=80

2. **Text:**
   ```
   📊 Data Source: Prophet ML Forecasts (v1.1.0)
   📅 Coverage: 57 ZIP codes, 90-day forecasts
   🔄 Last Updated: Sept 2025
   ⚠️  Forecasts are probabilistic estimates
   ```

3. **Style:**
   - Font: 11pt, Gray
   - Background: Light blue (#EFF6FF)
   - Border: 1px solid #BFDBFE
   - Padding: 10px

### Add Interpretation Legend (Bottom)

1. **Text Box below all visualizations**
2. **Text:**
   ```
   📖 How to Read This Dashboard:
   • Confidence Bands (Viz 1, 2): 80% of actual values expected within shaded area
   • Uncertainty (Viz 5): Larger bubbles = less reliable forecasts
   • Construction Planning (Viz 3, 6): Schedule roadwork during low-traffic periods
   • Traffic Levels: <300/day = Low | 300-600 = Medium | >600 = High
   ```

---

## POST-BUILD CHECKLIST

After completing all 7 visualizations:

### Functionality Tests:
- [ ] **Date Range Filter:** Change dates, verify all charts update
- [ ] **ZIP Code Filter:** Select 1-3 ZIPs, verify charts filter correctly
- [ ] **Cross-Filtering:** Click a ZIP in one chart, other charts should highlight it
- [ ] **Hover Tooltips:** Hover over data points, verify tooltips show correct info

### Visual Consistency:
- [ ] All charts use Chicago color palette (#0051BA, #10B981, #F59E0B, #EF4444)
- [ ] Font sizes consistent (16pt titles, 12pt labels)
- [ ] All axes have clear titles and units
- [ ] Legends positioned appropriately (bottom/right)

### Data Validation:
- [ ] Spot-check 2-3 ZIPs against BigQuery (numbers should match)
- [ ] Verify date ranges cover Sept 2025 - Jan 2026
- [ ] Check that Top 10 charts show exactly 10 items
- [ ] Ensure no blank/null values displayed

### Performance:
- [ ] Dashboard loads in <10 seconds
- [ ] Filter changes apply in <3 seconds
- [ ] No query timeout errors

### Documentation:
- [ ] Add dashboard title and subtitle
- [ ] Include data source info and last updated date
- [ ] Add interpretation legend for users
- [ ] Create "About this Dashboard" text box

---

## TROUBLESHOOTING GUIDE

### Issue: "No data available"
**Cause:** Date range filter set to past dates
**Fix:** Change filter to Sept 2025 or later (forecast data is future dates)

### Issue: Too many lines cluttering charts
**Cause:** Showing all 57 ZIPs simultaneously
**Fix:** Add row limit (Top 10) or use ZIP filter to select specific ZIPs

### Issue: Weekly/Monthly aggregation shows wrong totals
**Cause:** Using AVERAGE instead of SUM
**Fix:** Change aggregation to SUM for `predicted_trips`

### Issue: Day-of-week chart in wrong order
**Cause:** Alphabetical sort (Friday, Monday, Saturday...)
**Fix:** Use `day_of_week_num` to sort, or create custom dimension order

### Issue: Scatter plot bubbles all same size
**Cause:** Bubble size metric not set
**Fix:** Add `uncertainty_range / predicted_trips * 100` as bubble size metric

### Issue: Colors not matching brand
**Cause:** Auto-assigned colors
**Fix:** Manually set colors in STYLE tab for each series

### Issue: Numbers too large (decimals showing)
**Cause:** Number format includes decimals
**Fix:** Change to "Number, 0 decimals" in STYLE → Number format

---

## KEYBOARD SHORTCUTS (Speed Up Building)

- **Ctrl+C / Cmd+C:** Copy chart
- **Ctrl+V / Cmd+V:** Paste chart (useful for similar visualizations)
- **Ctrl+Z / Cmd+Z:** Undo
- **Ctrl+S / Cmd+S:** Save (auto-save is on, but good habit)
- **Arrow Keys:** Move selected object 1px at a time
- **Shift+Arrow:** Move 10px at a time
- **Ctrl+D / Cmd+D:** Duplicate selected object

---

## NEXT STEPS AFTER COMPLETION

1. **Share Dashboard:**
   - Click **Share** button (top right)
   - Add viewer emails
   - Set permissions (View only / Can edit)

2. **Schedule Email Delivery:**
   - Click **⋮** menu → **Schedule email delivery**
   - Set frequency (Weekly recommended)
   - Add recipients

3. **Embed in Website (Optional):**
   - Click **File** → **Embed report**
   - Copy iframe code
   - Paste into website

4. **Create Dashboard URL:**
   - Click **Share** → **Get report link**
   - Share URL: https://lookerstudio.google.com/reporting/...

---

## SUPPORT & RESOURCES

- **Looker Studio Help:** https://support.google.com/looker-studio
- **BigQuery Console:** https://console.cloud.google.com/bigquery
- **Data Source:** `chicago-bi-app-msds-432-476520.gold_data.v_traffic_dashboard_full`
- **Build Time Estimate:** 2-3 hours total
- **Complexity:** Medium (some calculated metrics, multiple chart types)

---

**Dashboard Complete! 🎉**

You now have a fully functional traffic forecasting dashboard with:
- ✅ 7 interactive visualizations
- ✅ Date range and ZIP code filtering
- ✅ 90-day forecast coverage
- ✅ Construction planning insights
- ✅ Uncertainty analysis
- ✅ Model performance metrics

**Ready to build Dashboard 2 (Airport Traffic) next?**

---

**Created by:** Claude Code
**Version:** 1.0
**Last Updated:** November 19, 2025
