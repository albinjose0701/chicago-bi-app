-- =====================================================
-- Gold Layer: Top 10 Route Pairs Analysis
-- =====================================================
-- Purpose: Identify and analyze top 10 most popular routes
-- Source: silver_data.silver_trips_enriched
-- Granularity: pickup_zip, dropoff_zip
-- Created: 2025-11-13
-- =====================================================

CREATE TABLE IF NOT EXISTS `chicago-bi-app-msds-432-476520.gold_data.gold_route_pairs`
AS
WITH route_aggregates AS (
  SELECT
    pickup_zip,
    dropoff_zip,
    COUNT(*) as trip_count,
    ROUND(AVG(fare), 2) as avg_fare,
    ROUND(AVG(trip_miles), 2) as avg_miles,
    ROUND(SUM(fare), 2) as total_revenue
  FROM `chicago-bi-app-msds-432-476520.silver_data.silver_trips_enriched`
  WHERE
    pickup_zip IS NOT NULL
    AND dropoff_zip IS NOT NULL
  GROUP BY
    pickup_zip,
    dropoff_zip
),
ranked_routes AS (
  SELECT
    *,
    RANK() OVER (ORDER BY trip_count DESC) as rank
  FROM route_aggregates
)
SELECT
  pickup_zip,
  dropoff_zip,
  trip_count,
  avg_fare,
  avg_miles,
  total_revenue,
  rank,
  CURRENT_TIMESTAMP() as created_at
FROM ranked_routes
WHERE rank <= 10;

-- =====================================================
-- Verification Query
-- =====================================================
-- SELECT
--   COUNT(*) as total_routes,
--   SUM(trip_count) as total_trips,
--   ROUND(AVG(avg_fare), 2) as overall_avg_fare,
--   ROUND(AVG(avg_miles), 2) as overall_avg_miles,
--   ROUND(SUM(total_revenue), 2) as combined_revenue,
--   MIN(rank) as min_rank,
--   MAX(rank) as max_rank
-- FROM `chicago-bi-app-msds-432-476520.gold_data.gold_route_pairs`;
