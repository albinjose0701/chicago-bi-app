-- Create views for Dashboard 2: Airport Traffic Analysis
-- Created: November 20, 2025

-- View 1: Airport trips with proper identification
CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.gold_data.v_airport_trips` AS
SELECT
  trip_id,
  trip_date,
  trip_hour,
  trip_start_timestamp,
  trip_end_timestamp,
  trip_miles,
  fare,
  pickup_community_area,
  pickup_zip,
  pickup_neighborhood,
  dropoff_community_area,
  dropoff_zip,
  dropoff_neighborhood,
  shared_trip_authorized,
  trips_pooled,

  -- Identify airport destination
  CASE
    WHEN dropoff_community_area = 76 OR dropoff_zip = '60666' THEN 'O''Hare'
    WHEN dropoff_community_area = 56 AND dropoff_zip = '60638' THEN 'Midway'
    ELSE 'Other'
  END AS airport_destination,

  -- Flag for filtering
  CASE
    WHEN dropoff_community_area IN (76, 56) OR dropoff_zip IN ('60666', '60638') THEN true
    ELSE false
  END AS is_airport_trip,

  -- Calculate week for COVID overlay
  DATE_TRUNC(trip_date, WEEK(MONDAY)) AS week_start,
  DATE_TRUNC(trip_date, MONTH) AS month_start

FROM `chicago-bi-app-msds-432-476520.silver_data.silver_trips_enriched`
WHERE dropoff_community_area IN (76, 56)
   OR dropoff_zip IN ('60666', '60638');


-- View 2: Airport traffic with COVID overlay (for Viz 4)
CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.gold_data.v_airport_covid_overlay` AS
WITH airport_weekly AS (
  SELECT
    DATE_TRUNC(trip_date, WEEK(MONDAY)) AS week_start,
    airport_destination,
    COUNT(*) AS airport_trips,
    AVG(fare) AS avg_fare,
    AVG(trip_miles) AS avg_miles
  FROM `chicago-bi-app-msds-432-476520.gold_data.v_airport_trips`
  GROUP BY week_start, airport_destination
),
covid_weekly AS (
  SELECT
    week_start,
    SUM(cases_weekly) AS total_covid_cases,
    AVG(adjusted_risk_score) AS avg_risk_score
  FROM `chicago-bi-app-msds-432-476520.gold_data.gold_covid_hotspots`
  GROUP BY week_start
)
SELECT
  a.week_start,
  a.airport_destination,
  a.airport_trips,
  a.avg_fare,
  a.avg_miles,
  COALESCE(c.total_covid_cases, 0) AS total_covid_cases,
  COALESCE(c.avg_risk_score, 0) AS avg_risk_score
FROM airport_weekly a
LEFT JOIN covid_weekly c
  ON a.week_start = c.week_start
ORDER BY a.week_start, a.airport_destination;


-- View 3: Hourly patterns for Viz 5
CREATE OR REPLACE VIEW `chicago-bi-app-msds-432-476520.gold_data.v_airport_hourly_patterns` AS
SELECT
  trip_hour,
  airport_destination,
  COUNT(*) AS trip_count,
  AVG(fare) AS avg_fare,
  AVG(trip_miles) AS avg_miles
FROM `chicago-bi-app-msds-432-476520.gold_data.v_airport_trips`
WHERE trip_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY trip_hour, airport_destination
ORDER BY trip_hour, airport_destination;


-- Verification queries
-- Count trips by airport
SELECT
  airport_destination,
  COUNT(*) AS total_trips,
  MIN(trip_date) AS first_trip,
  MAX(trip_date) AS last_trip
FROM `chicago-bi-app-msds-432-476520.gold_data.v_airport_trips`
GROUP BY airport_destination
ORDER BY total_trips DESC;
