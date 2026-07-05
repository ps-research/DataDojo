-- NAIVE (WA): computes the streak as (last active day - first active day + 1),
-- i.e. the calendar SPAN between a driver's first and last active day. Any gap in
-- the middle -- a day off -- is counted as if the driver were active, so the span
-- wildly overstates the true consecutive run. On the visible sample the top
-- driver's span is 37 days versus a real longest streak of 3.
WITH active_days AS (
    SELECT DISTINCT driver_id, SUBSTR(dropoff_ts, 1, 10) AS active_day
    FROM trips
    WHERE status = 'completed' AND driver_id IS NOT NULL
),
best AS (
    SELECT driver_id,
        CAST(julianday(MAX(active_day)) - julianday(MIN(active_day)) AS INTEGER) + 1
            AS longest_streak
    FROM active_days
    GROUP BY driver_id
)
SELECT driver_id, longest_streak
FROM best
WHERE longest_streak = (SELECT MAX(longest_streak) FROM best)
ORDER BY driver_id;
