-- NAIVE (WA): takes each session's LAST event by timestamp as its outcome, then
-- treats that stage as the deepest reached. Because some sessions log events out
-- of funnel order (a purchase timestamped before its checkout), the last-by-time
-- event is not the deepest stage -- an inverted purchasing session is misread as
-- ending at checkout, so purchases are undercounted. The funnel depth must come
-- from the stage hierarchy (MAX over ranks), not the clock.
WITH ranked AS (
    SELECT
        e.session_id,
        e.customer_id,
        e.event_type,
        ROW_NUMBER() OVER (
            PARTITION BY e.session_id
            ORDER BY e.event_ts DESC, e.event_id DESC
        ) AS rn
    FROM events e
),
sess AS (
    SELECT
        r.session_id,
        CASE r.event_type
            WHEN 'view' THEN 1 WHEN 'add_to_cart' THEN 2
            WHEN 'checkout' THEN 3 WHEN 'purchase' THEN 4 ELSE 0 END AS deepest,
        COALESCE(c.acquisition_channel, 'unknown') AS channel
    FROM ranked r
    LEFT JOIN customers c ON c.customer_id = r.customer_id
    WHERE r.rn = 1
)
SELECT
    channel,
    SUM(CASE WHEN deepest >= 1 THEN 1 ELSE 0 END) AS view_sessions,
    SUM(CASE WHEN deepest >= 2 THEN 1 ELSE 0 END) AS cart_sessions,
    SUM(CASE WHEN deepest >= 3 THEN 1 ELSE 0 END) AS checkout_sessions,
    SUM(CASE WHEN deepest >= 4 THEN 1 ELSE 0 END) AS purchase_sessions,
    ROUND(1.0 * SUM(CASE WHEN deepest >= 2 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN deepest >= 1 THEN 1 ELSE 0 END), 0), 4) AS view_to_cart,
    ROUND(1.0 * SUM(CASE WHEN deepest >= 3 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN deepest >= 2 THEN 1 ELSE 0 END), 0), 4) AS cart_to_checkout,
    ROUND(1.0 * SUM(CASE WHEN deepest >= 4 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN deepest >= 3 THEN 1 ELSE 0 END), 0), 4) AS checkout_to_purchase
FROM sess
GROUP BY channel
ORDER BY channel ASC;
