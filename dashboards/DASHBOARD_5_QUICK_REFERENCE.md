# Dashboard 5: Quick Reference Card

## Data Sources (5 total)

1. **v_economic_dashboard** → Viz 1, 3, 4
2. **v_permits_timeline** → Viz 2, 6
3. **v_permits_by_area** → Viz 4
4. **v_monthly_permit_summary** → Viz 6
5. **v_fee_analysis** → Viz 5

## 6 Visualizations at a Glance

| # | Name | Type | Position | Size | Key Metric |
|---|------|------|----------|------|------------|
| 1 | Investment Targets | Maps Heatmap | 0, 80 | 750×450 | investment_need_score |
| 2 | Permit Timeline | Line Chart | 800, 80 | 750×450 | COUNT(permits) by month |
| 3 | Loan Eligibility | Maps Filled | 0, 560 | 500×350 | priority_category (color) |
| 4 | Income vs Construction | Scatter | 520, 560 | 500×350 | income(X), permits(Y), pop(size) |
| 5 | Fee Distribution | Horizontal Bar | 1040, 560 | 500×350 | total_fees_collected (top 15) |
| 6 | Monthly Trends | Combo Chart | 0, 930 | 1550×250 | permits(bars), cumulative(line) |

## Key Data Points

- **58 ZIPs** with complete data
- **33 ZIPs** loan eligible (57%)
- **7,935 permits** (2020-2025)
- **$15.6B** total project value
- **$69M** total fees collected
- **112 permits/month** average

## Color Scheme

**Investment Need / Priority:**
- High: Red #EF4444 or #C8102E
- Medium: Yellow/Orange #F59E0B or #F97316
- Low: Yellow #F59E0B
- Not Eligible: Gray #D1D5DB

**Charts:**
- Primary: Blue #0051BA
- Secondary: Orange #F97316
- Positive: Green #10B981

## Map Settings (All Maps)

- Center: 41.8781, -87.6298
- Zoom: 10
- Map type: Roadmap
- Opacity: 70%

## Common Filters

- Date range: 2020-01-01 to 2025-11-04
- Priority category: High/Medium/Low/Not Eligible
- Minimum permits: >= 10 (for scatter plot)

## Quick Tips

1. **Viz 1 & 3** use same data source (v_economic_dashboard)
2. **Viz 4** needs bubble sizing by population
3. **Viz 5** limit to top 15 ZIPs (sort DESC)
4. **Viz 6** cumulative may need pre-calc if RUNNING_SUM doesn't work
5. All maps must be ZIP code → Postal Code type
6. Timeline charts need month_start as Date Range Dimension

## Priority ZIPs (High Need - Sample)

Top investment targets by eligibility_index:
- Check viz 1 & 3 for current rankings
- Red/dark areas = highest priority
- Bottom-left quadrant in scatter = best opportunities

## Build Order (Recommended)

1. ✅ Create report in Looker Studio
2. ✅ Add all 5 data sources
3. → Build Viz 1 (Investment Map) - 10 min
4. → Build Viz 2 (Timeline) - 10 min
5. → Build Viz 3 (Loan Map) - 10 min
6. → Build Viz 4 (Scatter) - 15 min (most complex)
7. → Build Viz 5 (Fee Bars) - 10 min
8. → Build Viz 6 (Trends) - 15 min
9. → Add filters & test - 10 min
10. → Final layout & polish - 10 min

**Total Estimated Time:** 90 minutes
