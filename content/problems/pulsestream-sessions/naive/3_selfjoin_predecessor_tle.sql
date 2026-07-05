-- NAIVE (TLE, not WA): finds each event's predecessor with a correlated self-join
-- over the same listener's events (the greatest earlier event in (played_at, track_id)
-- order) instead of a single LAG window pass. This is O(n^2) per listener and dies on
-- the multi-million-row hidden fixture. Output matches the reference on small inputs;
-- this is the designated naive-slow for the section-6 TLE calibration.
WITH dedup AS (
    SELECT DISTINCT user_id, track_id, played_at
    FROM plays
),
ordered AS (
    SELECT d.user_id, d.track_id, d.played_at,
           (SELECT d2.played_at
              FROM dedup d2
             WHERE d2.user_id = d.user_id
               AND (d2.played_at < d.played_at
                    OR (d2.played_at = d.played_at AND d2.track_id < d.track_id))
             ORDER BY d2.played_at DESC, d2.track_id DESC
             LIMIT 1) AS prev_ts
    FROM dedup d
),
flagged AS (
    SELECT user_id, track_id, played_at,
           CASE WHEN prev_ts IS NULL
                  OR (unixepoch(played_at) - unixepoch(prev_ts)) > 1800
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
