-- NAIVE (WA): treats the first month's growth as 0 instead of undefined.
-- COALESCE(..., 0) turns the earliest month's NULL growth into 0.00, which
-- disagrees with the reference on the very first row.
WITH monthly AS (
    SELECT
        SUBSTR(played_at, 1, 7) AS month,
        COUNT(DISTINCT user_id) AS active_listeners
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
    COALESCE(ROUND(100.0 * (active_listeners - prev_active) / prev_active, 2), 0) AS mom_growth_pct
FROM with_prev
ORDER BY month;
