-- NAIVE (WA): counts plays, not distinct listeners.
-- Duplicate retry events and repeat listens by the same person inflate every
-- month's "active listener" number, and every growth rate derived from it.
WITH monthly AS (
    SELECT
        SUBSTR(played_at, 1, 7) AS month,
        COUNT(*)                AS active_listeners
    FROM plays
    GROUP BY SUBSTR(played_at, 1, 7)
),
with_prev AS (
    SELECT month, active_listeners,
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
