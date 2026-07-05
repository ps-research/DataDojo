-- NAIVE (WA): "first ride" = the rider's earliest request of any status.
-- Dropping the status='completed' filter breaks the answer two ways:
--   * a rider whose journey to their first ride began with a cancellation or a
--     no_driver now dates the "first ride" to that earlier failed request, so
--     avg_days_to_first_ride shrinks;
--   * riders who NEVER completed a ride but did request one are now counted,
--     inflating the cohort head-counts.
-- Both the riders column and the averages diverge from the reference.
WITH first_request AS (
    SELECT rider_id, MIN(request_ts) AS first_ts
    FROM trips
    GROUP BY rider_id
)
SELECT
    SUBSTR(r.signup_date, 1, 7) AS signup_cohort,
    COUNT(*) AS riders,
    ROUND(AVG(
        CAST(julianday(SUBSTR(f.first_ts, 1, 10)) AS INTEGER)
        - CAST(julianday(r.signup_date) AS INTEGER)
    ), 2) AS avg_days_to_first_ride
FROM first_request f
JOIN riders r ON r.rider_id = f.rider_id
GROUP BY SUBSTR(r.signup_date, 1, 7)
ORDER BY signup_cohort;
