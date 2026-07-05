-- NAIVE (WA): "the genre whose count equals the listener's max count".
-- With no alphabetical tiebreak this correlated-MAX filter returns multiple rows
-- for every listener whose top genres tie, exactly like RANK() = 1.
WITH genre_counts AS (
    SELECT p.user_id, t.genre, COUNT(*) AS play_count
    FROM plays p
    JOIN tracks t ON p.track_id = t.track_id
    WHERE t.genre IS NOT NULL
    GROUP BY p.user_id, t.genre
)
SELECT gc.user_id, gc.genre AS signature_genre, gc.play_count
FROM genre_counts gc
WHERE gc.play_count = (
    SELECT MAX(gc2.play_count)
    FROM genre_counts gc2
    WHERE gc2.user_id = gc.user_id
)
ORDER BY gc.user_id;
