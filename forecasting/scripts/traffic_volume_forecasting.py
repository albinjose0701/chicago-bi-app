#!/usr/bin/env python3
"""
Traffic Volume Forecasting using Prophet
Requirements 4 & 9: Forecast daily/weekly/monthly traffic patterns by ZIP code

This script:
1. Loads historical taxi trip data from BigQuery
2. Trains Prophet models for each ZIP code
3. Generates 30/90-day forecasts
4. Calculates model performance metrics
5. Writes results back to BigQuery
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
MODEL_VERSION = "v1.1.0"  # Fixed: Now forecasts from full dataset (2025-11-01 onwards)
FORECAST_DAYS = 90  # 3 months ahead
TRAIN_TEST_SPLIT = 0.8  # 80% training, 20% testing

# BigQuery client
client = bigquery.Client(project=PROJECT_ID)

def load_training_data():
    """Load historical taxi trip data aggregated by ZIP code and date"""
    print("\n[1/6] Loading training data from BigQuery...")

    query = f"""
    SELECT
      pickup_zip as zip_code,
      trip_date,
      SUM(trip_count) as trip_count
    FROM `{PROJECT_ID}.{DATASET_ID}.gold_taxi_daily_by_zip`
    WHERE pickup_zip IS NOT NULL
      AND trip_date >= '2020-01-01'
      AND trip_date <= '2025-10-31'
    GROUP BY pickup_zip, trip_date
    ORDER BY pickup_zip, trip_date
    """

    df = client.query(query).to_dataframe()
    print(f"   ✅ Loaded {len(df):,} records")
    print(f"   ✅ Date range: {df['trip_date'].min()} to {df['trip_date'].max()}")
    print(f"   ✅ ZIP codes: {df['zip_code'].nunique()}")

    return df

def prepare_prophet_data(df, zip_code):
    """Prepare data in Prophet format (ds, y)"""
    zip_df = df[df['zip_code'] == zip_code].copy()
    zip_df = zip_df.rename(columns={'trip_date': 'ds', 'trip_count': 'y'})
    zip_df = zip_df[['ds', 'y']].sort_values('ds')
    return zip_df

def train_prophet_model(df_prophet, zip_code):
    """Train Prophet model for a single ZIP code"""
    # Split into train/test
    split_idx = int(len(df_prophet) * TRAIN_TEST_SPLIT)
    train = df_prophet.iloc[:split_idx]
    test = df_prophet.iloc[split_idx:]

    # Train Prophet model
    model = Prophet(
        changepoint_prior_scale=0.05,
        seasonality_prior_scale=10.0,
        seasonality_mode='multiplicative',
        yearly_seasonality=True,
        weekly_seasonality=True,
        daily_seasonality=False
    )

    model.fit(train)

    # Evaluate on test set
    test_forecast = model.predict(test[['ds']])
    test_metrics = calculate_metrics(test['y'].values, test_forecast['yhat'].values)

    return model, test_metrics, len(train)

def calculate_metrics(y_true, y_pred):
    """Calculate forecast accuracy metrics"""
    mae = mean_absolute_error(y_true, y_pred)
    rmse = np.sqrt(mean_squared_error(y_true, y_pred))
    mape = np.mean(np.abs((y_true - y_pred) / y_true)) * 100
    r2 = r2_score(y_true, y_pred)

    return {
        'mae': mae,
        'rmse': rmse,
        'mape': mape,
        'r2': r2
    }

def generate_forecasts(model, last_date, forecast_days):
    """Generate future forecasts"""
    # Create ONLY future dates (not including historical)
    future = model.make_future_dataframe(periods=forecast_days, freq='D', include_history=False)
    forecast = model.predict(future)
    return forecast

def process_zip_code(df, zip_code):
    """Train model and generate forecasts for a single ZIP code"""
    try:
        # Prepare data
        df_prophet = prepare_prophet_data(df, zip_code)

        if len(df_prophet) < 365:  # Need at least 1 year of data
            print(f"   ⚠️  {zip_code}: Insufficient data ({len(df_prophet)} days)")
            return None, None

        # Train model with train/test split for validation metrics
        model_for_validation, metrics, training_days = train_prophet_model(df_prophet, zip_code)

        # Retrain on FULL dataset for actual forecasts (better accuracy)
        model_full = Prophet(
            changepoint_prior_scale=0.05,
            seasonality_prior_scale=10.0,
            seasonality_mode='multiplicative',
            yearly_seasonality=True,
            weekly_seasonality=True,
            daily_seasonality=False
        )
        model_full.fit(df_prophet)

        # Generate forecasts from the FULL dataset end
        last_date = df_prophet['ds'].max()  # Each ZIP's last available data date
        forecast = generate_forecasts(model_full, last_date, FORECAST_DAYS)

        # Prepare forecast records
        forecast_records = []
        for _, row in forecast.iterrows():
            forecast_records.append({
                'zip_code': zip_code,
                'forecast_date': row['ds'].date(),
                'forecast_type': 'daily',
                'yhat': max(0, row['yhat']),  # No negative trips
                'yhat_lower': max(0, row['yhat_lower']),
                'yhat_upper': row['yhat_upper'],
                'trend': row['trend'],
                'yearly': row.get('yearly', 0),
                'weekly': row.get('weekly', 0),
                'model_trained_date': datetime.now().date(),
                'training_days': training_days,
                'model_version': MODEL_VERSION
            })

        # Prepare metrics record
        # Note: df_prophet['ds'] contains datetime.date objects from BigQuery DATE type
        min_date = df_prophet['ds'].min()
        max_date = df_prophet['ds'].max()

        # Convert to date if it's a Timestamp, otherwise use as-is
        if isinstance(min_date, pd.Timestamp):
            min_date = min_date.date()
        if isinstance(max_date, pd.Timestamp):
            max_date = max_date.date()

        metrics_record = {
            'model_name': f'traffic_forecast_zip_{zip_code}',
            'model_version': MODEL_VERSION,
            'trained_date': datetime.now().date(),
            'train_start_date': min_date,
            'train_end_date': max_date,
            'training_records': len(df_prophet),  # Full dataset used for forecast model
            'mae': metrics['mae'],
            'rmse': metrics['rmse'],
            'mape': metrics['mape'],
            'r_squared': metrics['r2'],
            'changepoint_prior_scale': 0.05,
            'seasonality_prior_scale': 10.0,
            'seasonality_mode': 'multiplicative',
            'zip_code': zip_code,
            'neighborhood': None,
            'notes': f'{FORECAST_DAYS}-day forecast'
        }

        print(f"   ✅ {zip_code}: MAE={metrics['mae']:.0f}, MAPE={metrics['mape']:.1f}%, R²={metrics['r2']:.3f}")

        return forecast_records, metrics_record

    except Exception as e:
        print(f"   ❌ {zip_code}: Error - {str(e)}")
        return None, None

def write_to_bigquery(forecast_records, metrics_records):
    """Write forecasts and metrics to BigQuery"""
    print("\n[5/6] Writing forecasts to BigQuery...")

    # Write forecasts
    forecast_df = pd.DataFrame(forecast_records)

    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    table_id = f"{PROJECT_ID}.{DATASET_ID}.gold_traffic_forecasts_by_zip"
    job = client.load_table_from_dataframe(forecast_df, table_id, job_config=job_config)
    job.result()

    print(f"   ✅ Wrote {len(forecast_df):,} forecast records")

    # Write metrics
    print("\n[6/6] Writing model metrics to BigQuery...")
    metrics_df = pd.DataFrame(metrics_records)

    table_id = f"{PROJECT_ID}.{DATASET_ID}.gold_forecast_model_metrics"
    job = client.load_table_from_dataframe(metrics_df, table_id, job_config=job_config)
    job.result()

    print(f"   ✅ Wrote {len(metrics_df):,} metrics records")

def main():
    """Main forecasting pipeline"""
    print("=" * 60)
    print("TRAFFIC VOLUME FORECASTING WITH PROPHET")
    print(f"Requirements: 4 & 9 (Daily/Weekly/Monthly Traffic Patterns)")
    print("=" * 60)

    # Load data
    df = load_training_data()

    # Get list of ZIP codes
    zip_codes = sorted(df['zip_code'].unique())

    print(f"\n[2/6] Training Prophet models for {len(zip_codes)} ZIP codes...")
    print("   This may take 5-10 minutes...")

    # Train models for each ZIP code
    all_forecasts = []
    all_metrics = []

    for i, zip_code in enumerate(zip_codes, 1):
        print(f"   [{i}/{len(zip_codes)}] Processing {zip_code}...", end=" ")

        forecast_records, metrics_record = process_zip_code(df, zip_code)

        if forecast_records:
            all_forecasts.extend(forecast_records)
            all_metrics.append(metrics_record)

    print(f"\n[3/6] Successfully trained {len(all_metrics)} models")
    print(f"[4/6] Generated {len(all_forecasts):,} forecast records ({FORECAST_DAYS} days × {len(all_metrics)} ZIPs)")

    # Write to BigQuery
    if all_forecasts and all_metrics:
        write_to_bigquery(all_forecasts, all_metrics)

        # Summary statistics
        print("\n" + "=" * 60)
        print("FORECASTING COMPLETE!")
        print("=" * 60)

        metrics_df = pd.DataFrame(all_metrics)
        print(f"\nModel Performance Summary:")
        print(f"  Average MAE:  {metrics_df['mae'].mean():.0f} trips/day")
        print(f"  Average MAPE: {metrics_df['mape'].mean():.1f}%")
        print(f"  Average R²:   {metrics_df['r_squared'].mean():.3f}")
        print(f"\nForecast Coverage:")
        print(f"  ZIP Codes:    {len(all_metrics)}")
        print(f"  Forecast Days: {FORECAST_DAYS}")
        print(f"  Total Records: {len(all_forecasts):,}")
        print(f"  Date Range:    {pd.DataFrame(all_forecasts)['forecast_date'].min()} to {pd.DataFrame(all_forecasts)['forecast_date'].max()}")

    else:
        print("\n❌ No forecasts generated - check errors above")

if __name__ == "__main__":
    main()
