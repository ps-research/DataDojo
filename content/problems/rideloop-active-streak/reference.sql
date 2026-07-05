-- Bk2 - Longest streak of consecutive active days per driver.  (SQLite reference;
-- per-engine island-key variants in reference.postgres/mysql/duckdb.sql.)
--
-- An "active day" is a calendar day on which a driver COMPLETED >= 1 trip, keyed
-- on the completion (dropoff) date. The pipeline:
--   active_days : DISTINCT (driver, day) -- multiple completed trips on one day
--                 collapse to a single active day. Skipping this dedup corrupts
--                 the island key (a repeated day makes ROW_NUMBER outrun the date).
--   islands     : gaps-and-islands. For a run of consecutive days, day - rownum
--                 is constant, so it labels the run. Day arithmetic (julianday),
--                 not day-of-month, so a run survives month ends and 2024-02-29.
--   runs/best   : run length per island, then each driver's longest run.
--   ranked      : RANK() over longest_streak DESC keeps EVERY driver tied at the
--                 maximum (ROW_NUMBER would silently drop the ties).
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
        RANK() OVER (ORDER BY longest_streak DESC) AS rk
    FROM best
)
SELECT driver_id, longest_streak
FROM ranked
WHERE rk = 1
ORDER BY driver_id;
