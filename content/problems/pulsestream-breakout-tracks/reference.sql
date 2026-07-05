-- Breakout Tracks of the Month (December 2024).
-- Count every play in the month, join to human-readable title + artist, and
-- rank with a fully deterministic tiebreak so the 10th/11th boundary is unique.
SELECT
    t.track_id                         AS track_id,
    t.title                            AS track_title,
    a.name                             AS artist_name,
    COUNT(*)                           AS play_count
FROM plays p
JOIN tracks  t ON p.track_id  = t.track_id
JOIN artists a ON t.artist_id = a.artist_id
WHERE p.played_at >= '2024-12-01'
  AND p.played_at <  '2025-01-01'
GROUP BY t.track_id, t.title, a.name
ORDER BY play_count DESC, track_title ASC, track_id ASC
LIMIT 10;
