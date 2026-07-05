-- NAIVE (WA): denominator is COUNT(*), which counts NULL-ms_played plays as
-- (non-skip) usable plays. That inflates the denominator and understates every
-- skip rate, and it gates on total plays rather than usable plays.
SELECT
    t.track_id,
    t.title AS track_title,
    COUNT(*) AS qualifying_plays,
    SUM(CASE WHEN p.ms_played < 30000 THEN 1 ELSE 0 END) AS skips,
    ROUND(1.0 * SUM(CASE WHEN p.ms_played < 30000 THEN 1 ELSE 0 END)
              / COUNT(*), 4) AS skip_rate
FROM plays p
JOIN tracks t ON p.track_id = t.track_id
GROUP BY t.track_id, t.title
HAVING COUNT(*) >= 50
ORDER BY skip_rate DESC, qualifying_plays DESC, t.track_id ASC;
