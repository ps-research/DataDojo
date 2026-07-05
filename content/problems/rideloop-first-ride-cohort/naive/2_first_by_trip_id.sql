-- NAIVE (WA): picks the first completed trip by smallest trip_id instead of by
-- earliest request_ts. trip_id is a surrogate key that is NOT monotonic with
-- request time (requests are inserted in time-random order), so for any rider
-- with more than one completed trip the "first" row is often the wrong one, and
-- its request_ts (hence the days gap) differs. On the visible sample this changes
-- the first-completed trip for 20 riders and shifts multiple cohort averages.
WITH first_completed AS (
    SELECT rider_id, request_ts,
        ROW_NUMBER() OVER (PARTITION BY rider_id ORDER BY trip_id) AS rn
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
