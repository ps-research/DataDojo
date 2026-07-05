-- NAIVE (WA / runtime error): LEFT JOIN from every track, no >=50 gate.
-- Never-played tracks have 0 plays, so skips / plays divides by zero: a runtime
-- error on Postgres, a NULL rate row on SQLite/MySQL. Either way it disagrees
-- with the reference, and it floods the leaderboard with sub-threshold tracks.
SELECT
    t.track_id,
    t.title AS track_title,
    COUNT(p.play_id) AS qualifying_plays,
    SUM(CASE WHEN p.ms_played < 30000 THEN 1 ELSE 0 END) AS skips,
    ROUND(1.0 * SUM(CASE WHEN p.ms_played < 30000 THEN 1 ELSE 0 END)
              / COUNT(p.play_id), 4) AS skip_rate
FROM tracks t
LEFT JOIN plays p ON p.track_id = t.track_id
GROUP BY t.track_id, t.title
ORDER BY skip_rate DESC, qualifying_plays DESC, t.track_id ASC;
