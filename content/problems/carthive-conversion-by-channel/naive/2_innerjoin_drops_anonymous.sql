-- NAIVE (WA): counts distinct sessions per stage (so double-fires are handled),
-- but joins events to customers with an INNER JOIN. Anonymous sessions have a
-- NULL customer_id and are dropped entirely, so the 'unknown' bucket loses all
-- anonymous traffic and its cart/purchase counts (and conversion) are wrong.
SELECT
    COALESCE(c.acquisition_channel, 'unknown') AS channel,
    COUNT(DISTINCT CASE WHEN e.event_type = 'add_to_cart' THEN e.session_id END) AS cart_sessions,
    COUNT(DISTINCT CASE WHEN e.event_type = 'purchase'    THEN e.session_id END) AS purchase_sessions,
    ROUND(1.0 * COUNT(DISTINCT CASE WHEN e.event_type = 'purchase' THEN e.session_id END)
          / NULLIF(COUNT(DISTINCT CASE WHEN e.event_type = 'add_to_cart' THEN e.session_id END), 0), 4) AS conversion_rate
FROM events e
JOIN customers c ON c.customer_id = e.customer_id
GROUP BY COALESCE(c.acquisition_channel, 'unknown')
HAVING COUNT(DISTINCT CASE WHEN e.event_type = 'add_to_cart' THEN e.session_id END) > 0
ORDER BY channel ASC;
