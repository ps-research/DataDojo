-- Monthly active listeners and month-over-month growth.
-- Bucket by the month of played_at (string slice of the ISO timestamp), count
-- DISTINCT listeners (so duplicate events and repeat listens do not inflate it),
-- then use LAG for the prior month with a NULL/zero guard on the first month.
WITH monthly AS (
    SELECT
        SUBSTR(played_at, 1, 7)   AS month,
        COUNT(DISTINCT user_id)   AS active_listeners
    FROM plays
    GROUP BY SUBSTR(played_at, 1, 7)
),
with_prev AS (
    SELECT
        month,
        active_listeners,
        LAG(active_listeners) OVER (ORDER BY month) AS prev_active
    FROM monthly
)
SELECT
    month,
    active_listeners,
    CASE
        WHEN prev_active IS NULL OR prev_active = 0 THEN NULL
        ELSE ROUND(100.0 * (active_listeners - prev_active) / prev_active, 2)
    END AS mom_growth_pct
FROM with_prev
ORDER BY month;
