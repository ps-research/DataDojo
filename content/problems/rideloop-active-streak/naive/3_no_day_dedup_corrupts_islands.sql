-- NAIVE (WA at scale): runs the correct gaps-and-islands math but WITHOUT
-- deduping to distinct (driver, day) first -- it keys the ROW_NUMBER off raw
-- completed-trip rows. When a driver completes two or more trips on the same
-- calendar day, that day repeats while ROW_NUMBER keeps incrementing, so
-- (day - rownum) drifts and splits a genuine run into pieces (and can also fuse
-- unrelated days). The longest streak is corrupted downward. This coincides with
-- the reference on the tiny visible sample (its max-streak drivers happen to have
-- no doubled days inside their runs) but diverges hard at scale: on the purple
-- fixture the true maximum streak is 250 days while this naive reports 38.
WITH islands AS (
    SELECT driver_id, SUBSTR(dropoff_ts, 1, 10) AS active_day,
        CAST(julianday(SUBSTR(dropoff_ts, 1, 10)) AS INTEGER)
            - ROW_NUMBER() OVER (PARTITION BY driver_id
                                 ORDER BY SUBSTR(dropoff_ts, 1, 10)) AS island_key
    FROM trips
    WHERE status = 'completed' AND driver_id IS NOT NULL
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
)
SELECT driver_id, longest_streak
FROM best
WHERE longest_streak = (SELECT MAX(longest_streak) FROM best)
ORDER BY driver_id;
