-- IQR Analysis for 8 Time Windows - Rush Hour Dashboard
-- Purpose: Calculate min/max color scale limits for consistent comparison
-- Created: November 20, 2025

-- Calculate Q1, Q3, IQR, and limits for each time window
WITH time_window_data AS (
  SELECT
    zip_code,
    trip_hour,
    day_type,
    -- Assign time windows
    CASE
      WHEN trip_hour >= 5 AND trip_hour < 7 THEN '1. 5 AM - 7 AM (Early Morning)'
      WHEN trip_hour >= 7 AND trip_hour < 9 THEN '2. 7 AM - 9 AM (Morning Rush)'
      WHEN trip_hour >= 11 AND trip_hour < 13 THEN '3. 11 AM - 1 PM (Midday)'
      WHEN trip_hour >= 14 AND trip_hour < 16 THEN '4. 2 PM - 4 PM (Afternoon)'
      WHEN trip_hour >= 16 AND trip_hour < 18 THEN '5. 4 PM - 6 PM (Evening Rush)'
      WHEN trip_hour >= 19 AND trip_hour < 21 THEN '6. 7 PM - 9 PM (Evening)'
      WHEN trip_hour >= 22 OR trip_hour = 0 THEN '7. 10 PM - 12 AM (Late Night)'
      WHEN trip_hour >= 2 AND trip_hour < 4 THEN '8. 2 AM - 4 AM (Overnight)'
      ELSE 'Other'
    END AS time_window,
    SUM(trip_count) AS total_trips
  FROM `chicago-bi-app-msds-432-476520.gold_data.v_rush_hour_by_zip`
  WHERE trip_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND (
      (trip_hour >= 5 AND trip_hour < 7) OR
      (trip_hour >= 7 AND trip_hour < 9) OR
      (trip_hour >= 11 AND trip_hour < 13) OR
      (trip_hour >= 14 AND trip_hour < 16) OR
      (trip_hour >= 16 AND trip_hour < 18) OR
      (trip_hour >= 19 AND trip_hour < 21) OR
      (trip_hour >= 22 OR trip_hour = 0) OR
      (trip_hour >= 2 AND trip_hour < 4)
    )
  GROUP BY zip_code, trip_hour, day_type, time_window
),

quartile_calculations AS (
  SELECT
    time_window,
    COUNT(*) AS data_points,
    MIN(total_trips) AS absolute_min,
    MAX(total_trips) AS absolute_max,
    APPROX_QUANTILES(total_trips, 100)[OFFSET(25)] AS Q1,
    APPROX_QUANTILES(total_trips, 100)[OFFSET(50)] AS median,
    APPROX_QUANTILES(total_trips, 100)[OFFSET(75)] AS Q3,
    APPROX_QUANTILES(total_trips, 100)[OFFSET(75)] -
      APPROX_QUANTILES(total_trips, 100)[OFFSET(25)] AS IQR
  FROM time_window_data
  WHERE time_window != 'Other'
  GROUP BY time_window
)

SELECT
  time_window,
  data_points,
  absolute_min,
  absolute_max,
  Q1,
  median,
  Q3,
  IQR,
  -- Calculate limits (boxplot method)
  GREATEST(0, Q1 - (1.5 * IQR)) AS min_limit_calculated,
  CASE
    WHEN Q1 - (1.5 * IQR) < 0 THEN 0
    ELSE Q1 - (1.5 * IQR)
  END AS min_limit_final,
  Q3 + (1.5 * IQR) AS max_limit_final,
  -- Outlier detection
  ROUND((Q3 + (1.5 * IQR)) / NULLIF(absolute_max, 0) * 100, 1) AS pct_coverage
FROM quartile_calculations
ORDER BY time_window;


-- Summary: Find overall min and max for all maps
WITH time_window_data AS (
  SELECT
    zip_code,
    trip_hour,
    day_type,
    CASE
      WHEN trip_hour >= 5 AND trip_hour < 7 THEN '1. 5 AM - 7 AM'
      WHEN trip_hour >= 7 AND trip_hour < 9 THEN '2. 7 AM - 9 AM'
      WHEN trip_hour >= 11 AND trip_hour < 13 THEN '3. 11 AM - 1 PM'
      WHEN trip_hour >= 14 AND trip_hour < 16 THEN '4. 2 PM - 4 PM'
      WHEN trip_hour >= 16 AND trip_hour < 18 THEN '5. 4 PM - 6 PM'
      WHEN trip_hour >= 19 AND trip_hour < 21 THEN '6. 7 PM - 9 PM'
      WHEN trip_hour >= 22 OR trip_hour = 0 THEN '7. 10 PM - 12 AM'
      WHEN trip_hour >= 2 AND trip_hour < 4 THEN '8. 2 AM - 4 AM'
      ELSE 'Other'
    END AS time_window,
    SUM(trip_count) AS total_trips
  FROM `chicago-bi-app-msds-432-476520.gold_data.v_rush_hour_by_zip`
  WHERE trip_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND (
      (trip_hour >= 5 AND trip_hour < 7) OR
      (trip_hour >= 7 AND trip_hour < 9) OR
      (trip_hour >= 11 AND trip_hour < 13) OR
      (trip_hour >= 14 AND trip_hour < 16) OR
      (trip_hour >= 16 AND trip_hour < 18) OR
      (trip_hour >= 19 AND trip_hour < 21) OR
      (trip_hour >= 22 OR trip_hour = 0) OR
      (trip_hour >= 2 AND trip_hour < 4)
    )
  GROUP BY zip_code, trip_hour, day_type, time_window
),

quartile_calculations AS (
  SELECT
    time_window,
    MAX(total_trips) AS absolute_max,
    APPROX_QUANTILES(total_trips, 100)[OFFSET(25)] AS Q1,
    APPROX_QUANTILES(total_trips, 100)[OFFSET(75)] AS Q3,
    APPROX_QUANTILES(total_trips, 100)[OFFSET(75)] -
      APPROX_QUANTILES(total_trips, 100)[OFFSET(25)] AS IQR
  FROM time_window_data
  WHERE time_window != 'Other'
  GROUP BY time_window
),

limits AS (
  SELECT
    time_window,
    absolute_max,
    Q1,
    Q3,
    IQR,
    GREATEST(0, Q1 - (1.5 * IQR)) AS min_limit,
    Q3 + (1.5 * IQR) AS max_limit
  FROM quartile_calculations
)

-- Final recommended values
SELECT
  '=== RECOMMENDED COLOR SCALE LIMITS ===' AS summary,
  ROUND(MIN(min_limit), 0) AS recommended_min,
  ROUND(MAX(max_limit), 0) AS recommended_max,
  -- Context
  (SELECT time_window FROM limits ORDER BY absolute_max ASC LIMIT 1) AS quietest_period,
  (SELECT time_window FROM limits ORDER BY absolute_max DESC LIMIT 1) AS busiest_period,
  ROUND(MIN(min_limit), 0) || ' to ' || ROUND(MAX(max_limit), 0) AS color_scale_range
FROM limits;


-- Detailed breakdown by time window with weekday/weekend split
WITH time_window_data AS (
  SELECT
    zip_code,
    trip_hour,
    day_type,
    CASE
      WHEN trip_hour >= 5 AND trip_hour < 7 THEN '1. 5 AM - 7 AM'
      WHEN trip_hour >= 7 AND trip_hour < 9 THEN '2. 7 AM - 9 AM'
      WHEN trip_hour >= 11 AND trip_hour < 13 THEN '3. 11 AM - 1 PM'
      WHEN trip_hour >= 14 AND trip_hour < 16 THEN '4. 2 PM - 4 PM'
      WHEN trip_hour >= 16 AND trip_hour < 18 THEN '5. 4 PM - 6 PM'
      WHEN trip_hour >= 19 AND trip_hour < 21 THEN '6. 7 PM - 9 PM'
      WHEN trip_hour >= 22 OR trip_hour = 0 THEN '7. 10 PM - 12 AM'
      WHEN trip_hour >= 2 AND trip_hour < 4 THEN '8. 2 AM - 4 AM'
      ELSE 'Other'
    END AS time_window,
    SUM(trip_count) AS total_trips
  FROM `chicago-bi-app-msds-432-476520.gold_data.v_rush_hour_by_zip`
  WHERE trip_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  GROUP BY zip_code, trip_hour, day_type, time_window
)

SELECT
  time_window,
  day_type,
  COUNT(*) AS data_points,
  MIN(total_trips) AS min_trips,
  MAX(total_trips) AS max_trips,
  ROUND(AVG(total_trips), 0) AS avg_trips,
  APPROX_QUANTILES(total_trips, 100)[OFFSET(25)] AS Q1,
  APPROX_QUANTILES(total_trips, 100)[OFFSET(75)] AS Q3,
  APPROX_QUANTILES(total_trips, 100)[OFFSET(75)] -
    APPROX_QUANTILES(total_trips, 100)[OFFSET(25)] AS IQR
FROM time_window_data
WHERE time_window != 'Other'
GROUP BY time_window, day_type
ORDER BY time_window, day_type;
