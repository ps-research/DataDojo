-- Cart-to-purchase conversion by acquisition channel.
-- Conversion = distinct sessions that reached purchase
--             / distinct sessions that reached add_to_cart.
-- Work at the session grain first: a per-session flag for each stage collapses
-- double-fired (duplicate) events, so a session that fired add_to_cart twice
-- still counts once. Channel comes from the session's customer; anonymous
-- sessions (NULL customer) and customers with a NULL channel both fall into a
-- single 'unknown' bucket via COALESCE. A LEFT JOIN keeps anonymous traffic.
WITH per_session AS (
    SELECT
        e.session_id,
        COALESCE(c.acquisition_channel, 'unknown') AS channel,
        MAX(CASE WHEN e.event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS reached_cart,
        MAX(CASE WHEN e.event_type = 'purchase'    THEN 1 ELSE 0 END) AS reached_purchase
    FROM events e
    LEFT JOIN customers c ON c.customer_id = e.customer_id
    GROUP BY e.session_id, COALESCE(c.acquisition_channel, 'unknown')
)
SELECT
    channel,
    SUM(reached_cart)     AS cart_sessions,
    SUM(reached_purchase) AS purchase_sessions,
    ROUND(1.0 * SUM(reached_purchase) / NULLIF(SUM(reached_cart), 0), 4) AS conversion_rate
FROM per_session
GROUP BY channel
HAVING SUM(reached_cart) > 0
ORDER BY channel ASC;
