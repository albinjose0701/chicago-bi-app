#!/usr/bin/env python3
"""
COVID-19 Alert Forecasting - RETROSPECTIVE VERSION for Dashboard Demo
Train on 2020 data → Forecast 2021-2024

This version demonstrates "what-if" scenario: What would the model have predicted
during the active pandemic if we had this forecasting tool?

Approach:
- Training data: 2020 only (~40 weeks of pandemic data)
- Forecast horizon: Jan 2021 through Dec 2024 (~208 weeks)
- Purpose: Show meaningful risk variations for dashboard visualization
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from prophet import Prophet
from google.cloud import bigquery
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import warnings
warnings.filterwarnings('ignore')

# Configuration
PROJECT_ID = "chicago-bi-app-msds-432-476520"
DATASET_ID = "gold_data"
MODEL_VERSION = "v1.7.0-smooth-variation"
FORECAST_WEEKS = 156  # ~3 years (2022-2024)
TRAIN_TEST_SPLIT = 0.8
TEST_SINGLE_ZIP = False  # Set to True for testing
TEST_ZIP = "60601"  # Downtown Chicago for testing

# BigQuery client
client = bigquery.Client(project=PROJECT_ID)

def load_covid_data():
    """Load COVID hotspots data - May 2020 to May 2021 (focused training period)"""
    print("\n[1/5] Loading COVID risk data from BigQuery (May 2020 - May 2021)...")

    query = f"""
    SELECT
      zip_code,
      week_start,
      adjusted_risk_score,
      risk_category,
      cases_weekly,
      case_rate_weekly,
      tests_weekly,
      total_trips_from_zip + total_trips_to_zip as total_mobility
    FROM `{PROJECT_ID}.{DATASET_ID}.gold_covid_hotspots`
    WHERE week_start >= '2020-05-01'
      AND week_start <= '2021-05-31'  -- 12 months focused period
      AND adjusted_risk_score IS NOT NULL
    ORDER BY zip_code, week_start
    """

    df = client.query(query).to_dataframe()
    print(f"   ✅ Loaded {len(df):,} records")
    print(f"   ✅ Date range: {df['week_start'].min()} to {df['week_start'].max()}")
    print(f"   ✅ ZIP codes: {df['zip_code'].nunique()}")
    print(f"   ✅ Weeks: {df['week_start'].nunique()}")
    print(f"   📅 Training on May 2020 - May 2021 (avoids Winter surge skew)")

    return df

def prepare_prophet_data(df, zip_code):
    """Prepare data in Prophet format with logistic growth caps"""
    zip_df = df[df['zip_code'] == zip_code].copy()

    # Prophet expects 'ds' (date) and 'y' (target value)
    zip_df = zip_df.rename(columns={
        'week_start': 'ds',
        'adjusted_risk_score': 'y'
    })

    # Keep metadata for later use
    zip_df = zip_df[['ds', 'y', 'cases_weekly', 'case_rate_weekly', 'total_mobility', 'risk_category']].copy()

    # Ensure ds is datetime
    zip_df['ds'] = pd.to_datetime(zip_df['ds'])

    # Ensure y is numeric and handle NaNs
    zip_df['y'] = pd.to_numeric(zip_df['y'], errors='coerce')
    zip_df['y'] = zip_df['y'].fillna(zip_df['y'].median())

    # Add caps for logistic growth (prevent unbounded increase)
    zip_df['cap'] = 3.0  # Historical max risk score ~2.7
    zip_df['floor'] = 0.0  # Minimum risk score

    # Sort by date
    zip_df = zip_df.sort_values('ds').reset_index(drop=True)

    return zip_df

def train_prophet_model(df_prophet, zip_code):
    """Train tuned Prophet model with bounded logistic growth"""
    # Split into train/test
    split_idx = int(len(df_prophet) * TRAIN_TEST_SPLIT)
    train = df_prophet.iloc[:split_idx][['ds', 'y', 'cap', 'floor']].copy()
    test = df_prophet.iloc[split_idx:].copy()

    # Tuned Prophet model - smooth variation without weekly pulses (Option 1 fix)
    model = Prophet(
        growth='logistic',  # Bounded growth instead of linear
        changepoint_prior_scale=0.01,  # Very conservative - prevents wild swings
        seasonality_prior_scale=3.0,  # Reduced to avoid weekly pulse artifacts (was 10.0)
        seasonality_mode='additive',
        yearly_seasonality=True,
        weekly_seasonality=False,  # Weekly data, no weekly component
        daily_seasonality=False
    )

    # NOTE: Monthly seasonality removed - was causing weekly pulse artifacts

    # Fit model
    print(f"      Training on {len(train)} weeks (May 2020-May 2021)...", end=" ")
    model.fit(train)

    # Evaluate on test set
    test_forecast = model.predict(test[['ds', 'cap', 'floor']])
    test_metrics = calculate_metrics(test['y'].values, test_forecast['yhat'].values)

    return model, test_metrics, len(train), df_prophet

def calculate_metrics(y_true, y_pred):
    """Calculate forecast accuracy metrics"""
    mae = mean_absolute_error(y_true, y_pred)
    rmse = np.sqrt(mean_squared_error(y_true, y_pred))

    # Safe MAPE calculation
    non_zero_mask = y_true > 0
    if non_zero_mask.sum() > 0:
        mape = np.mean(np.abs((y_true[non_zero_mask] - y_pred[non_zero_mask]) / y_true[non_zero_mask])) * 100
    else:
        mape = 0

    r2 = r2_score(y_true, y_pred)

    return {
        'mae': mae,
        'rmse': rmse,
        'mape': mape,
        'r2': r2
    }

def classify_risk(risk_score):
    """Classify continuous risk score into Low/Medium/High categories
    Note: adjusted_risk_score scale is 0-3 (not 0-100)
    Based on historical data: 2020-2022 max ~2.5-2.7"""
    if risk_score < 0.5:
        return 'Low'
    elif risk_score < 1.5:
        return 'Medium'
    else:
        return 'High'

def generate_alert_level(risk_score):
    """Generate alert level based on risk score (0-3 scale)"""
    if risk_score >= 2.0:
        return 'CRITICAL'
    elif risk_score >= 1.5:
        return 'WARNING'
    elif risk_score >= 0.8:
        return 'CAUTION'
    else:
        return 'NONE'

def generate_alert_message(zip_code, risk_category, alert_level):
    """Generate human-readable alert message"""
    if alert_level == 'CRITICAL':
        return f"CRITICAL: ZIP {zip_code} has {risk_category} COVID risk. Avoid non-essential travel."
    elif alert_level == 'WARNING':
        return f"WARNING: ZIP {zip_code} shows {risk_category} COVID risk. Exercise caution."
    elif alert_level == 'CAUTION':
        return f"CAUTION: ZIP {zip_code} has {risk_category} COVID risk. Monitor situation."
    else:
        return f"ZIP {zip_code} has {risk_category} COVID risk. Continue standard safety measures."

def generate_forecasts(model, df_prophet, forecast_weeks):
    """Generate forecasts for 2021-2024 period with caps"""
    # Last training date (should be in May 2021)
    last_date = df_prophet['ds'].max()
    last_date_ts = pd.Timestamp(last_date)
    print(f"      Last training date: {last_date}")

    # Start forecasts from June 2021 (right after training ends)
    forecast_start = pd.Timestamp('2021-06-07')  # First Monday after May 2021

    # Generate weekly forecasts through end of 2024
    future_dates = pd.date_range(start=forecast_start, periods=forecast_weeks, freq='W-MON')
    future = pd.DataFrame({
        'ds': future_dates,
        'cap': 3.0,  # Same cap as training
        'floor': 0.0
    })

    print(f"      Generating {len(future)} forecasts: {future['ds'].min().date()} to {future['ds'].max().date()}")

    # Generate forecast
    forecast = model.predict(future)
    print(f"      Generated {len(forecast)} forecast rows")

    return forecast

def process_zip_code(df, zip_code):
    """Train model and generate COVID forecasts for a single ZIP code"""
    try:
        # Prepare data
        df_prophet = prepare_prophet_data(df, zip_code)

        if len(df_prophet) < 40:  # Need at least ~10 months of data
            print(f"   ⚠️  {zip_code}: Insufficient data ({len(df_prophet)} weeks)")
            return None, None

        # Train model
        model, metrics, training_weeks, full_data = train_prophet_model(df_prophet, zip_code)
        print(f"MAE={metrics['mae']:.1f}, R²={metrics['r2']:.3f}")

        # Generate forecasts for 2021-2024
        forecast = generate_forecasts(model, full_data, FORECAST_WEEKS)

        # Prepare forecast records
        forecast_records = []
        for _, row in forecast.iterrows():
            risk_score = max(0, min(3, row['yhat']))  # Clamp to 0-3 scale
            risk_category = classify_risk(risk_score)
            alert_level = generate_alert_level(risk_score)

            # Use last known values from 2020 as baseline
            last_cases = full_data['cases_weekly'].iloc[-4:].mean()
            last_case_rate = full_data['case_rate_weekly'].iloc[-4:].mean()
            last_mobility = full_data['total_mobility'].iloc[-4:].mean()

            # Convert date to date object
            forecast_date = row['ds']
            if isinstance(forecast_date, pd.Timestamp):
                forecast_date = forecast_date.date()

            forecast_records.append({
                'zip_code': zip_code,
                'forecast_date': forecast_date,
                'predicted_risk_score': risk_score,
                'predicted_risk_category': risk_category,
                'predicted_case_rate': last_case_rate,
                'predicted_positivity_rate': None,
                'risk_score_lower': max(0, row['yhat_lower']),
                'risk_score_upper': min(3, row['yhat_upper']),
                'predicted_mobility_index': last_mobility,
                'predicted_cases_weekly': int(last_cases),
                'predicted_tests_weekly': None,
                'alert_level': alert_level,
                'alert_message': generate_alert_message(zip_code, risk_category, alert_level),
                'model_trained_date': datetime.now().date(),
                'training_weeks': training_weeks,
                'model_version': MODEL_VERSION
            })

        # Prepare metrics record
        min_date = full_data['ds'].min()
        max_date = full_data['ds'].max()

        # Convert to date
        if isinstance(min_date, pd.Timestamp):
            min_date = min_date.date()
        if isinstance(max_date, pd.Timestamp):
            max_date = max_date.date()

        metrics_record = {
            'model_name': f'covid_risk_forecast_zip_{zip_code}_retrospective',
            'model_version': MODEL_VERSION,
            'trained_date': datetime.now().date(),
            'train_start_date': min_date,
            'train_end_date': max_date,
            'training_records': training_weeks,
            'mae': metrics['mae'],
            'rmse': metrics['rmse'],
            'mape': metrics['mape'],
            'r_squared': metrics['r2'],
            'changepoint_prior_scale': 0.01,
            'seasonality_prior_scale': 3.0,
            'growth': 'logistic',
            'seasonality_mode': 'additive',
            'zip_code': zip_code,
            'neighborhood': None,
            'notes': f'Option 1 fix: Smooth variation, no weekly pulses. Logistic growth, yearly seasonality only. Trained May 2020-May 2021, forecasted Jun 2021-May 2024 ({FORECAST_WEEKS} weeks). Bounded 0-3.'
        }

        print(f"      ✅ Generated {len(forecast_records)} forecasts")

        return forecast_records, metrics_record

    except Exception as e:
        import traceback
        print(f"   ❌ {zip_code}: Error - {str(e)}")
        print(traceback.format_exc())
        return None, None

def write_to_bigquery(forecast_records, metrics_records):
    """Write forecasts and metrics to BigQuery"""
    print("\n[4/5] Writing COVID forecasts to BigQuery...")

    # Write forecasts
    forecast_df = pd.DataFrame(forecast_records)

    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    table_id = f"{PROJECT_ID}.{DATASET_ID}.gold_covid_risk_forecasts"
    job = client.load_table_from_dataframe(forecast_df, table_id, job_config=job_config)
    job.result()

    print(f"   ✅ Wrote {len(forecast_df):,} forecast records to {table_id}")

    # Append metrics
    print("\n[5/5] Writing model metrics to BigQuery...")
    metrics_df = pd.DataFrame(metrics_records)

    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
    )

    table_id = f"{PROJECT_ID}.{DATASET_ID}.gold_forecast_model_metrics"
    job = client.load_table_from_dataframe(metrics_df, table_id, job_config=job_config)
    job.result()

    print(f"   ✅ Appended {len(metrics_df):,} metrics records")

def main():
    """Main COVID forecasting pipeline - RETROSPECTIVE VERSION"""
    print("=" * 70)
    print("COVID-19 ALERT FORECASTING - TUNED MODEL")
    print(f"Training: May 2020 - May 2021 (focused 12-month period)")
    print(f"Forecast: June 2021 - Dec 2024 ({FORECAST_WEEKS} weeks)")
    print(f"Model: Logistic growth (bounded 0-3), reduced seasonality")
    print(f"Version: {MODEL_VERSION}")
    print("=" * 70)

    # Load data
    df = load_covid_data()

    # Get list of ZIP codes
    if TEST_SINGLE_ZIP:
        zip_codes = [TEST_ZIP]
        print(f"\n🧪 TEST MODE: Processing single ZIP code {TEST_ZIP}")
    else:
        zip_codes = sorted(df['zip_code'].unique())

    print(f"\n[2/5] Training Prophet models for {len(zip_codes)} ZIP code(s)...")
    print("   This may take 3-5 minutes...")

    # Train models for each ZIP code
    all_forecasts = []
    all_metrics = []

    for i, zip_code in enumerate(zip_codes, 1):
        print(f"\n   [{i}/{len(zip_codes)}] Processing ZIP {zip_code}...")

        forecast_records, metrics_record = process_zip_code(df, zip_code)

        if forecast_records:
            all_forecasts.extend(forecast_records)
            all_metrics.append(metrics_record)

    print(f"\n[3/5] Successfully trained {len(all_metrics)} model(s)")
    print(f"      Generated {len(all_forecasts):,} forecast records ({FORECAST_WEEKS} weeks × {len(all_metrics)} ZIP(s))")

    # Write to BigQuery
    if all_forecasts and all_metrics:
        write_to_bigquery(all_forecasts, all_metrics)

        # Summary statistics
        print("\n" + "=" * 70)
        print("COVID FORECASTING COMPLETE! ✅")
        print("=" * 70)

        forecast_df = pd.DataFrame(all_forecasts)
        metrics_df = pd.DataFrame(all_metrics)

        print(f"\n📊 Model Performance Summary:")
        print(f"  Average MAE:  {metrics_df['mae'].mean():.1f} risk points")
        print(f"  Average MAPE: {metrics_df['mape'].mean():.1f}%")
        print(f"  Average R²:   {metrics_df['r_squared'].mean():.3f}")

        print(f"\n📈 Forecast Coverage:")
        print(f"  ZIP Codes:      {len(all_metrics)}")
        print(f"  Forecast Weeks: {FORECAST_WEEKS}")
        print(f"  Date Range:     2021-06-07 to ~2024-12-30")
        print(f"  Total Records:  {len(all_forecasts):,}")

        print(f"\n🚨 Risk Distribution (Forecasted Jun 2021 - Dec 2024):")
        print(forecast_df['predicted_risk_category'].value_counts().to_string())

        print(f"\n⚠️  Alert Distribution (Forecasted Jun 2021 - Dec 2024):")
        print(forecast_df['alert_level'].value_counts().to_string())

        print(f"\n📊 Risk Score Statistics:")
        print(f"  Min:  {forecast_df['predicted_risk_score'].min():.1f}")
        print(f"  Max:  {forecast_df['predicted_risk_score'].max():.1f}")
        print(f"  Mean: {forecast_df['predicted_risk_score'].mean():.1f}")
        print(f"  Median: {forecast_df['predicted_risk_score'].median():.1f}")

        print(f"\n✅ Tuned forecasting complete!")
        print(f"   Dashboard will show bounded COVID risk forecasts (Jun 2021 - Dec 2024)")
        print(f"   Model: Logistic growth trained on May 2020 - May 2021")
        print(f"   Bounded at 0-3 risk score, reduced seasonality artifacts")

        if TEST_SINGLE_ZIP:
            print(f"\n💡 To run for all ZIPs, set TEST_SINGLE_ZIP = False in the script")
            print(f"   Expected: {df['zip_code'].nunique()} ZIPs × {FORECAST_WEEKS} weeks = ~{df['zip_code'].nunique() * FORECAST_WEEKS:,} records")

    else:
        print("\n❌ No forecasts generated - check errors above")

if __name__ == "__main__":
    main()
