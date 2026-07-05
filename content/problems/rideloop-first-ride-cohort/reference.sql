-- P2 - Time-to-first-ride by signup-month cohort.  (SQLite reference; per-engine
-- day-difference variants in reference.postgres.sql / reference.mysql.sql /
-- reference.duckdb.sql.)
--
-- For each rider, the FIRST COMPLETED trip is picked by (request_ts, trip_id):
--   * status='completed' only -- a cancelled/no_driver request is not a ride, so
--     MIN(request_ts) over all rows would count a non-ride as the "first ride".
--   * ORDER BY request_ts THEN trip_id -- request_ts has ties (same rider, same
--     second) at scale, and trip_id is NOT time-ordered, so MIN(trip_id) picks
--     the wrong row. The explicit tiebreak makes "first" deterministic.
-- Riders who never completed a trip never appear (INNER via the window CTE),
-- which is the intended exclusion. Cohort = signup month (a 'YYYY-MM' slice sorts
-- chronologically). avg_days is the mean whole-day gap from signup to that ride.
WITH first_completed AS (
    SELECT rider_id, request_ts,
        ROW_NUMBER() OVER (PARTITION BY rider_id ORDER BY request_ts, trip_id) AS rn
    FROM trips
    WHERE status = 'completed'
)
SELECT
    SUBSTR(r.signup_date, 1, 7) AS signup_cohort,
    COUNT(*) AS riders,
    ROUND(AVG(
        CAST(julianday(SUBSTR(f.request_ts, 1, 10)) AS INTEGER)
        - CAST(julianday(r.signup_date) AS INTEGER)
    ), 2) AS avg_days_to_first_ride
FROM first_completed f
JOIN riders r ON r.rider_id = f.rider_id
WHERE f.rn = 1
GROUP BY SUBSTR(r.signup_date, 1, 7)
ORDER BY signup_cohort;
