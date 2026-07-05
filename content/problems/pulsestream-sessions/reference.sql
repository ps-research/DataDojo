-- Listening-Session Reconstruction (SQLite reference).
--
-- Dedupe exact duplicate events on the natural key (user_id, track_id, played_at),
-- order each listener's events by played_at (with track_id as a stable tiebreak for
-- exact-timestamp ties), and start a NEW session whenever the gap since the previous
-- play exceeds 30 minutes (> 1800 seconds, strictly). Assign session ids with a
-- running SUM of the new-session flag (gaps-and-islands), then aggregate per session
-- and per listener. A session "crosses a day" when its first and last events fall on
-- different calendar dates.
--
-- Timestamp arithmetic is engine-specific: this file uses SQLite's unixepoch();
-- see reference.postgres.sql / reference.duckdb.sql / reference.mysql.sql.
WITH dedup AS (
    SELECT DISTINCT user_id, track_id, played_at
    FROM plays
),
ordered AS (
    SELECT
        user_id, track_id, played_at,
        LAG(played_at) OVER (PARTITION BY user_id ORDER BY played_at, track_id) AS prev_ts
    FROM dedup
),
flagged AS (
    SELECT
        user_id, track_id, played_at,
        CASE
            WHEN prev_ts IS NULL
              OR (unixepoch(played_at) - unixepoch(prev_ts)) > 1800
            THEN 1 ELSE 0
        END AS is_new
    FROM ordered
),
sessioned AS (
    SELECT
        user_id, played_at,
        SUM(is_new) OVER (
            PARTITION BY user_id ORDER BY played_at, track_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS session_seq
    FROM flagged
),
per_session AS (
    SELECT
        user_id, session_seq,
        COUNT(*)                              AS plays_in_session,
        MIN(SUBSTR(CONCAT(played_at, ''), 1, 10)) AS start_day,
        MAX(SUBSTR(CONCAT(played_at, ''), 1, 10)) AS end_day
    FROM sessioned
    GROUP BY user_id, session_seq
)
SELECT
    user_id,
    COUNT(*)                                               AS num_sessions,
    MAX(plays_in_session)                                  AS longest_session_plays,
    SUM(CASE WHEN start_day <> end_day THEN 1 ELSE 0 END)  AS day_crossing_sessions
FROM per_session
GROUP BY user_id
ORDER BY user_id;
