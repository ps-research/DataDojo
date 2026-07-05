-- NAIVE (WA): RANK() = 1 returns EVERY genre tied for a listener's top count.
-- Listeners whose top two genres tie (e.g. classical vs electronic at 2 plays)
-- get two rows instead of one, violating the one-signature-per-listener contract.
WITH genre_counts AS (
    SELECT p.user_id, t.genre, COUNT(*) AS play_count
    FROM plays p
    JOIN tracks t ON p.track_id = t.track_id
    WHERE t.genre IS NOT NULL
    GROUP BY p.user_id, t.genre
),
ranked AS (
    SELECT user_id, genre, play_count,
           RANK() OVER (PARTITION BY user_id ORDER BY play_count DESC) AS rnk
    FROM genre_counts
)
SELECT user_id, genre AS signature_genre, play_count
FROM ranked
WHERE rnk = 1
ORDER BY user_id;
