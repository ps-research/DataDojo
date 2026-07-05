-- NAIVE (WA): sessionizes the raw firehose without deduplicating retry events.
-- A client retry logs the same (user_id, track_id, played_at) twice with a new
-- play_id; both rows land in the same session (zero-minute gap) and inflate the
-- session's play count, so the longest-session length (and any per-session count)
-- is overstated for every listener who has a duplicated event.
WITH ordered AS (
    SELECT user_id, track_id, played_at, play_id,
           LAG(played_at) OVER (
               PARTITION BY user_id ORDER BY played_at, track_id, play_id
           ) AS prev_ts
    FROM plays
),
flagged AS (
    SELECT user_id, track_id, played_at, play_id,
           CASE WHEN prev_ts IS NULL
                  OR (unixepoch(played_at) - unixepoch(prev_ts)) > 1800
                THEN 1 ELSE 0 END AS is_new
    FROM ordered
),
sessioned AS (
    SELECT user_id, played_at,
           SUM(is_new) OVER (
               PARTITION BY user_id ORDER BY played_at, track_id, play_id
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
