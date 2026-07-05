-- NAIVE (WA): orders each listener's events by play_id instead of played_at.
-- play_id is ingestion order, which is NOT chronological (offline syncs, retries,
-- backfills), so gaps are computed between events that are not time-adjacent. This
-- invents session boundaries where none exist and merges events that are really far
-- apart -- the session counts and longest-session length come out wrong.
WITH dedup AS (
    SELECT user_id, track_id, played_at, MIN(play_id) AS play_id
    FROM plays
    GROUP BY user_id, track_id, played_at
),
ordered AS (
    SELECT user_id, played_at, play_id,
           LAG(played_at) OVER (PARTITION BY user_id ORDER BY play_id) AS prev_ts
    FROM dedup
),
flagged AS (
    SELECT user_id, played_at, play_id,
           CASE WHEN prev_ts IS NULL
                  OR (unixepoch(played_at) - unixepoch(prev_ts)) > 1800
                THEN 1 ELSE 0 END AS is_new
    FROM ordered
),
sessioned AS (
    SELECT user_id, played_at,
           SUM(is_new) OVER (
               PARTITION BY user_id ORDER BY play_id
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS session_seq
    FROM flagged
),
per_session AS (
    SELECT user_id, session_seq, COUNT(*) AS plays_in_session,
           MIN(SUBSTR(CONCAT(played_at, ''), 1, 10)) AS start_day,
           MAX(SUBSTR(CONCAT(played_at, ''), 1, 10)) AS end_day
    FROM sessioned GROUP BY user_id, session_seq
)
SELECT user_id, COUNT(*) AS num_sessions, MAX(plays_in_session) AS longest_session_plays,
       SUM(CASE WHEN start_day <> end_day THEN 1 ELSE 0 END) AS day_crossing_sessions
FROM per_session GROUP BY user_id ORDER BY user_id;
