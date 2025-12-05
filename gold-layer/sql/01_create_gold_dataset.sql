-- =====================================================
-- Gold Layer Dataset Creation
-- =====================================================
-- Purpose: Create the gold_data dataset for analytics-ready aggregations
-- Location: us-central1 (consistent with bronze and silver layers)
-- Created: 2025-11-13
-- =====================================================

-- Note: This script is for documentation. The dataset is created via bq command.
-- Run: bq mk --dataset --location=us-central1 --description="Gold layer - Analytics-ready aggregations and ML features" chicago-bi-app-msds-432-476520:gold_data
