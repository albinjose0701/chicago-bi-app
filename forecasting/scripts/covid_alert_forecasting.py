#!/usr/bin/env python3
"""
COVID-19 Alert Forecasting using Prophet
Requirement 1: Forecast COVID-19 alerts (Low/Medium/High) considering
taxi trips and COVID-19 positive test cases

This script:
1. Loads historical COVID + mobility data from BigQuery
2. Trains Prophet models for COVID risk by ZIP code
3. Generates weekly forecasts with alert levels
4. Writes results back to BigQuery

Note: COVID data is available through May 2024, so this generates
historical forecasts to demonstrate the capability for when data resumes.
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
MODEL_VERSION = "v1.0.0"
FORECAST_WEEKS = 12  # 3 months ahead
TRAIN_TEST_SPLIT = 0.8

# BigQuery client
client = bigquery.Client(project=PROJECT_ID)

def load_covid_and_mobility_data():
    """Load COVID hotspots data with mobility indicators"""
    print("\n[1/6] Loading COVID + mobility data from BigQuery...")

    query = f"""
    SELECT
      c.zip_code,
      c.week_start,
      c.adjusted_risk_score as risk_score,
      c.risk_category,
      c.cases_weekly,
      c.case_rate_weekly,
      SAFE_DIVIDE(c.cases_weekly * 100.0, c.tests_weekly) as positivity_rate,
      c.tests_weekly,
      c.total_trips_from_zip + c.total_trips_to_zip as mobility_index,
      c.population
    FROM `{PROJECT_ID}.{DATASET_ID}.gold_covid_hotspots` c
    WHERE c.week_start >= '2020-03-01'
      AND c.week_start <= '2024-05-12'
    ORDER BY c.zip_code, c.week_start
    """

    df = client.query(query).to_dataframe()
    print(f"   ✅ Loaded {len(df):,} records")
    print(f"   ✅ Date range: {df['week_start'].min()} to {df['week_start'].max()}")
    print(f"   ✅ ZIP codes: {df['zip_code'].nunique()}")
    print(f"   ✅ Weeks: {df['week_start'].nunique()}")

    return df

def prepare_covid_prophet_data(df, zip_code):
    """Prepare data in Prophet format with mobility as regressor"""
    zip_df = df[df['zip_code'] == zip_code].copy()

    # Prepare for Prophet
    zip_df = zip_df.rename(columns={
        'week_start': 'ds',
        'risk_score': 'y'
    })

    # Ensure numeric columns are float type
    zip_df['mobility_index'] = pd.to_numeric(zip_df['mobility_index'], errors='coerce')
    zip_df['case_rate_weekly'] = pd.to_numeric(zip_df['case_rate_weekly'], errors='coerce')
    zip_df['cases_weekly'] = pd.to_numeric(zip_df['cases_weekly'], errors='coerce')
    zip_df['positivity_rate'] = pd.to_numeric(zip_df['positivity_rate'], errors='coerce')
    zip_df['risk_score'] = pd.to_numeric(zip_df['risk_score'], errors='coerce')

    # Add regressors (normalized with safe division)
    mobility_std = zip_df['mobility_index'].std()
    if mobility_std > 0:
        zip_df['mobility'] = (zip_df['mobility_index'] - zip_df['mobility_index'].mean()) / mobility_std
    else:
        zip_df['mobility'] = 0

    zip_df['case_rate'] = zip_df['case_rate_weekly']

    zip_df = zip_df[['ds', 'y', 'mobility', 'case_rate', 'cases_weekly', 'positivity_rate', 'mobility_index']].sort_values('ds')

    # Fill NA values only in numeric columns (not dates)
    numeric_cols = ['y', 'mobility', 'case_rate', 'cases_weekly', 'positivity_rate', 'mobility_index']
    for col in numeric_cols:
        zip_df[col] = pd.to_numeric(zip_df[col], errors='coerce').fillna(0)

    return zip_df

def train_covid_prophet_model(df_prophet, zip_code):
    """Train Prophet model for COVID risk prediction"""
    # Split into train/test
    split_idx = int(len(df_prophet) * TRAIN_TEST_SPLIT)
    train = df_prophet.iloc[:split_idx]
    test = df_prophet.iloc[split_idx:]

    # Train Prophet model with regressors
    model = Prophet(
        changepoint_prior_scale=0.1,
        seasonality_prior_scale=5.0,
        seasonality_mode='additive',
        yearly_seasonality=True,
        weekly_seasonality=False,
        daily_seasonality=False
    )

    # Add mobility as regressor
    model.add_regressor('mobility', prior_scale=10.0)
    model.add_regressor('case_rate', prior_scale=15.0)

    model.fit(train)

    # Evaluate on test set
    test_forecast = model.predict(test[['ds', 'mobility', 'case_rate']])
    test_metrics = calculate_metrics(test['y'].values, test_forecast['yhat'].values)

    return model, test_metrics, len(train)

def calculate_metrics(y_true, y_pred):
    """Calculate forecast accuracy metrics"""
    mae = mean_absolute_error(y_true, y_pred)
    rmse = np.sqrt(mean_squared_error(y_true, y_pred))
    mape = np.mean(np.abs((y_true - y_pred) / np.maximum(y_true, 1))) * 100  # Avoid division by zero
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

def generate_alert_level(risk_score, trend):
    """Generate alert level based on risk score and trend"""
    if risk_score >= 70:
        return 'CRITICAL'
    elif risk_score >= 50:
        return 'WARNING'
    elif risk_score >= 30 and trend > 5:
        return 'CAUTION'
    else:
        return 'NONE'

def generate_alert_message(zip_code, risk_category, alert_level, predicted_cases):
    """Generate human-readable alert message"""
    if alert_level == 'CRITICAL':
        return f"CRITICAL: ZIP {zip_code} has {risk_category} COVID risk ({predicted_cases:.0f} cases/week predicted). Avoid non-essential travel."
    elif alert_level == 'WARNING':
        return f"WARNING: ZIP {zip_code} shows {risk_category} COVID risk. Exercise caution and follow safety protocols."
    elif alert_level == 'CAUTION':
        return f"CAUTION: ZIP {zip_code} has increasing COVID activity. Monitor situation closely."
    else:
        return f"ZIP {zip_code} has {risk_category} COVID risk. Continue standard safety measures."

def generate_forecasts(model, df_prophet, last_date, forecast_weeks):
    """Generate future forecasts with regressors"""
    # Get last known date as Timestamp
    if isinstance(last_date, pd.Timestamp):
        last_date_ts = last_date
    else:
        last_date_ts = pd.Timestamp(last_date)

    # Create future Monday dates manually (weekly frequency)
    future_dates = []
    current_date = last_date_ts + pd.Timedelta(days=7)

    # Ensure it's a Monday
    while current_date.dayofweek != 0:
        current_date += pd.Timedelta(days=1)

    # Generate forecast_weeks of Mondays
    for i in range(forecast_weeks):
        future_dates.append(current_date)
        current_date += pd.Timedelta(days=7)

    future = pd.DataFrame({'ds': future_dates})

    # Use last known values for regressors (in real scenario, would forecast these too)
    last_mobility = df_prophet['mobility'].iloc[-4:].mean()  # Last month average
    last_case_rate = df_prophet['case_rate'].iloc[-4:].mean()

    future['mobility'] = last_mobility
    future['case_rate'] = last_case_rate

    # Generate forecast
    forecast = model.predict(future)

    return forecast

def process_zip_code_covid(df, zip_code):
    """Train model and generate COVID forecasts for a single ZIP code"""
    try:
        # Prepare data
        df_prophet = prepare_covid_prophet_data(df, zip_code)

        if len(df_prophet) < 52:  # Need at least 1 year of weekly data
            print(f"   ⚠️  {zip_code}: Insufficient data ({len(df_prophet)} weeks)")
            return None, None

        # Train model
        model, metrics, training_weeks = train_covid_prophet_model(df_prophet, zip_code)

        # Generate forecasts
        last_date = df_prophet['ds'].max()
        forecast = generate_forecasts(model, df_prophet, last_date, FORECAST_WEEKS)

        # Calculate trend from last 4 weeks
        recent_trend = df_prophet['y'].iloc[-4:].diff().mean()

        # Prepare forecast records
        forecast_records = []
        for _, row in forecast.iterrows():
            risk_score = max(0, min(100, row['yhat']))  # Clamp to 0-100
            risk_category = classify_risk(risk_score)
            alert_level = generate_alert_level(risk_score, recent_trend)

            # Estimate cases and positivity (simplified - in real scenario would forecast these separately)
            predicted_cases = max(0, df_prophet['cases_weekly'].iloc[-4:].mean() * (risk_score / df_prophet['y'].iloc[-4:].mean()))
            predicted_positivity = max(0, min(100, df_prophet['positivity_rate'].iloc[-4:].mean() * (risk_score / df_prophet['y'].iloc[-4:].mean())))

            # Convert date properly
            forecast_date = row['ds']
            if isinstance(forecast_date, pd.Timestamp):
                forecast_date = forecast_date.date()

            forecast_records.append({
                'zip_code': zip_code,
                'forecast_date': forecast_date,
                'predicted_risk_score': risk_score,
                'predicted_risk_category': risk_category,
                'predicted_case_rate': df_prophet['case_rate'].iloc[-1],  # Last known
                'predicted_positivity_rate': predicted_positivity,
                'risk_score_lower': max(0, row['yhat_lower']),
                'risk_score_upper': min(100, row['yhat_upper']),
                'predicted_mobility_index': df_prophet['mobility_index'].iloc[-1],
                'predicted_cases_weekly': int(predicted_cases),
                'predicted_tests_weekly': None,
                'alert_level': alert_level,
                'alert_message': generate_alert_message(zip_code, risk_category, alert_level, predicted_cases),
                'model_trained_date': datetime.now().date(),
                'training_weeks': training_weeks,
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
            'changepoint_prior_scale': 0.1,
            'seasonality_prior_scale': 5.0,
            'seasonality_mode': 'additive',
            'zip_code': zip_code,
            'neighborhood': None,
            'notes': f'{FORECAST_WEEKS}-week COVID risk forecast with mobility regressor'
        }

        print(f"   ✅ {zip_code}: MAE={metrics['mae']:.1f}, MAPE={metrics['mape']:.1f}%, R²={metrics['r2']:.3f}")

        return forecast_records, metrics_record

    except Exception as e:
        import traceback
        print(f"   ❌ {zip_code}: Error - {str(e)}")
        # Uncomment for detailed debugging:
        # print(traceback.format_exc())
        return None, None

def write_to_bigquery(forecast_records, metrics_records):
    """Write forecasts and metrics to BigQuery"""
    print("\n[5/6] Writing COVID forecasts to BigQuery...")

    # Write forecasts
    forecast_df = pd.DataFrame(forecast_records)

    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    table_id = f"{PROJECT_ID}.{DATASET_ID}.gold_covid_risk_forecasts"
    job = client.load_table_from_dataframe(forecast_df, table_id, job_config=job_config)
    job.result()

    print(f"   ✅ Wrote {len(forecast_df):,} forecast records")

    # Append metrics
    print("\n[6/6] Writing model metrics to BigQuery...")
    metrics_df = pd.DataFrame(metrics_records)

    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
    )

    table_id = f"{PROJECT_ID}.{DATASET_ID}.gold_forecast_model_metrics"
    job = client.load_table_from_dataframe(metrics_df, table_id, job_config=job_config)
    job.result()

    print(f"   ✅ Appended {len(metrics_df):,} metrics records")

def main():
    """Main COVID forecasting pipeline"""
    print("=" * 60)
    print("COVID-19 ALERT FORECASTING WITH PROPHET")
    print(f"Requirement 1: Forecast COVID alerts considering mobility")
    print("=" * 60)

    # Load data
    df = load_covid_and_mobility_data()

    # Get list of ZIP codes
    zip_codes = sorted(df['zip_code'].unique())

    print(f"\n[2/6] Training Prophet models for {len(zip_codes)} ZIP codes...")
    print("   This may take 3-5 minutes...")

    # Train models for each ZIP code
    all_forecasts = []
    all_metrics = []

    for i, zip_code in enumerate(zip_codes, 1):
        print(f"   [{i}/{len(zip_codes)}] Processing {zip_code}...", end=" ")

        forecast_records, metrics_record = process_zip_code_covid(df, zip_code)

        if forecast_records:
            all_forecasts.extend(forecast_records)
            all_metrics.append(metrics_record)

    print(f"\n[3/6] Successfully trained {len(all_metrics)} models")
    print(f"[4/6] Generated {len(all_forecasts):,} forecast records ({FORECAST_WEEKS} weeks × {len(all_metrics)} ZIPs)")

    # Write to BigQuery
    if all_forecasts and all_metrics:
        write_to_bigquery(all_forecasts, all_metrics)

        # Summary statistics
        print("\n" + "=" * 60)
        print("COVID FORECASTING COMPLETE!")
        print("=" * 60)

        forecast_df = pd.DataFrame(all_forecasts)
        metrics_df = pd.DataFrame(all_metrics)

        print(f"\nModel Performance Summary:")
        print(f"  Average MAE:  {metrics_df['mae'].mean():.1f} risk points")
        print(f"  Average MAPE: {metrics_df['mape'].mean():.1f}%")
        print(f"  Average R²:   {metrics_df['r_squared'].mean():.3f}")

        print(f"\nForecast Coverage:")
        print(f"  ZIP Codes:     {len(all_metrics)}")
        print(f"  Forecast Weeks: {FORECAST_WEEKS}")
        print(f"  Total Records:  {len(all_forecasts):,}")

        print(f"\nRisk Distribution (Forecasted):")
        print(forecast_df['predicted_risk_category'].value_counts())

        print(f"\nAlert Distribution (Forecasted):")
        print(forecast_df['alert_level'].value_counts())

    else:
        print("\n❌ No forecasts generated - check errors above")

if __name__ == "__main__":
    main()
