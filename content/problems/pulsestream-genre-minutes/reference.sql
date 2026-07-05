-- Listening minutes by genre across the whole catalog.
-- ms_played is milliseconds: minutes = ms / 60000. SUM ignores NULL ms_played.
-- NULL genre collapses into one labelled bucket via COALESCE (rows never dropped).
SELECT
    COALESCE(t.genre, '(uncategorized)')             AS genre,
    COALESCE(SUM(p.ms_played), 0)                    AS total_ms,
    ROUND(COALESCE(SUM(p.ms_played), 0) / 60000.0, 2) AS total_minutes
FROM plays p
JOIN tracks t ON p.track_id = t.track_id
GROUP BY COALESCE(t.genre, '(uncategorized)')
ORDER BY total_ms DESC, genre ASC;
