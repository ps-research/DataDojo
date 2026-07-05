-- Track skip-rate leaderboard.
-- A skip is ms_played < 30000 (30 seconds in MILLISECONDS). NULL ms_played is
-- excluded from both numerator and denominator via the WHERE filter, so the
-- ratio is well defined. HAVING COUNT(*) >= 50 gates the ratio, which also means
-- never-played (and barely-played) tracks never reach a division.
SELECT
    t.track_id                                                       AS track_id,
    t.title                                                          AS track_title,
    COUNT(*)                                                         AS qualifying_plays,
    SUM(CASE WHEN p.ms_played < 30000 THEN 1 ELSE 0 END)             AS skips,
    ROUND(1.0 * SUM(CASE WHEN p.ms_played < 30000 THEN 1 ELSE 0 END)
              / COUNT(*), 4)                                         AS skip_rate
FROM plays p
JOIN tracks t ON p.track_id = t.track_id
WHERE p.ms_played IS NOT NULL
GROUP BY t.track_id, t.title
HAVING COUNT(*) >= 50
ORDER BY skip_rate DESC, qualifying_plays DESC, t.track_id ASC;
