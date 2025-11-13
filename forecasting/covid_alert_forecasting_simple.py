#!/usr/bin/env python3
"""
COVID-19 Alert Forecasting using Prophet - SIMPLIFIED VERSION (Option B)
Requirement 1: Forecast COVID-19 alerts (Low/Medium/High)

This is a simplified version that:
- Uses only basic Prophet (no regressors)
- Forecasts adjusted_risk_score directly
- Tests with single ZIP first, then expands to all ZIPs

Option B approach: Get basic model working, then add complexity incrementally
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
MODEL_VERSION = "v1.1.0-simple"
FORECAST_WEEKS = 12  # 3 months ahead
TRAIN_TEST_SPLIT = 0.8
TEST_SINGLE_ZIP = False  # Set to False to run all ZIPs
TEST_ZIP = "60601"  # Downtown Chicago for testing

# BigQuery client
client = bigquery.Client(project=PROJECT_ID)

def load_covid_data():
    """Load COVID hotspots data - simplified query"""
    print("\n[1/5] Loading COVID risk data from BigQuery...")

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
    WHERE week_start >= '2020-03-01'
      AND week_start <= '2024-05-12'
      AND adjusted_risk_score IS NOT NULL
    ORDER BY zip_code, week_start
    """

    df = client.query(query).to_dataframe()
    print(f"   ✅ Loaded {len(df):,} records")
    print(f"   ✅ Date range: {df['week_start'].min()} to {df['week_start'].max()}")
    print(f"   ✅ ZIP codes: {df['zip_code'].nunique()}")
    print(f"   ✅ Weeks: {df['week_start'].nunique()}")

    return df

def prepare_prophet_data(df, zip_code):
    """Prepare data in Prophet format - SIMPLIFIED (no regressors)"""
    zip_df = df[df['zip_code'] == zip_code].copy()

    # Prophet expects 'ds' (date) and 'y' (target value)
    zip_df = zip_df.rename(columns={
        'week_start': 'ds',
        'adjusted_risk_score': 'y'
    })

    # Keep only required columns + metadata for later use
    zip_df = zip_df[['ds', 'y', 'cases_weekly', 'case_rate_weekly', 'total_mobility', 'risk_category']].copy()

    # Ensure ds is datetime
    zip_df['ds'] = pd.to_datetime(zip_df['ds'])

    # Ensure y is numeric and handle NaNs
    zip_df['y'] = pd.to_numeric(zip_df['y'], errors='coerce')
    zip_df['y'] = zip_df['y'].fillna(zip_df['y'].median())  # Fill with median instead of 0

    # Sort by date
    zip_df = zip_df.sort_values('ds').reset_index(drop=True)

    return zip_df

def train_prophet_model(df_prophet, zip_code):
    """Train SIMPLIFIED Prophet model (no regressors)"""
    # Split into train/test
    split_idx = int(len(df_prophet) * TRAIN_TEST_SPLIT)
    train = df_prophet.iloc[:split_idx][['ds', 'y']].copy()
    test = df_prophet.iloc[split_idx:].copy()

    # Basic Prophet model - no regressors
    model = Prophet(
        changepoint_prior_scale=0.05,  # Less flexible (more stable)
        seasonality_prior_scale=10.0,
        seasonality_mode='additive',
        yearly_seasonality=True,
        weekly_seasonality=False,  # Weekly data, so no weekly seasonality
        daily_seasonality=False
    )

    # Fit model
    print(f"      Training on {len(train)} weeks...", end=" ")
    model.fit(train)

    # Evaluate on test set
    test_forecast = model.predict(test[['ds']])
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
    """Classify continuous risk score into Low/Medium/High categories"""
    if risk_score < 20:
        return 'Low'
    elif risk_score < 50:
        return 'Medium'
    else:
        return 'High'

def generate_alert_level(risk_score):
    """Generate alert level based on risk score"""
    if risk_score >= 70:
        return 'CRITICAL'
    elif risk_score >= 50:
        return 'WARNING'
    elif risk_score >= 30:
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
    """Generate future forecasts"""
    # Get last date
    last_date = df_prophet['ds'].max()
    last_date_ts = pd.Timestamp(last_date)
    print(f"      Last historical date: {last_date}")

    # Create future dates manually to ensure they're truly in the future
    # Start from next Monday after last_date
    next_date = last_date_ts + pd.Timedelta(days=7)

    # Adjust to Monday if not already
    while next_date.dayofweek != 0:  # 0 = Monday
        next_date += pd.Timedelta(days=1)

    # Generate forecast_weeks of future Mondays
    future_dates = pd.date_range(start=next_date, periods=forecast_weeks, freq='W-MON')
    future = pd.DataFrame({'ds': future_dates})

    print(f"      Created {len(future)} future dates: {future['ds'].min().date()} to {future['ds'].max().date()}")

    # Generate forecast
    forecast = model.predict(future)
    print(f"      Generated {len(forecast)} forecast rows")

    return forecast

def process_zip_code(df, zip_code):
    """Train model and generate COVID forecasts for a single ZIP code"""
    try:
        # Prepare data
        df_prophet = prepare_prophet_data(df, zip_code)

        if len(df_prophet) < 52:  # Need at least 1 year of weekly data
            print(f"   ⚠️  {zip_code}: Insufficient data ({len(df_prophet)} weeks)")
            return None, None

        # Train model
        model, metrics, training_weeks, full_data = train_prophet_model(df_prophet, zip_code)
        print(f"MAE={metrics['mae']:.1f}, R²={metrics['r2']:.3f}")

        # Generate forecasts
        forecast = generate_forecasts(model, full_data, FORECAST_WEEKS)

        # Prepare forecast records
        forecast_records = []
        for _, row in forecast.iterrows():
            risk_score = max(0, min(100, row['yhat']))  # Clamp to 0-100
            risk_category = classify_risk(risk_score)
            alert_level = generate_alert_level(risk_score)

            # Get last known values for reference
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
                'predicted_positivity_rate': None,  # Not forecasting this yet
                'risk_score_lower': max(0, row['yhat_lower']),
                'risk_score_upper': min(100, row['yhat_upper']),
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
            'model_name': f'covid_risk_forecast_zip_{zip_code}',
            'model_version': MODEL_VERSION,
            'trained_date': datetime.now().date(),
            'train_start_date': min_date,
            'train_end_date': max_date,
            'training_records': training_weeks,
            'mae': metrics['mae'],
            'rmse': metrics['rmse'],
            'mape': metrics['mape'],
            'r_squared': metrics['r2'],
            'changepoint_prior_scale': 0.05,
            'seasonality_prior_scale': 10.0,
            'seasonality_mode': 'additive',
            'zip_code': zip_code,
            'neighborhood': None,
            'notes': f'{FORECAST_WEEKS}-week COVID risk forecast (simplified model, no regressors)'
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
    """Main COVID forecasting pipeline - SIMPLIFIED"""
    print("=" * 70)
    print("COVID-19 ALERT FORECASTING - SIMPLIFIED VERSION (Option B)")
    print(f"Model: Basic Prophet (no regressors)")
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
    print("   This may take 2-4 minutes...")

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
        print(f"  Total Records:  {len(all_forecasts):,}")

        print(f"\n🚨 Risk Distribution (Forecasted):")
        print(forecast_df['predicted_risk_category'].value_counts().to_string())

        print(f"\n⚠️  Alert Distribution (Forecasted):")
        print(forecast_df['alert_level'].value_counts().to_string())

        if TEST_SINGLE_ZIP:
            print(f"\n✅ Single ZIP test successful!")
            print(f"\n💡 To run for all ZIPs, set TEST_SINGLE_ZIP = False in the script")
            print(f"   Expected: {df['zip_code'].nunique()} ZIPs × {FORECAST_WEEKS} weeks = ~{df['zip_code'].nunique() * FORECAST_WEEKS} records")

    else:
        print("\n❌ No forecasts generated - check errors above")

if __name__ == "__main__":
    main()
