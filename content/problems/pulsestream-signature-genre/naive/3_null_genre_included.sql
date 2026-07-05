-- NAIVE (WA): keeps NULL-genre plays and ranks them as an '(uncategorized)'
-- bucket. For listeners whose most-played bucket is uncategorized, the signature
-- comes back as '(uncategorized)' (and, since '(' sorts before letters, it even
-- wins ties), which the reference never emits. It also invents rows for
-- listeners who should have been excluded for having only uncategorized plays.
WITH genre_counts AS (
    SELECT p.user_id, COALESCE(t.genre, '(uncategorized)') AS genre, COUNT(*) AS play_count
    FROM plays p
    JOIN tracks t ON p.track_id = t.track_id
    GROUP BY p.user_id, COALESCE(t.genre, '(uncategorized)')
),
ranked AS (
    SELECT user_id, genre, play_count,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY play_count DESC, genre ASC) AS rn
    FROM genre_counts
)
SELECT user_id, genre AS signature_genre, play_count
FROM ranked
WHERE rn = 1
ORDER BY user_id;
