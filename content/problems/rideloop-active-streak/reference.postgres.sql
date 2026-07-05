-- Bk2 - PostgreSQL variant. Same gaps-and-islands as reference.sql; the island
-- key uses native date arithmetic (date - integer = date), which is constant
-- along a consecutive run.
WITH active_days AS (
    SELECT DISTINCT driver_id, CAST(dropoff_ts AS DATE) AS active_day
    FROM trips
    WHERE status = 'completed' AND driver_id IS NOT NULL
),
islands AS (
    SELECT driver_id, active_day,
        active_day - CAST(ROW_NUMBER() OVER (PARTITION BY driver_id ORDER BY active_day) AS INTEGER)
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
        RANK() OVER (ORDER BY longest_streak DESC) AS rk
    FROM best
)
SELECT driver_id, longest_streak
FROM ranked
WHERE rk = 1
ORDER BY driver_id;
