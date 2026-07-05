-- NAIVE (WA): reports COUNT(DISTINCT active_day) as the "streak". That is the
-- driver's TOTAL number of active days, not the longest run of CONSECUTIVE ones.
-- A driver who is active every Saturday for months scores huge here but has a
-- real streak of 1. On the visible sample this returns a single driver (id 1)
-- with 14, instead of the three drivers tied at a true streak of 3.
WITH active_days AS (
    SELECT DISTINCT driver_id, SUBSTR(dropoff_ts, 1, 10) AS active_day
    FROM trips
    WHERE status = 'completed' AND driver_id IS NOT NULL
),
best AS (
    SELECT driver_id, COUNT(*) AS longest_streak
    FROM active_days
    GROUP BY driver_id
)
SELECT driver_id, longest_streak
FROM best
WHERE longest_streak = (SELECT MAX(longest_streak) FROM best)
ORDER BY driver_id;
