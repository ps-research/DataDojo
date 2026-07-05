-- NAIVE (WA): treats the 30-second threshold as 30, forgetting ms_played is in
-- milliseconds. Almost no play is under 30 ms, so nearly every track scores a
-- skip_rate of 0.0 and the leaderboard is meaningless.
SELECT
    t.track_id,
    t.title AS track_title,
    COUNT(*) AS qualifying_plays,
    SUM(CASE WHEN p.ms_played < 30 THEN 1 ELSE 0 END) AS skips,
    ROUND(1.0 * SUM(CASE WHEN p.ms_played < 30 THEN 1 ELSE 0 END)
              / COUNT(*), 4) AS skip_rate
FROM plays p
JOIN tracks t ON p.track_id = t.track_id
WHERE p.ms_played IS NOT NULL
GROUP BY t.track_id, t.title
HAVING COUNT(*) >= 50
ORDER BY skip_rate DESC, qualifying_plays DESC, t.track_id ASC;
