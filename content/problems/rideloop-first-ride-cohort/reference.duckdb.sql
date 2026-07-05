-- P2 - DuckDB variant. Whole-day gap via DATE_DIFF('day', start, end); month via
-- STRFTIME on the cast date.
WITH first_completed AS (
    SELECT rider_id, request_ts,
        ROW_NUMBER() OVER (PARTITION BY rider_id ORDER BY request_ts, trip_id) AS rn
    FROM trips
    WHERE status = 'completed'
)
SELECT
    STRFTIME(CAST(r.signup_date AS DATE), '%Y-%m') AS signup_cohort,
    COUNT(*) AS riders,
    ROUND(AVG(DATE_DIFF('day', CAST(r.signup_date AS DATE), CAST(f.request_ts AS DATE))), 2)
        AS avg_days_to_first_ride
FROM first_completed f
JOIN riders r ON r.rider_id = f.rider_id
WHERE f.rn = 1
GROUP BY STRFTIME(CAST(r.signup_date AS DATE), '%Y-%m')
ORDER BY signup_cohort;
