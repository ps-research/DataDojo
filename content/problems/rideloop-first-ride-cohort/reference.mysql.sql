-- P2 - MySQL variant. Whole-day gap via DATEDIFF(end, start); month via
-- DATE_FORMAT. Requires MySQL 8.0+ (window functions).
WITH first_completed AS (
    SELECT rider_id, request_ts,
        ROW_NUMBER() OVER (PARTITION BY rider_id ORDER BY request_ts, trip_id) AS rn
    FROM trips
    WHERE status = 'completed'
)
SELECT
    DATE_FORMAT(r.signup_date, '%Y-%m') AS signup_cohort,
    COUNT(*) AS riders,
    ROUND(AVG(DATEDIFF(CAST(f.request_ts AS DATE), CAST(r.signup_date AS DATE))), 2)
        AS avg_days_to_first_ride
FROM first_completed f
JOIN riders r ON r.rider_id = f.rider_id
WHERE f.rn = 1
GROUP BY DATE_FORMAT(r.signup_date, '%Y-%m')
ORDER BY signup_cohort;
