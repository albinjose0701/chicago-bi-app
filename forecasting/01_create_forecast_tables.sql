-- ================================================
-- PROPHET FORECASTING TABLES
-- ================================================
-- Creates tables for storing Prophet model forecasts
-- Requirements: 1, 4, 9
-- ================================================

-- ================================================
-- Table 1: Traffic Volume Forecasts by ZIP Code
-- ================================================
-- Requirements 4 & 9: Forecast daily/weekly/monthly traffic patterns
-- Stores Prophet forecasts for taxi trip volumes by ZIP code

CREATE OR REPLACE TABLE `chicago-bi-app-msds-432-476520.gold_data.gold_traffic_forecasts_by_zip`
(
  zip_code STRING NOT NULL,
  forecast_date DATE NOT NULL,
  forecast_type STRING NOT NULL, -- 'daily', 'weekly', 'monthly'

  -- Prophet forecast outputs
  yhat FLOAT64,           -- Point forecast (predicted trip count)
  yhat_lower FLOAT64,     -- Lower bound of prediction interval
  yhat_upper FLOAT64,     -- Upper bound of prediction interval

  -- Trend and seasonality components
  trend FLOAT64,          -- Trend component
  yearly FLOAT64,         -- Yearly seasonality
  weekly FLOAT64,         -- Weekly seasonality (if applicable)

  -- Metadata
  model_trained_date DATE,  -- When the model was trained
  training_days INT64,      -- Number of days used for training
  model_version STRING,     -- Model version/identifier
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY forecast_date
CLUSTER BY zip_code, forecast_type
OPTIONS(
  description="Prophet forecasts for taxi trip volumes by ZIP code (Requirements 4 & 9)",
  labels=[("layer", "gold"), ("model", "prophet"), ("purpose", "traffic_forecasting")]
);

-- ================================================
-- Table 2: COVID-19 Risk Forecasts by ZIP Code
-- ================================================
-- Requirement 1: Forecast COVID-19 alerts (Low/Medium/High) considering
-- taxi trips and COVID-19 positive test cases

CREATE OR REPLACE TABLE `chicago-bi-app-msds-432-476520.gold_data.gold_covid_risk_forecasts`
(
  zip_code STRING NOT NULL,
  forecast_date DATE NOT NULL,

  -- Risk predictions
  predicted_risk_score FLOAT64,          -- Continuous risk score (0-100)
  predicted_risk_category STRING,        -- 'Low', 'Medium', 'High'
  predicted_case_rate FLOAT64,           -- Predicted cases per 100K population
  predicted_positivity_rate FLOAT64,     -- Predicted test positivity rate (%)

  -- Confidence intervals
  risk_score_lower FLOAT64,              -- Lower bound of risk score
  risk_score_upper FLOAT64,              -- Upper bound of risk score

  -- Contributing factors (predicted)
  predicted_mobility_index FLOAT64,      -- Predicted taxi trip activity
  predicted_cases_weekly INT64,          -- Predicted weekly cases
  predicted_tests_weekly INT64,          -- Predicted weekly tests

  -- Alert recommendation
  alert_level STRING,                    -- 'NONE', 'CAUTION', 'WARNING', 'CRITICAL'
  alert_message STRING,                  -- Human-readable alert message

  -- Metadata
  model_trained_date DATE,
  training_weeks INT64,
  model_version STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY forecast_date
CLUSTER BY zip_code, predicted_risk_category
OPTIONS(
  description="Prophet forecasts for COVID-19 risk levels by ZIP code (Requirement 1)",
  labels=[("layer", "gold"), ("model", "prophet"), ("purpose", "covid_forecasting")]
);

-- ================================================
-- Table 3: Neighborhood Traffic Forecasts
-- ================================================
-- Requirement 9: Forecast traffic volumes for neighborhoods (for construction planning)

CREATE OR REPLACE TABLE `chicago-bi-app-msds-432-476520.gold_data.gold_traffic_forecasts_by_neighborhood`
(
  neighborhood STRING NOT NULL,
  forecast_date DATE NOT NULL,
  forecast_type STRING NOT NULL, -- 'daily', 'weekly', 'monthly'

  -- Prophet forecast outputs
  yhat FLOAT64,
  yhat_lower FLOAT64,
  yhat_upper FLOAT64,

  -- Trend and seasonality components
  trend FLOAT64,
  yearly FLOAT64,
  weekly FLOAT64,

  -- Traffic intensity classification
  traffic_intensity STRING, -- 'Very Low', 'Low', 'Medium', 'High', 'Very High'
  construction_advisory STRING, -- Planning recommendation

  -- Metadata
  model_trained_date DATE,
  training_days INT64,
  model_version STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY forecast_date
CLUSTER BY neighborhood, forecast_type
OPTIONS(
  description="Prophet forecasts for taxi trip volumes by neighborhood (Requirement 9)",
  labels=[("layer", "gold"), ("model", "prophet"), ("purpose", "construction_planning")]
);

-- ================================================
-- Table 4: Model Performance Metrics
-- ================================================
-- Stores model performance metrics for monitoring and evaluation

CREATE OR REPLACE TABLE `chicago-bi-app-msds-432-476520.gold_data.gold_forecast_model_metrics`
(
  model_name STRING NOT NULL,
  model_version STRING NOT NULL,
  trained_date DATE NOT NULL,

  -- Training metrics
  train_start_date DATE,
  train_end_date DATE,
  training_records INT64,

  -- Performance metrics (on holdout set)
  mae FLOAT64,                 -- Mean Absolute Error
  rmse FLOAT64,                -- Root Mean Squared Error
  mape FLOAT64,                -- Mean Absolute Percentage Error
  r_squared FLOAT64,           -- R-squared

  -- Model parameters
  changepoint_prior_scale FLOAT64,
  seasonality_prior_scale FLOAT64,
  holidays_prior_scale FLOAT64,
  seasonality_mode STRING,

  -- Additional metadata
  zip_code STRING,             -- NULL for aggregated models
  neighborhood STRING,         -- NULL for aggregated models
  notes STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY trained_date
CLUSTER BY model_name, model_version
OPTIONS(
  description="Model performance metrics for Prophet forecasting models",
  labels=[("layer", "gold"), ("purpose", "model_monitoring")]
);

-- ================================================
-- SUMMARY
-- ================================================
-- Created 4 Gold tables for Prophet forecasting:
-- 1. gold_traffic_forecasts_by_zip (Req 4 & 9)
-- 2. gold_covid_risk_forecasts (Req 1)
-- 3. gold_traffic_forecasts_by_neighborhood (Req 9)
-- 4. gold_forecast_model_metrics (monitoring)
-- ================================================
