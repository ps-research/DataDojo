-- NAIVE (WA): uses a >= 30-minute gap test instead of > 30 minutes. A gap of
-- EXACTLY 30 minutes (1800 seconds) is meant to keep the same session, but >= 1800
-- splits it, inflating the session count and shrinking the longest session for every
-- listener who has a play exactly half an hour after the previous one.
WITH dedup AS (
    SELECT DISTINCT user_id, track_id, played_at
    FROM plays
),
ordered AS (
    SELECT user_id, track_id, played_at,
           LAG(played_at) OVER (PARTITION BY user_id ORDER BY played_at, track_id) AS prev_ts
    FROM dedup
),
flagged AS (
    SELECT user_id, track_id, played_at,
           CASE WHEN prev_ts IS NULL
                  OR (unixepoch(played_at) - unixepoch(prev_ts)) >= 1800   -- BUG: >= not >
                THEN 1 ELSE 0 END AS is_new
    FROM ordered
),
sessioned AS (
    SELECT user_id, played_at,
           SUM(is_new) OVER (
               PARTITION BY user_id ORDER BY played_at, track_id
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
