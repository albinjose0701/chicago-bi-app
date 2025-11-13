#!/bin/bash
#
# Master script to run all Prophet forecasting models
# Requirements: 1, 4, 9
#

set -e

echo "================================================"
echo "RUNNING ALL PROPHET FORECASTING MODELS"
echo "================================================"
echo ""

# Check if Python environment has required packages
echo "[0/3] Checking dependencies..."
if ! python3 -c "import prophet" 2>/dev/null; then
    echo "   ⚠️  Prophet not installed. Installing dependencies..."
    pip3 install -r requirements.txt
else
    echo "   ✅ Dependencies OK"
fi

echo ""
echo "================================================"
echo "[1/3] Traffic Volume Forecasting (Req 4 & 9)"
echo "================================================"
python3 traffic_volume_forecasting.py

echo ""
echo "================================================"
echo "[2/3] COVID-19 Alert Forecasting (Req 1)"
echo "================================================"
python3 covid_alert_forecasting.py

echo ""
echo "================================================"
echo "[3/3] FORECASTING PIPELINE COMPLETE!"
echo "================================================"

echo ""
echo "Next steps:"
echo "  1. View forecasts in BigQuery:"
echo "     - gold_data.gold_traffic_forecasts_by_zip"
echo "     - gold_data.gold_covid_risk_forecasts"
echo "  2. View model metrics:"
echo "     - gold_data.gold_forecast_model_metrics"
echo "  3. Create dashboards in Looker Studio"
echo "  4. Set up weekly refresh via Cloud Scheduler"
echo ""
