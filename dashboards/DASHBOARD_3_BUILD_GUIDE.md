# Dashboard 3: Vulnerable Communities (CCVI) - Build Guide

**Created:** November 22, 2025
**Purpose:** Track taxi trips from/to neighborhoods with high COVID-19 Community Vulnerability Index (CCVI)
**Visualizations:** 6 total
**Data Sources:** 6 BigQuery views

---

## Data Sources

| View Name | Row Count | Purpose |
|-----------|-----------|---------|
| `v_ccvi_map` | 39 | CCVI vulnerability map (26 CAs + 13 ZIPs) |
| `v_ccvi_trip_activity` | 26 | Trip volumes from/to high-risk CAs |
| `v_ccvi_double_burden` | 13 | Areas with High CCVI + High COVID |
| `v_ccvi_trip_trends` | 365 | Weekly trip trends over time |
| `v_ccvi_pooled_rides` | 26 | Pooled ride analysis by area |
| `v_ccvi_dashboard_summary` | 1 | KPI summary metrics |

**BigQuery Project:** `chicago-bi-app-msds-432-476520`
**Dataset:** `gold_data`

---

## Visualization Specifications

### Viz 1: CCVI Vulnerability Map (Bubble/Geo Map)

**Purpose:** Show high-vulnerability areas on map with CCVI scores

**Data Source:** `v_ccvi_map`

**Configuration:**
| Setting | Value |
|---------|-------|
| Chart Type | Google Maps (Bubble) |
| Location | latitude, longitude |
| Size | ccvi_score |
| Color | vulnerability_score (1-4 gradient) |
| Tooltip | area_name, ccvi_score, vulnerability_level |

**Color Scale:**
- 4 (Very High): Red #DC2626
- 3 (High): Orange #F97316
- 2 (Moderate-High): Yellow #FBBF24
- 1 (Threshold): Gray #9CA3AF

**Map Center:** 41.8781, -87.6298 (Chicago)
**Zoom:** 10

---

### Viz 2: Trip Activity by Area (Horizontal Bar Chart)

**Purpose:** Show taxi trip volumes from/to CCVI high-risk areas

**Data Source:** `v_ccvi_trip_activity`

**Configuration:**
| Setting | Value |
|---------|-------|
| Chart Type | Bar Chart (Horizontal) |
| Dimension | area_name |
| Metric 1 | trips_from_area |
| Metric 2 | trips_to_area |
| Sort | ccvi_score DESC |

**Style:**
- Bars stacked: No (grouped)
- Color 1 (From): Blue #3B82F6
- Color 2 (To): Teal #14B8A6
- Show legend: Yes

---

### Viz 3: Double Burden Analysis (Scatter Plot)

**Purpose:** Identify areas with BOTH high CCVI AND high COVID risk

**Data Source:** `v_ccvi_double_burden`

**Configuration:**
| Setting | Value |
|---------|-------|
| Chart Type | Scatter Plot |
| X-Axis | ccvi_score |
| Y-Axis | avg_risk_score |
| Bubble Size | population |
| Bubble Color | burden_category |
| Tooltip | zip_code, total_cases, total_deaths |

**Color by Category:**
- Critical: Red #DC2626
- Severe: Orange #F97316
- High: Yellow #FBBF24
- Elevated: Gray #9CA3AF

---

### Viz 4: Trip Trends Over Time (Time Series)

**Purpose:** Show weekly trips to/from vulnerable areas over time

**Data Source:** `v_ccvi_trip_trends`

**Configuration:**
| Setting | Value |
|---------|-------|
| Chart Type | Time Series |
| Date Dimension | week_start |
| Metric 1 | trips_from_high_ccvi |
| Metric 2 | trips_to_high_ccvi |
| Metric 3 | total_trips (secondary axis) |

**Style:**
- Line style: Smooth
- Show data points: No
- Color 1: Blue #3B82F6
- Color 2: Teal #14B8A6
- Color 3 (Total): Gray #6B7280

---

### Viz 5: Pooled Rides Analysis (Bar Chart)

**Purpose:** Compare pooled vs solo rides in high-CCVI neighborhoods

**Data Source:** `v_ccvi_pooled_rides`

**Configuration:**
| Setting | Value |
|---------|-------|
| Chart Type | Bar Chart |
| Dimension | area_name |
| Metric 1 | pooled_trips |
| Metric 2 | solo_trips |
| Sort | ccvi_score DESC |

**Style:**
- Stacked: Yes (100% stacked optional)
- Color (Pooled): Green #22C55E
- Color (Solo): Orange #F97316

---

### Viz 6: KPI Scorecards

**Purpose:** Executive summary metrics

**Data Source:** `v_ccvi_dashboard_summary`

**Scorecards to Create:**

| Metric | Field | Format |
|--------|-------|--------|
| High-Risk Areas | total_high_risk_areas | Number |
| High-Risk CAs | high_risk_cas | Number |
| High-Risk ZIPs | high_risk_zips | Number |
| Avg CCVI Score | avg_ccvi_score | Number (1 decimal) |
| Total Trips (High CCVI) | total_trips_high_ccvi_areas | Compact Number |
| COVID Cases | total_covid_cases | Compact Number |
| COVID Deaths | total_covid_deaths | Compact Number |

---

## Step-by-Step Build Instructions

### Step 1: Add Data Sources

1. Open Looker Studio
2. Click **Resource** > **Manage added data sources**
3. Click **Add a data source**
4. Select **BigQuery**
5. Navigate to: `chicago-bi-app-msds-432-476520` > `gold_data`
6. Add each view:
   - v_ccvi_map
   - v_ccvi_trip_activity
   - v_ccvi_double_burden
   - v_ccvi_trip_trends
   - v_ccvi_pooled_rides
   - v_ccvi_dashboard_summary

### Step 2: Create Dashboard Page

1. Create new page or use existing Dashboard 3 page
2. Set page title: "Vulnerable Communities (CCVI)"
3. Add header with title

### Step 3: Build Visualizations

Follow the specifications above for each visualization.

**Recommended Layout:**
```
+------------------------------------------+
|  [Header: Vulnerable Communities CCVI]   |
+------------------------------------------+
|  [KPI Scorecards - 4 across top]         |
+------------------------------------------+
| [Viz 1: Map]          | [Viz 2: Bar]     |
|                       |                   |
+------------------------------------------+
| [Viz 3: Scatter]      | [Viz 5: Pooled]  |
|                       |                   |
+------------------------------------------+
|         [Viz 4: Time Series - Full Width]|
+------------------------------------------+
```

### Step 4: Configure Data Freshness

1. **Resource** > **Manage added data sources**
2. Edit each data source
3. Set **Data freshness** to **12 hours**

---

## Sample Data Preview

### v_ccvi_map (sample)
| geography_type | geography_id | area_name | ccvi_score | vulnerability_level |
|---------------|--------------|-----------|------------|---------------------|
| CA | 67 | West Englewood | 63.7 | Very High |
| CA | 30 | South Lawndale | 58.2 | High |
| CA | 19 | Belmont Cragin | 52.4 | Moderate-High |

### v_ccvi_double_burden (sample)
| zip_code | ccvi_score | avg_case_rate | total_cases | burden_category |
|----------|------------|---------------|-------------|-----------------|
| 60620 | 62.5 | 145.3 | 28,500 | Critical |
| 60636 | 58.1 | 132.7 | 24,100 | Severe |

---

## Troubleshooting

### Map not showing locations
- Ensure latitude/longitude fields are recognized as Geo type
- Check that coordinates are within Chicago bounds

### No data in views
- Refresh data source: **Resource** > **Manage added data sources** > **Edit** > **Refresh Fields**
- Check BigQuery permissions

### Colors not matching specification
- For categorical dimensions, use numeric score field (vulnerability_score) with gradient
- Looker Studio doesn't support custom colors for categorical filled maps

---

## Key Metrics Explained

| Metric | Description |
|--------|-------------|
| **CCVI Score** | COVID-19 Community Vulnerability Index (0-100, higher = more vulnerable) |
| **High-Risk** | CCVI score >= 47.9 (HIGH category) |
| **Double Burden** | Areas with both high CCVI AND high COVID case rates |
| **Pooled Trips** | Shared rides with multiple passengers |

---

## Related Files

- SQL Views: `/dashboards/queries/create_dashboard_3_views.sql`
- Source Data: `silver_data.silver_ccvi_high_risk`
- COVID Data: `gold_data.gold_covid_hotspots`
- Trip Data: `silver_data.silver_trips_enriched`

---

**End of Build Guide**
