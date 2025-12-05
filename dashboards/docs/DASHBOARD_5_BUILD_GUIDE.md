# Dashboard 5: Economic Development & Investment - Build Guide

**Created:** November 21, 2025
**Purpose:** Identify investment targets, small business loan opportunities, and construction trends
**Data Sources:** Economic indicators, building permits, loan eligibility metrics
**Coverage:** 58 ZIP codes, 7,935 NEW CONSTRUCTION permits (2020-2025), $15.6B in construction value

---

## Dashboard Overview

**6 Visualizations:**
1. **Investment Targets Map** - Geographic view of high-need areas (Heatmap)
2. **Permit Activity Timeline** - Construction trends over time (Line Chart)
3. **Loan Eligibility Map** - ZIP codes qualifying for small business loans (Choropleth)
4. **Income vs Construction** - Scatter plot showing investment opportunities (Bubble Chart)
5. **Fee Analysis by ZIP** - Permit fee distribution (Column Chart)
6. **Monthly Construction Trends** - Seasonal patterns and growth (Combo Chart)

**Canvas Size:** 1600 × 1200 px

---

## Data Summary

**Economic Dashboard View:**
- 58 ZIPs with complete data
- 33 ZIPs eligible for small business loans
- 4 priority levels (High/Medium/Low/Not Eligible)
- Average per capita income: $33,310

**Permit Data:**
- 7,935 NEW CONSTRUCTION permits
- Date range: Jan 2020 - Nov 2025 (71 months)
- Total project value: $15.6 billion
- Total fees collected: $69 million
- Average: 112 permits per month
- Peak month: 205 permits

---

## Pre-Build Setup

### Step 1: Create New Looker Studio Report

1. Go to https://lookerstudio.google.com/
2. Click **Create** → **Report**
3. Name: "Dashboard 5 - Economic Development & Investment"

### Step 2: Add Data Sources

Add **5 data sources** from BigQuery:

1. **Economic Dashboard**
   - Table: `chicago-bi-app-msds-432-476520.gold_data.v_economic_dashboard`
   - Records: 58 ZIPs
   - Used for: Viz 1, 3, 4

2. **Permits Timeline**
   - Table: `chicago-bi-app-msds-432-476520.gold_data.v_permits_timeline`
   - Records: 7,935 permits
   - Used for: Viz 2, 6

3. **Permits by Area**
   - Table: `chicago-bi-app-msds-432-476520.gold_data.v_permits_by_area`
   - Records: 60 ZIPs
   - Used for: Viz 4

4. **Monthly Summary**
   - Table: `chicago-bi-app-msds-432-476520.gold_data.v_monthly_permit_summary`
   - Records: 71 months
   - Used for: Viz 6

5. **Fee Analysis**
   - Table: `chicago-bi-app-msds-432-476520.gold_data.v_fee_analysis`
   - Records: 59 ZIPs
   - Used for: Viz 5

### Step 3: Configure Page Settings

1. Click **File** → **Page settings**
2. Set:
   - Canvas size: 1600 × 1200 px
   - Theme: Chicago color scheme
   - Grid: 20px (optional)

---

## VISUALIZATION 1: Investment Targets Map

**Purpose:** Show geographic distribution of investment need
**Chart Type:** Google Maps (Heatmap)
**Data Source:** v_economic_dashboard
**Position:** X=0, Y=80
**Size:** 750 × 450

### DATA Tab

**Location:**
- Field: `zip_code`
- Type: Postal Code (auto-detected)

**Weight (Metric):**
- Field: `investment_need_score`
- Aggregation: AVG
- Rename: "Investment Need Score"

**Alternative weights to consider:**
- `eligibility_index` - Overall eligibility (0-1)
- `inverted_income_index` - Income-based need
- `total_permits_new_construction` - Construction activity (inverted colors)

**Optional Filter:**
- Add control: Dropdown for `priority_category`
- Default: Show all

### STYLE Tab

**Map Settings:**
- Map type: Roadmap
- Center: Chicago (41.8781, -87.6298)
- Zoom: 10
- Heatmap aggregation: Average
- Opacity: 70%

**Color Scale:**
- Min color: Green (#10B981) - Low need
- Mid color: Yellow (#F59E0B) - Medium need
- Max color: Red (#EF4444) - High need
- Domain min: 0
- Domain max: 1.0

**Chart Title:**
- Text: "Investment Target Areas - ZIP Code Need Score"
- Font: 18pt, Bold
- Subtitle: "Higher scores indicate greater investment need"

**Business Insight:**
- Red/yellow areas = High priority for economic development programs
- Green areas = Lower priority, better economic indicators

---

## VISUALIZATION 2: Permit Activity Timeline

**Purpose:** Show construction trends over time
**Chart Type:** Time Series (Smoothed Line Chart)
**Data Source:** v_permits_timeline
**Position:** X=800, Y=80
**Size:** 750 × 450

### DATA Tab

**Date Dimension:**
- Field: `month_start`
- Type: Date (YYYYMM)
- Date granularity: Month

**Metric:**
- Create calculated field `monthly_permits`:
  - Formula: `COUNT(permit_)`
  - Rename: "Permits Issued"

**Secondary Metric (optional):**
- Field: `SUM(reported_cost)`
- Rename: "Total Project Value"
- Use as secondary axis

**Date Range:**
- Default: All time (2020-2025)
- Add control: Date range picker

**Sort:**
- `month_start` Ascending

### STYLE Tab

**Line Settings:**
- Line color: Blue (#0051BA)
- Line width: 3px
- Smoothing: Medium
- Show data points: Yes

**X-Axis:**
- Title: "Month"
- Format: MMM yyyy

**Y-Axis:**
- Title: "NEW CONSTRUCTION Permits"
- Format: Number, 0 decimals

**Trend Line:**
- Show trend: Yes (optional)
- Type: Linear

**Annotations (optional):**
- Add annotation: "COVID Impact" at March 2020
- Add annotation: "Recovery Peak" at highest month

**Chart Title:**
- Text: "NEW CONSTRUCTION Permit Trends (2020-2025)"
- Font: 18pt, Bold

---

## VISUALIZATION 3: Loan Eligibility Map

**Purpose:** Show which ZIP codes qualify for small business loans
**Chart Type:** Google Maps (Filled Map with Categories)
**Data Source:** v_economic_dashboard
**Position:** X=0, Y=560
**Size:** 500 × 350

### DATA Tab

**Location:**
- Field: `zip_code`
- Type: Postal Code

**Color Dimension:**
- Field: `priority_category`
- Type: Text
- Values: "High Priority", "Medium Priority", "Low Priority", "Not Eligible"

**Optional Metric (Tooltip):**
- `eligibility_index`
- `per_capita_income`
- `total_permits_new_construction`

### STYLE Tab

**Map Settings:**
- Map type: Roadmap
- Center: Chicago (41.8781, -87.6298)
- Zoom: 10
- Border: None or light gray

**Color Scheme (by Category):**
- High Priority: Dark Red (#C8102E)
- Medium Priority: Orange (#F97316)
- Low Priority: Yellow (#F59E0B)
- Not Eligible: Light Gray (#D1D5DB)

**Legend:**
- Position: Bottom-right
- Show all categories

**Chart Title:**
- Text: "Small Business Loan Eligibility by ZIP"
- Font: 16pt, Bold
- Subtitle: "33 of 58 ZIPs eligible"

**Business Insight:**
- Red ZIPs = Highest priority for loan programs
- Gray ZIPs = Doesn't meet eligibility criteria

---

## VISUALIZATION 4: Income vs Construction Activity

**Purpose:** Identify investment opportunities (low income + low construction)
**Chart Type:** Scatter Plot (Bubble Chart)
**Data Source:** v_permits_by_area
**Position:** X=520, Y=560
**Size:** 500 × 350

### DATA Tab

**Dimension:**
- Field: `zip_code`
- Type: Text

**X-Axis Metric:**
- Field: `per_capita_income`
- Aggregation: AVG
- Rename: "Per Capita Income"

**Y-Axis Metric:**
- Field: `permit_count`
- Aggregation: SUM
- Rename: "Total Permits (2020-2025)"

**Bubble Size:**
- Field: `population`
- Aggregation: MAX
- Rename: "Population"

**Bubble Color (optional):**
- Field: `is_loan_eligible`
- Type: Boolean
- Color: TRUE = Green, FALSE = Gray

**Optional Filter:**
- `permit_count >= 10` (exclude very low activity ZIPs)

### STYLE Tab

**Bubble Settings:**
- Color scheme:
  - Eligible (TRUE): Green (#10B981)
  - Not Eligible (FALSE): Gray (#9CA3AF)
- Size range: Min 5px, Max 30px
- Opacity: 70%

**X-Axis:**
- Title: "Per Capita Income ($)"
- Format: Currency, 0 decimals
- Scale: Linear

**Y-Axis:**
- Title: "NEW CONSTRUCTION Permits (2020-2025)"
- Format: Number, 0 decimals
- Scale: Linear

**Quadrant Lines (optional):**
- Add reference line: Vertical at median income
- Add reference line: Horizontal at median permits
- Purpose: Identify 4 quadrants:
  - **Bottom-left = HIGH PRIORITY** (low income + low construction)
  - Top-right = Low priority (high income + high construction)

**Data Labels:**
- Show ZIP code on hover (tooltip)
- Include all 4 metrics in tooltip

**Chart Title:**
- Text: "Investment Opportunity Analysis"
- Font: 16pt, Bold
- Subtitle: "Lower-left quadrant = highest need"

---

## VISUALIZATION 5: Fee Distribution by ZIP

**Purpose:** Analyze permit fee patterns across ZIPs
**Chart Type:** Horizontal Bar Chart
**Data Source:** v_fee_analysis
**Position:** X=1040, Y=560
**Size:** 500 × 350

### DATA Tab

**Dimension:**
- Field: `zip_code`
- Type: Text

**Metric 1:**
- Field: `total_fees_collected`
- Aggregation: SUM
- Rename: "Total Fees"

**Metric 2 (optional):**
- Field: `avg_fee`
- Aggregation: AVG
- Rename: "Avg Fee per Permit"

**Sort:**
- By: `total_fees_collected` Descending
- **Row Limit:** 15 (Top 15 ZIPs)

### STYLE Tab

**Bar Settings:**
- Orientation: Horizontal
- Color: Blue gradient
- Bar thickness: Auto

**X-Axis:**
- Title: "Total Fees Collected ($)"
- Format: Currency, 0 decimals, abbreviated (e.g., $1.2M)

**Y-Axis:**
- Title: "ZIP Code"
- Show all labels

**Data Labels:**
- Show values: Yes
- Position: Inside end
- Format: Currency abbreviated

**Chart Title:**
- Text: "Top 15 ZIPs by Permit Fees Collected"
- Font: 16pt, Bold
- Subtitle: "2020-2025 NEW CONSTRUCTION permits"

**Business Insight:**
- Shows revenue-generating areas
- Can correlate with construction activity

---

## VISUALIZATION 6: Monthly Construction Trends

**Purpose:** Show seasonal patterns and growth trends
**Chart Type:** Combo Chart (Bars + Line)
**Data Source:** v_monthly_permit_summary
**Position:** X=0, Y=930
**Size:** 1550 × 250

### DATA Tab

**Date Dimension:**
- Field: `month_start`
- Type: Date
- Granularity: Month

**Metric 1 (Bars):**
- Field: `permit_count`
- Aggregation: SUM
- Rename: "Monthly Permits"
- Chart type: Column

**Metric 2 (Line):**
- Create calculated field `cumulative_permits`:
  - Formula: `RUNNING_SUM(permit_count)`
  - Rename: "Cumulative Permits"
  - Chart type: Line

**Alternative Metric 2:**
- Field: `total_reported_cost`
- Aggregation: SUM
- Rename: "Total Project Value"
- Chart type: Line (secondary axis)

**Date Range:**
- Default: All time
- Add control: Date range picker

**Sort:**
- `month_start` Ascending

### STYLE Tab

**Bar Settings (Metric 1):**
- Color: Blue (#0051BA)
- Width: Auto
- Spacing: 5%

**Line Settings (Metric 2):**
- Color: Orange (#F97316)
- Width: 2px
- Style: Solid
- Show data points: No (too many)

**X-Axis:**
- Title: "Month"
- Format: MMM yyyy
- Show every Nth label: 3 (every 3 months)

**Left Y-Axis (Bars):**
- Title: "Monthly Permits"
- Format: Number, 0 decimals

**Right Y-Axis (Line):**
- Title: "Cumulative Total"
- Format: Number, 0 decimals, abbreviated

**Legend:**
- Position: Top-right
- Show both series

**Annotations (optional):**
- COVID lockdown: March 2020
- Recovery start: June 2020
- Peak activity: Identify highest month

**Chart Title:**
- Text: "Construction Activity Trends - Monthly & Cumulative"
- Font: 16pt, Bold

**Business Insight:**
- Identify seasonal patterns (construction season = spring/summer)
- Track recovery from COVID-19
- Forecast future activity based on trends

---

## Dashboard Layout Summary

```
┌─────────────────────────────────────────────────────────┐
│  DASHBOARD 5: ECONOMIC DEVELOPMENT & INVESTMENT         │
├──────────────────────────────┬──────────────────────────┤
│  Viz 1: Investment Targets   │  Viz 2: Permit Activity  │
│  Map (Heatmap)               │  Timeline (Line Chart)   │
│  750 × 450                   │  750 × 450               │
├────────────┬─────────────────┼──────────────────────────┤
│ Viz 3:     │ Viz 4: Income   │ Viz 5: Fee Distribution  │
│ Loan Elig. │ vs Construction │ (Horizontal Bar)         │
│ Map        │ (Scatter)       │ 500 × 350                │
│ 500 × 350  │ 500 × 350       │                          │
├────────────┴─────────────────┴──────────────────────────┤
│ Viz 6: Monthly Construction Trends                      │
│ (Combo Chart: Bars + Cumulative Line)                   │
│ 1550 × 250                                              │
└─────────────────────────────────────────────────────────┘
```

**Total Canvas:** 1600 × 1200 px

---

## Post-Build Checklist

- [ ] All 6 visualizations created and positioned correctly
- [ ] All 5 data sources connected
- [ ] Map visualizations centered on Chicago (zoom 10)
- [ ] Color scales consistent (Green/Yellow/Red for need/priority)
- [ ] Chart titles clear and descriptive
- [ ] Axes labeled with units ($, counts, etc.)
- [ ] Legends positioned appropriately
- [ ] Tooltips show relevant details
- [ ] Filter controls added (date range, priority category)
- [ ] Test with different date ranges
- [ ] Verify calculations (especially income vs permits)
- [ ] Check data freshness (should include 2025 data)

---

## Key Insights to Highlight

### Investment Targeting (Viz 1 & 4)
- **Bottom-left quadrant** in scatter plot = high priority
- Low income + low construction = greatest investment need
- 33 of 58 ZIPs qualify for small business loans

### Construction Trends (Viz 2 & 6)
- **COVID Impact:** Sharp drop in March-May 2020
- **Recovery:** Gradual increase starting June 2020
- **Seasonal Pattern:** Higher activity in spring/summer months
- **2020-2025 Total:** 7,935 permits, $15.6B in project value

### Fee Analysis (Viz 5)
- Total fees collected: $69 million
- Average fee: $8,456 per permit
- Fee rate: 0.84% of reported project cost
- Top ZIP codes by fees correlate with high construction activity

### Loan Eligibility (Viz 3)
- 33 ZIPs eligible (57% of total)
- Eligibility based on:
  - Low per capita income
  - Low construction activity
  - Low permit values
- Composite eligibility index (0-1 scale)

---

## Data Quality Notes

### Coverage
- **ZIPs:** 58 with complete socioeconomic data
- **Permits:** 7,935 NEW CONSTRUCTION (excludes renovations, repairs)
- **Date Range:** Jan 2020 - Nov 2025 (71 months)
- **Geographic:** Chicago city limits

### Data Freshness
- Permit data: Updated through Nov 4, 2025
- Socioeconomic data: Based on census estimates
- Loan eligibility: Calculated Nov 12, 2025

### Known Limitations
- "Unknown" ZIP excluded (0 records)
- Some ZIPs may have low permit counts (< 10)
- Income data may be 1-2 years behind current
- Fee breakdown (paid/unpaid/waived) not available in current dataset

---

## Filter Suggestions

### Global Filters (Apply to All Visualizations)
1. **Date Range Picker**
   - Control type: Date range
   - Field: `month_start` or `issue_date`
   - Default: All time
   - Purpose: Focus on specific time period

2. **Priority Category Dropdown** (for maps)
   - Control type: Dropdown
   - Field: `priority_category`
   - Options: All, High Priority, Medium Priority, Low Priority
   - Default: All

### Chart-Specific Filters

**Viz 2 & 6 (Timeline):**
- Add year selector (2020, 2021, 2022, 2023, 2024, 2025)
- Add quarter selector for granular analysis

**Viz 4 (Scatter):**
- Filter: `permit_count >= 10` (exclude very low activity)
- Filter: `population > 5000` (exclude very small ZIPs)

**Viz 5 (Fee Analysis):**
- Row limit: 15 (already set)
- Could add: `permit_count >= 50` (only ZIPs with substantial activity)

---

## Troubleshooting

### Issue: Maps not showing data
- **Check:** ZIP code field set to "Postal Code" type
- **Check:** Map centered on Chicago (41.8781, -87.6298)
- **Check:** Data source connected correctly
- **Fix:** Refresh data source fields

### Issue: Scatter plot bubbles too small/large
- **Check:** Population values are numeric (not text)
- **Adjust:** Bubble size range (min 5px, max 30px)
- **Alternative:** Use fixed bubble size, color by eligibility

### Issue: Timeline showing unexpected spikes/drops
- **Check:** Date range filter not excluding data
- **Check:** Aggregation method (COUNT not SUM)
- **Verify:** Data in BigQuery matches visualization

### Issue: Cumulative line not working (Viz 6)
- **Looker Studio Limitation:** RUNNING_SUM may not be available
- **Alternative 1:** Pre-calculate cumulative in BigQuery view
- **Alternative 2:** Use total project value as secondary metric instead
- **Workaround:** Show monthly + 12-month moving average

---

## Enhancement Ideas (Future)

### Additional Visualizations
1. **Community Area View:** Aggregate by community area (not just ZIP)
2. **Project Size Distribution:** Pie chart of Large/Medium/Small/Minimal
3. **Processing Time Analysis:** Average days by ZIP or year
4. **Work Type Breakdown:** Bar chart of work types within NEW CONSTRUCTION

### Advanced Analytics
1. **Predictive Forecast:** Use historical trends to predict next 12 months
2. **Correlation Analysis:** Income vs fees, population vs permits
3. **Efficiency Metrics:** Permits per capita, fees as % of property value
4. **Comparative Analysis:** Year-over-year growth rates by ZIP

### Interactivity Enhancements
1. **Click-through:** Click ZIP on map → filter all other charts
2. **Drill-down:** Click month on timeline → see individual permits
3. **Conditional Formatting:** Highlight ZIPs above/below thresholds
4. **Dynamic Text:** Show selected ZIP's metrics in scorecard

---

## Business Use Cases

### Economic Development Department
- **Identify target areas** for investment programs (Viz 1, 4)
- **Track program impact** by monitoring permit growth in priority ZIPs
- **Allocate resources** based on need scores

### Small Business Loan Program
- **Determine eligibility** using Viz 3 (loan eligibility map)
- **Prioritize applications** from high-priority ZIPs
- **Report outcomes** using construction activity metrics

### City Planning
- **Forecast revenue** from permit fees (Viz 5)
- **Identify construction seasons** for resource planning (Viz 6)
- **Monitor trends** to adjust policies and fees

### Community Engagement
- **Show residents** where investments are going
- **Report impact** of economic development initiatives
- **Transparency** in loan program criteria and outcomes

---

**Created by:** Claude Code
**Version:** 1.0
**Last Updated:** November 21, 2025
**Related Files:**
- `dashboards/queries/create_dashboard_5_views.sql`
- `dashboards/docs/DASHBOARD_IMPLEMENTATION_PLAN.md`
