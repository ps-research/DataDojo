-- Each listener's signature genre: most-played non-NULL genre, alphabetical
-- tiebreak, exactly one row per listener.
-- NULL genre is excluded BEFORE ranking. ROW_NUMBER with a full deterministic
-- ORDER BY (play_count DESC, genre ASC) collapses ties to a single winner.
WITH genre_counts AS (
    SELECT
        p.user_id,
        t.genre,
        COUNT(*) AS play_count
    FROM plays p
    JOIN tracks t ON p.track_id = t.track_id
    WHERE t.genre IS NOT NULL
    GROUP BY p.user_id, t.genre
),
ranked AS (
    SELECT
        user_id,
        genre,
        play_count,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY play_count DESC, genre ASC
        ) AS rn
    FROM genre_counts
)
SELECT
    user_id,
    genre       AS signature_genre,
    play_count
FROM ranked
WHERE rn = 1
ORDER BY user_id;
