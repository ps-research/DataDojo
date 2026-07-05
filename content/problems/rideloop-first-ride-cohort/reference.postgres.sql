-- P2 - PostgreSQL variant. Same logic as reference.sql; the only dialect change
-- is the whole-day gap: (date - date) yields an integer number of days in
-- Postgres. Timestamps/dates are CAST explicitly so the query is agnostic to
-- whether the loader stored them as native temporal types or as text.
WITH first_completed AS (
    SELECT rider_id, request_ts,
        ROW_NUMBER() OVER (PARTITION BY rider_id ORDER BY request_ts, trip_id) AS rn
    FROM trips
    WHERE status = 'completed'
)
SELECT
    TO_CHAR(CAST(r.signup_date AS DATE), 'YYYY-MM') AS signup_cohort,
    COUNT(*) AS riders,
    ROUND(AVG(CAST(f.request_ts AS DATE) - CAST(r.signup_date AS DATE)), 2)
        AS avg_days_to_first_ride
FROM first_completed f
JOIN riders r ON r.rider_id = f.rider_id
WHERE f.rn = 1
GROUP BY TO_CHAR(CAST(r.signup_date AS DATE), 'YYYY-MM')
ORDER BY signup_cohort;
