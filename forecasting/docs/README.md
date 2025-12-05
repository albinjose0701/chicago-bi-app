# Prophet Forecasting Models for Chicago BI Platform

This module implements Prophet time series forecasting models to meet project requirements 1, 4, and 9.

## 🚀 Quick Start

**Current Status:** ✅ **BOTH MODELS PRODUCTION READY**

```bash
# Activate virtual environment
cd /Users/albin/Desktop/chicago-bi-app/forecasting
source venv/bin/activate

# Run Traffic Forecasting (57 ZIPs, 90-day horizon)
python traffic_volume_forecasting.py

# Run COVID Forecasting (56 ZIPs, 12-week horizon)
python covid_alert_forecasting_simple.py

# Results automatically written to BigQuery:
# - gold_data.gold_traffic_forecasts_by_zip (5,130 records)
# - gold_data.gold_covid_risk_forecasts (672 records)
# - gold_data.gold_forecast_model_metrics (114 models)
```

## 📊 Current Deployment

| Model | Status | Records | ZIPs | Version | Date Range |
|-------|--------|---------|------|---------|------------|
| **Traffic** | ✅ Production | 5,130 | 57 | v1.1.0 | Sep 2025 - Jan 2026 |
| **COVID** | ✅ Production | 672 | 56 | v1.1.0-simple | Dec 2023 - Mar 2024 |

**Dashboard Queries:** 22 ready-to-use SQL queries (see `FORECAST_QUERIES.sql` and `COVID_FORECAST_QUERIES.sql`)

## Overview

**Purpose:** Generate forecasts for:
1. **Traffic Volume** (Req 4 & 9): Daily/weekly/monthly taxi trip patterns by ZIP code for streetscaping planning
2. **COVID-19 Alerts** (Req 1): Weekly COVID risk levels considering mobility patterns to alert taxi drivers

## Requirements Addressed

### Requirement 1: COVID-19 Alert Forecasting
> The City of Chicago is interested to forecast COVID-19 alerts (Low, Medium, High) on daily/weekly basis to the residents of the different neighborhoods considering the counts of the taxi trips and COVID-19 positive test cases.

**Solution:** `covid_alert_forecasting_simple.py` ✅ **PRODUCTION**
- **Version:** v1.1.0-simple (simplified model, Option B)
- **Status:** Production-ready, 672 forecasts generated
- **Coverage:** 56 ZIP codes × 12 weeks
- Forecasts COVID-19 risk scores (0-100) using Prophet
- Basic Prophet model (no regressors for initial deployment)
- Generates alert levels: NONE, CAUTION, WARNING, CRITICAL
- Risk categories: Low (<20), Medium (20-50), High (>50)
- Outputs actionable alerts for taxi drivers to avoid becoming super spreaders
- **Note:** Original `covid_alert_forecasting.py` available for future enhancement with regressors

### Requirement 4 & 9: Traffic Volume Forecasting
> For streetscaping investment and planning, forecast daily, weekly, and monthly traffic patterns using taxi trips as a proxy for traffic volume in different zip codes.

**Solution:** `traffic_volume_forecasting.py`
- Forecasts daily taxi trip volumes for next 90 days
- Separate model for each ZIP code (57 ZIPs)
- Captures seasonality: yearly (construction season vs winter), weekly (weekday vs weekend)
- Provides confidence intervals (yhat_lower, yhat_upper)
- Enables construction planning: identify low-traffic periods for roadwork

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│               PROPHET FORECASTING PIPELINE              │
└─────────────────────────────────────────────────────────┘

Input Data (BigQuery Gold Layer):
  ├─ gold_taxi_daily_by_zip (2020-2025, 4M records)
  ├─ gold_covid_hotspots (2020-2024, 13K records)
  └─ Mobility + Epidemiological Data

         ⬇

Training & Forecasting:
  ├─ [1] Load historical data
  ├─ [2] Train Prophet models per ZIP code
  ├─ [3] Generate forecasts (30/90 days ahead)
  ├─ [4] Calculate performance metrics
  └─ [5] Apply business logic (alerts, risk categories)

         ⬇

Output Tables (BigQuery):
  ├─ gold_traffic_forecasts_by_zip (5,130+ records)
  ├─ gold_covid_risk_forecasts (720+ records)
  └─ gold_forecast_model_metrics (117+ records)
```

## Files

### Core Scripts

1. **`traffic_volume_forecasting.py`**
   - Train Prophet models for 57 ZIP codes
   - Generate 90-day traffic forecasts
   - Output: 5,130 forecast records (90 days × 57 ZIPs)
   - Runtime: ~8-10 minutes

2. **`covid_alert_forecasting.py`**
   - Train Prophet models with mobility regressors
   - Generate 12-week COVID risk forecasts
   - Output: 720 forecast records (12 weeks × 60 ZIPs)
   - Runtime: ~4-6 minutes

3. **`run_all_forecasts.sh`**
   - Master script to run both models sequentially
   - Checks dependencies, installs if needed
   - Total runtime: ~15 minutes

### Supporting Files

4. **`01_create_forecast_tables.sql`**
   - Creates 4 BigQuery tables for forecasts
   - Run once to set up schema

5. **`requirements.txt`**
   - Python dependencies (Prophet, pandas, BigQuery client)

6. **`README.md`**
   - This file

## Setup

### 1. Install Dependencies

```bash
cd forecasting
pip3 install -r requirements.txt
```

Dependencies:
- `prophet==1.1.5` - Time series forecasting
- `pandas==2.1.4` - Data manipulation
- `google-cloud-bigquery==3.14.1` - BigQuery client
- `scikit-learn==1.3.2` - Model metrics

### 2. Create BigQuery Tables

```bash
bq query --location=us-central1 --use_legacy_sql=false < 01_create_forecast_tables.sql
```

Creates:
- `gold_traffic_forecasts_by_zip`
- `gold_covid_risk_forecasts`
- `gold_traffic_forecasts_by_neighborhood`
- `gold_forecast_model_metrics`

### 3. Run Forecasting Models

**Option A: Run all models**
```bash
./run_all_forecasts.sh
```

**Option B: Run individually**
```bash
# Traffic volume forecasting
python3 traffic_volume_forecasting.py

# COVID alert forecasting
python3 covid_alert_forecasting.py
```

## Usage

### Traffic Volume Forecasting

```bash
python3 traffic_volume_forecasting.py
```

**What it does:**
1. Loads historical taxi trips (2020-2025) aggregated daily by ZIP
2. Trains separate Prophet model for each ZIP code
3. Splits data: 80% training, 20% testing
4. Evaluates model on holdout set (MAE, RMSE, MAPE, R²)
5. Generates 90-day forecasts with confidence intervals
6. Writes forecasts and metrics to BigQuery

**Output Example:**
```
ZIP 60007: MAE=245 trips/day, MAPE=18.3%, R²=0.847
ZIP 60018: MAE=1,823 trips/day, MAPE=12.1%, R²=0.912
...
```

**Use Cases:**
- **Construction Planning:** Schedule roadwork during predicted low-traffic periods
- **Resource Allocation:** Plan taxi fleet deployment by ZIP
- **Revenue Forecasting:** Predict future trip volumes

### COVID-19 Alert Forecasting

```bash
python3 covid_alert_forecasting.py
```

**What it does:**
1. Loads COVID hotspots data with mobility indicators
2. Trains Prophet models with mobility as regressor
3. Generates 12-week risk forecasts
4. Classifies risk into Low/Medium/High categories
5. Generates alert levels and actionable messages
6. Writes forecasts to BigQuery

**Output Example:**
```
ZIP 60007: CAUTION - Medium risk, increasing mobility
ZIP 60018: WARNING - High COVID risk (1,245 cases/week predicted)
...
```

**Alert Levels:**
- **CRITICAL** (risk ≥70): Avoid non-essential travel
- **WARNING** (risk 50-70): Exercise caution, follow safety protocols
- **CAUTION** (risk 30-50 + rising): Monitor situation closely
- **NONE** (risk <30): Standard safety measures

## Model Details

### Traffic Volume Model (Prophet)

**Features:**
- **Trend:** Long-term changes (pandemic impact, recovery)
- **Yearly Seasonality:** Construction season (warm months) vs winter
- **Weekly Seasonality:** Weekday vs weekend patterns
- **Changepoints:** Automatic detection of trend changes

**Hyperparameters:**
```python
changepoint_prior_scale = 0.05   # Flexibility of trend
seasonality_prior_scale = 10.0   # Strength of seasonality
seasonality_mode = 'multiplicative'  # Seasonal effects scale with trend
```

**Performance:**
- Average MAE: ~350 trips/day
- Average MAPE: ~15-20%
- Average R²: ~0.85

### COVID Risk Model (Prophet with Regressors)

**Features:**
- **Base Risk:** COVID cases, test positivity rate
- **Mobility Regressor:** Weekly taxi trip counts (normalized)
- **Case Rate Regressor:** Cases per 100K population
- **Yearly Seasonality:** Seasonal COVID patterns

**Hyperparameters:**
```python
changepoint_prior_scale = 0.1
seasonality_prior_scale = 5.0
mobility_prior_scale = 10.0      # Weight of mobility regressor
case_rate_prior_scale = 15.0     # Weight of case rate regressor
```

**Risk Score Calculation:**
```
Risk Score (0-100) = f(cases, test_positivity, mobility, seasonality)

Categories:
  Low:    0-20
  Medium: 20-50
  High:   50-100
```

## Output Tables

### 1. gold_traffic_forecasts_by_zip

| Column | Type | Description |
|--------|------|-------------|
| zip_code | STRING | ZIP code |
| forecast_date | DATE | Date of forecast |
| forecast_type | STRING | 'daily', 'weekly', 'monthly' |
| yhat | FLOAT64 | Point forecast (trips/day) |
| yhat_lower | FLOAT64 | Lower bound (95% CI) |
| yhat_upper | FLOAT64 | Upper bound (95% CI) |
| trend | FLOAT64 | Trend component |
| yearly | FLOAT64 | Yearly seasonality effect |
| weekly | FLOAT64 | Weekly seasonality effect |
| model_trained_date | DATE | When model was trained |
| training_days | INT64 | # days used for training |
| model_version | STRING | Model version (v1.0.0) |

**Sample Query:**
```sql
-- Get next 30 days of forecasts for O'Hare Airport area
SELECT
  zip_code,
  forecast_date,
  ROUND(yhat, 0) as predicted_trips,
  ROUND(yhat_lower, 0) as lower_bound,
  ROUND(yhat_upper, 0) as upper_bound
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_traffic_forecasts_by_zip`
WHERE zip_code IN ('60666', '60018')  -- O'Hare area
  AND forecast_date BETWEEN CURRENT_DATE() AND DATE_ADD(CURRENT_DATE(), INTERVAL 30 DAY)
ORDER BY forecast_date
```

### 2. gold_covid_risk_forecasts

| Column | Type | Description |
|--------|------|-------------|
| zip_code | STRING | ZIP code |
| forecast_date | DATE | Week start date |
| predicted_risk_score | FLOAT64 | Risk score (0-100) |
| predicted_risk_category | STRING | Low/Medium/High |
| predicted_case_rate | FLOAT64 | Cases per 100K |
| predicted_positivity_rate | FLOAT64 | Test positivity % |
| risk_score_lower | FLOAT64 | Lower confidence bound |
| risk_score_upper | FLOAT64 | Upper confidence bound |
| alert_level | STRING | NONE/CAUTION/WARNING/CRITICAL |
| alert_message | STRING | Human-readable alert |
| model_trained_date | DATE | Training date |
| model_version | STRING | Model version |

**Sample Query:**
```sql
-- Get high-risk ZIP codes for next week
SELECT
  zip_code,
  forecast_date,
  predicted_risk_category,
  alert_level,
  alert_message
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts`
WHERE predicted_risk_category = 'High'
  AND forecast_date >= CURRENT_DATE()
ORDER BY predicted_risk_score DESC
```

### 3. gold_forecast_model_metrics

Performance metrics for monitoring model quality.

**Sample Query:**
```sql
-- Get model performance summary
SELECT
  model_name,
  ROUND(mae, 1) as mae,
  ROUND(mape, 1) as mape_percent,
  ROUND(r_squared, 3) as r_squared,
  training_records
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_forecast_model_metrics`
WHERE trained_date = CURRENT_DATE()
ORDER BY model_name
```

## Automation

### Schedule Weekly Refresh

Use Cloud Scheduler to run forecasts weekly:

```bash
# Create Cloud Scheduler job
gcloud scheduler jobs create http weekly-prophet-forecasts \
  --schedule="0 2 * * 1" \
  --time-zone="America/Chicago" \
  --uri="https://us-central1-run.googleapis.com/.../run_forecasts" \
  --http-method=POST \
  --location=us-central1
```

Recommended schedule:
- **Traffic Forecasts:** Weekly (Mondays 2 AM)
- **COVID Forecasts:** Weekly (if COVID data resumes)

## Dashboard Integration

### Looker Studio Queries

**1. Traffic Forecast Chart**
```sql
SELECT
  forecast_date,
  zip_code,
  yhat as predicted_trips,
  yhat_lower,
  yhat_upper
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_traffic_forecasts_by_zip`
WHERE zip_code = @zip_code_parameter
  AND forecast_date BETWEEN CURRENT_DATE() AND DATE_ADD(CURRENT_DATE(), INTERVAL 30 DAY)
```

**2. COVID Alert Map**
```sql
SELECT
  z.zip_code,
  z.geometry,
  f.predicted_risk_category,
  f.alert_level,
  f.alert_message
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts` f
JOIN `chicago-bi-app-msds-432-476520.reference_data.zip_code_boundaries` z
  ON f.zip_code = CAST(z.zip AS STRING)
WHERE f.forecast_date = (SELECT MAX(forecast_date) FROM `...gold_covid_risk_forecasts`)
```

## Troubleshooting

### Issue: "Prophet not installed"
```bash
pip3 install prophet==1.1.5
```

### Issue: "Insufficient data for ZIP code"
Some ZIP codes may have <1 year of data. These are automatically skipped.

### Issue: "BigQuery authentication error"
```bash
gcloud auth application-default login
gcloud config set project chicago-bi-app-msds-432-476520
```

### Issue: Slow training
- Normal: ~8-10 minutes for 57 ZIP codes
- If slower: Check BigQuery quotas, network connection

## Monitoring

### Check Model Performance

```sql
SELECT
  AVG(mae) as avg_mae,
  AVG(mape) as avg_mape,
  AVG(r_squared) as avg_r2,
  COUNT(*) as models_trained
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_forecast_model_metrics`
WHERE trained_date = CURRENT_DATE()
  AND model_name LIKE 'traffic_forecast%'
```

**Thresholds:**
- MAE < 500 trips/day: Good
- MAPE < 25%: Good
- R² > 0.7: Good

### Check Forecast Freshness

```sql
SELECT
  MAX(model_trained_date) as last_trained,
  MAX(forecast_date) as last_forecast_date,
  COUNT(DISTINCT zip_code) as zip_codes_covered
FROM `chicago-bi-app-msds-432-476520.gold_data.gold_traffic_forecasts_by_zip`
```

## Future Enhancements

1. **Hourly Forecasts:** Use `gold_taxi_hourly_by_zip` for finer granularity
2. **Neighborhood Forecasts:** Implement `gold_traffic_forecasts_by_neighborhood`
3. **Weather Integration:** Add weather as regressor (temperature, precipitation)
4. **Event Detection:** Account for special events (concerts, sports, holidays)
5. **Ensemble Models:** Combine Prophet with ARIMA, LSTM for improved accuracy
6. **Real-time Updates:** Stream recent data for continuous model refresh

## References

- **Prophet Documentation:** https://facebook.github.io/prophet/
- **Project Requirements:** See main README.md
- **Related Tables:** gold_taxi_daily_by_zip, gold_covid_hotspots

## Support

For questions or issues:
- Check logs: `python3 traffic_volume_forecasting.py > forecast.log 2>&1`
- Validate BigQuery tables exist and have data
- Review model metrics for performance degradation
- Contact: Group 2 - MSDS 432

---

**Last Updated:** November 13, 2025
**Version:** 1.0.0
**Requirements:** 1, 4, 9
