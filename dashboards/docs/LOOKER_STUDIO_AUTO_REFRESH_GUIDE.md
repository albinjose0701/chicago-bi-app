# Looker Studio Auto-Refresh Guide

**Question:** Will dashboards automatically update due to the data freshness option on Looker?

**Short Answer:** **YES** - Looker Studio dashboards will automatically show fresh data from BigQuery, but you need to configure the cache settings correctly.

---

## How Looker Studio Data Refresh Works

### Automatic Refresh (Default Behavior)

Looker Studio has **automatic caching** with configurable freshness:

```
User opens Dashboard
    ↓
Looker Studio checks cache age
    ↓
If cache < data freshness setting → Show cached data
If cache > data freshness setting → Query BigQuery for fresh data
    ↓
Display updated dashboard
```

**Key Points:**
- ✅ Looker Studio **automatically queries BigQuery** when cache expires
- ✅ No manual refresh needed if freshness settings are configured
- ✅ Users always see data as fresh as the cache setting allows
- ❌ Does NOT poll BigQuery continuously (only on dashboard view)

---

## Configuring Data Freshness

### Method 1: Data Source Level (Recommended)

This sets the default cache duration for ALL charts using this data source:

1. **Open your Looker Studio dashboard**
2. **Click Resource → Manage added data sources**
3. **Click the data source name** (e.g., "gold_permits_roi")
4. **Click the pencil icon** (Edit)
5. **In the top-right corner**, find **"Data freshness"** dropdown
6. **Select refresh interval:**
   - **Every 1 hour** (most aggressive)
   - **Every 4 hours** (balanced - RECOMMENDED for permits)
   - **Every 12 hours** (default)
   - **Every 24 hours** (least aggressive)

**Screenshot locations:**
```
[Data Source Settings]
┌────────────────────────────────────────┐
│ Data Source: gold_permits_roi          │
│                                        │
│ Connection: BigQuery                   │
│ Project: chicago-bi-app-msds-432-...  │
│                                        │
│ Data freshness: [Every 4 hours ▼]     │  ← Set this!
└────────────────────────────────────────┘
```

### Method 2: Chart Level (Override)

For specific charts that need different refresh rates:

1. **Select a chart** on your dashboard
2. **Click DATA tab** in the right panel
3. **Scroll down** to find **"Data freshness"**
4. **Select chart-specific refresh interval**

This **overrides** the data source default for this chart only.

### Method 3: Report Level (Global)

Set a report-wide cache policy:

1. **File → Report settings**
2. **Data sources section**
3. **Set default data freshness** for all sources

---

## Recommended Settings for Chicago BI Dashboards

### Dashboard 1: COVID-19 Alerts
- **Data freshness:** Every 12 hours
- **Reason:** COVID forecasts update weekly (Monday), daily refresh unnecessary
- **Sources:**
  - `gold_covid_hotspots` → 12 hours
  - `gold_covid_risk_forecasts` → 12 hours

### Dashboard 2: Airport Traffic
- **Data freshness:** Every 12 hours
- **Reason:** Historical analysis, no real-time needs
- **Sources:**
  - `v_airport_trips` → 12 hours
  - `v_airport_covid_overlay` → 12 hours
  - `v_airport_hourly_patterns` → 12 hours

### Dashboard 4: Traffic Forecasting
- **Data freshness:** Every 12 hours
- **Reason:** Forecasts update weekly, historical hourly data
- **Sources:**
  - `v_traffic_dashboard_full` → 12 hours
  - `v_rush_hour_by_zip` → 4 hours (if using recent data)

### Dashboard 5: Economic Development (Permits)
- **Data freshness:** Every 4 hours ← IMPORTANT!
- **Reason:** Permits pipeline runs weekly, but want fresh data on Monday mornings
- **Sources:**
  - `v_economic_dashboard` → 4 hours
  - `v_permits_timeline` → 4 hours
  - `v_permits_by_area` → 4 hours
  - `v_monthly_permit_summary` → 4 hours
  - `v_fee_analysis` → 4 hours

**Why 4 hours for permits?**
- Pipeline runs Monday 3 AM CT (9 AM UTC)
- 4-hour cache ensures users see fresh data by Monday afternoon
- Balance between freshness and query costs

---

## Data Update Timeline (Full Automation)

```
Monday 2:00 AM CT
    ↓
Permits Extractor runs (Cloud Run)
    ↓
New permits written to raw_data.raw_building_permits
    ↓
Monday 3:00 AM CT
    ↓
Permits Pipeline runs (Cloud Run)
    ↓
Data flows through:
  - bronze_data.bronze_building_permits (~3 min)
  - silver_data.silver_permits_enriched (~5 min)
  - gold_data.gold_permits_roi (~9 min)
  - gold_data.gold_loan_targets (~9 min)
    ↓
Monday 3:10 AM CT
    ↓
BigQuery tables updated with latest data
    ↓
[CACHE EXPIRES]
    ↓
Monday 7:10 AM CT (assuming 4-hour cache)
    ↓
First user opens Dashboard 5
    ↓
Looker Studio queries BigQuery (cache expired)
    ↓
Fresh data displayed! ✅
```

**Total latency:** ~4 hours after pipeline completes (due to cache)

**To see updates immediately after pipeline:**
- Manually refresh: Click **Refresh data** button (top-right)
- Or: Set data freshness to "Every 1 hour" (more expensive)

---

## Manual Refresh Options

### Option 1: Refresh Button (Individual Dashboard)

When viewing a dashboard:
1. Click **⟳ Refresh** button (top-right corner)
2. This forces immediate query to BigQuery
3. Ignores cache for this session only

**Use case:** After running pipeline manually, want to verify new data

### Option 2: Edit Mode Refresh (Development)

When editing a dashboard:
1. Enter **Edit mode** (click Edit button)
2. Select a chart
3. Click **Refresh data** in chart properties panel
4. This refreshes just that chart's data

**Use case:** Testing chart configurations with latest data

### Option 3: Data Source Refresh (All Dashboards)

Refresh cache for ALL dashboards using a data source:
1. **Resource → Manage added data sources**
2. **Click data source name**
3. **Click ⟳ Refresh fields** button

**WARNING:** This refreshes the schema (field names), not the data cache.
- Use this when you add new columns to BigQuery tables
- Does NOT force data refresh for dashboards

### Option 4: Clear Browser Cache (Nuclear Option)

If dashboards seem stale despite settings:
1. Open browser developer tools (F12)
2. Right-click refresh button → **Empty Cache and Hard Reload**
3. Or: Clear browser cache for datastudio.google.com

**Use case:** Debugging only, rarely needed

---

## Cache Behavior Details

### What Gets Cached?

- ✅ Query results (data rows)
- ✅ Aggregations (SUM, AVG, COUNT)
- ✅ Filter results
- ❌ Schema changes (fields, types)

### Cache Invalidation Triggers

Cache is automatically invalidated when:
1. **Time expires** (based on data freshness setting)
2. **User clicks manual refresh** (⟳ button)
3. **Filter values change** (applies new filter, re-queries)
4. **Date range changes** (applies new range, re-queries)
5. **Chart edited** (in edit mode, changes configuration)

### Cache Sharing

- Cache is **shared across users** viewing the same dashboard
- If User A opens dashboard → cache created
- If User B opens 5 minutes later → uses User A's cache
- Cache expires based on first query time

**Example:**
```
10:00 AM - User A opens Dashboard 5 → Cache created (expires 2:00 PM with 4-hour setting)
10:30 AM - User B opens Dashboard 5 → Uses cached data (no BigQuery query)
2:00 PM  - User C opens Dashboard 5 → Cache expired, new query, fresh cache created
```

---

## BigQuery Query Costs

### Cost Calculation

BigQuery charges **$6.25 per TB scanned** (on-demand pricing).

**Example for Dashboard 5:**

Assume each dashboard view queries:
- `v_economic_dashboard`: 58 rows × 20 columns × 100 bytes = 116 KB
- `v_permits_timeline`: 7,935 rows × 30 columns × 150 bytes = 35 MB
- `v_permits_by_area`: 60 rows × 25 columns × 100 bytes = 150 KB
- Others: ~50 MB total

**Total per dashboard view:** ~100 MB

**Cost per view:** 0.1 GB ÷ 1000 × $6.25 = **$0.000625** (negligible)

**Monthly cost with 4-hour cache:**
- Users: 10 active users
- Views/day: 10 users × 2 views = 20 views/day
- Cache hits: 75% (3 out of 4 views use cache)
- Actual queries: 20 × 0.25 = 5 queries/day
- Monthly queries: 5 × 30 = 150 queries
- **Monthly cost:** 150 × $0.000625 = **$0.09/month**

### Cost Optimization

**Best practices:**
1. ✅ Use **4-12 hour cache** for dashboards (balance freshness vs cost)
2. ✅ Create **pre-aggregated views** (like we did for Dashboard 5)
3. ✅ Use **LIMIT clauses** in views when appropriate
4. ✅ **Partition tables** by date (if tables grow large)
5. ❌ Avoid **1-hour cache** unless truly needed (6-12x more queries)

**Our current setup:**
- ✅ All views are pre-aggregated (gold layer)
- ✅ Views use filtered data (not full scans)
- ✅ Reasonable cache settings (4-12 hours)
- **Estimated monthly cost:** < $1.00

---

## Verification Checklist

### After Setting Up Automation

**Step 1: Set cache settings** (do this NOW)
```
□ Dashboard 1: Set all data sources to 12 hours
□ Dashboard 2: Set all data sources to 12 hours
□ Dashboard 4: Set all data sources to 12 hours
□ Dashboard 5: Set all data sources to 4 hours
```

**Step 2: Test manual pipeline execution**
```bash
# Run pipeline manually
gcloud run jobs execute permits-pipeline \
  --region=us-central1 \
  --project=chicago-bi-app-msds-432-476520 \
  --wait
```

**Step 3: Verify data updated in BigQuery**
```sql
-- Check newest permit date
SELECT MAX(issue_date) as newest_permit
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_permits_roi`;

-- Should show recent date (November 2025)
```

**Step 4: Force dashboard refresh**
```
□ Open Dashboard 5
□ Click ⟳ Refresh button (top-right)
□ Verify newest permit date appears in visualizations
□ Check "Last updated" timestamp (if added to dashboard)
```

**Step 5: Wait for cache expiration**
```
□ Note current time (e.g., 3:15 PM)
□ Close dashboard
□ Wait 4+ hours (cache expiration)
□ Re-open dashboard (e.g., 7:30 PM)
□ Verify data is still current (auto-refresh worked!)
```

### Monday Morning Test (After Automation)

**On first Monday after deployment:**

1. **Check extractor ran:**
   ```bash
   gcloud logging read "resource.type=cloud_run_job AND resource.labels.job_name=permits-extractor" \
     --limit=10 --project=chicago-bi-app-msds-432-476520
   ```

2. **Check pipeline ran:**
   ```bash
   gcloud logging read "resource.type=cloud_run_job AND resource.labels.job_name=permits-pipeline" \
     --limit=10 --project=chicago-bi-app-msds-432-476520
   ```

3. **Verify BigQuery updated:**
   ```sql
   SELECT
     'Bronze' as layer,
     MAX(issue_date) as newest_permit,
     MAX(last_updated) as last_update
   FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_building_permits`

   UNION ALL

   SELECT
     'Gold' as layer,
     MAX(newest_permit_date) as newest_permit,
     MAX(last_updated) as last_update
   FROM `chicago-bi-app-msds-432-476520.gold_data.gold_permits_roi`;
   ```

4. **Check Dashboard 5:**
   - Open dashboard
   - If cache not expired: Click manual refresh
   - Verify new permits appear in charts
   - Check monthly trends updated

---

## Advanced: Custom Refresh Logic

### Option A: Scheduled Query to Clear Cache

Create a BigQuery scheduled query that updates a metadata table:

```sql
-- Create metadata table (one-time)
CREATE TABLE `chicago-bi-app-msds-432-476520.gold_data.dashboard_refresh_trigger` (
  last_refresh TIMESTAMP,
  source_table STRING
);

-- Scheduled query (runs after pipeline, Monday 3:15 AM)
INSERT INTO `chicago-bi-app-msds-432-476520.gold_data.dashboard_refresh_trigger`
VALUES (CURRENT_TIMESTAMP(), 'permits_pipeline');
```

Then in Looker Studio:
- Add this table as a data source
- Include `last_refresh` field (hidden) in every chart
- Looker will re-query when this field changes

**Benefit:** Forces refresh immediately after pipeline without waiting for cache

### Option B: Embedding with URL Parameters

Force fresh data by appending `&refresh=true` to dashboard URL:

```
https://lookerstudio.google.com/reporting/your-dashboard-id/page/pageId?refresh=true
```

**Benefit:** Share links that always show latest data

### Option C: API-Based Refresh (Advanced)

Use Looker Studio API to programmatically trigger refresh:
- Requires OAuth setup
- Can trigger from Cloud Function after pipeline completes
- Most complex but most control

---

## Summary & Recommendations

### ✅ Best Practice Configuration

**For your Chicago BI App:**

1. **Set data freshness to 4 hours** for permits dashboards
2. **Set data freshness to 12 hours** for COVID/traffic/airport dashboards
3. **Run pipeline weekly** (Monday 3 AM CT)
4. **Users will see fresh data automatically** by Monday afternoon
5. **No manual intervention needed** ✅

### ✅ Expected User Experience

**Typical workflow:**
- Monday 3:10 AM: Pipeline completes, BigQuery updated
- Monday 7:15 AM: User opens Dashboard 5
  - Cache expired (4 hours passed)
  - Looker queries BigQuery automatically
  - Fresh data displayed
  - New cache created (expires 11:15 AM)
- Monday 10:00 AM: Another user opens Dashboard 5
  - Cache still valid
  - Cached data displayed (no BigQuery query)
  - Data still fresh (from 7:15 AM query)

### ✅ Cost Efficiency

**With these settings:**
- **BigQuery costs:** < $1/month
- **Looker Studio:** Free
- **Total dashboard refresh cost:** Effectively $0

### ✅ Troubleshooting

**If dashboards show stale data:**
1. Check data freshness setting (Resource → Manage data sources)
2. Manually refresh once (⟳ button)
3. Verify BigQuery tables updated (run SQL query)
4. Check pipeline logs for errors

---

## Action Items

**Complete these NOW:**

```
□ Open each Looker Studio dashboard
□ Set data freshness to recommended values
□ Test manual refresh button
□ Document refresh settings in dashboard description
□ Add "Last Updated" timestamp to dashboards (optional)
□ Test after next Monday's automated pipeline run
```

---

**Question Answered:**

> Will dashboards automatically update due to the data freshness option on Looker?

**YES!** ✅ Looker Studio dashboards will **automatically query BigQuery and display fresh data** when:
1. Data freshness cache expires (4-12 hours)
2. User opens the dashboard (triggers cache check)
3. No manual action needed from users

**Your pipeline runs weekly** → **Dashboards refresh automatically** → **Users always see current data** ✅

---

**Last Updated:** November 21, 2025
**Status:** Production Ready
**Cost:** < $1/month
**Manual Intervention Required:** None ✅
