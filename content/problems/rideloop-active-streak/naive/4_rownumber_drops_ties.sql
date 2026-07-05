-- NAIVE (WA): identical to the reference except it ranks the leaderboard with
-- ROW_NUMBER() instead of RANK(). ROW_NUMBER assigns 1 to exactly one of the
-- drivers tied at the maximum streak and >1 to the rest, so the WHERE rk = 1
-- filter keeps a single (arbitrary) driver and silently drops the others tied at
-- the top. On the visible sample it returns only driver 1, hiding drivers 7 and 9
-- who share the same longest streak of 3.
WITH active_days AS (
    SELECT DISTINCT driver_id, SUBSTR(dropoff_ts, 1, 10) AS active_day
    FROM trips
    WHERE status = 'completed' AND driver_id IS NOT NULL
),
islands AS (
    SELECT driver_id, active_day,
        CAST(julianday(active_day) AS INTEGER)
            - ROW_NUMBER() OVER (PARTITION BY driver_id ORDER BY active_day)
            AS island_key
    FROM active_days
),
runs AS (
    SELECT driver_id, island_key, COUNT(*) AS run_len
    FROM islands
    GROUP BY driver_id, island_key
),
best AS (
    SELECT driver_id, MAX(run_len) AS longest_streak
    FROM runs
    GROUP BY driver_id
),
ranked AS (
    SELECT driver_id, longest_streak,
        ROW_NUMBER() OVER (ORDER BY longest_streak DESC) AS rk
    FROM best
)
SELECT driver_id, longest_streak
FROM ranked
WHERE rk = 1
ORDER BY driver_id;
