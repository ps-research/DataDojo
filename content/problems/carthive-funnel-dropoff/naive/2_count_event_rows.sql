-- NAIVE (WA): counts event ROWS per stage instead of distinct sessions reaching
-- the stage. Double-fired (duplicate) events inflate the stage counts -- a session
-- that logs its view twice contributes two views -- so the funnel widths and every
-- conversion ratio are wrong. The metric is sessions, computed at the session grain.
SELECT
    COALESCE(c.acquisition_channel, 'unknown') AS channel,
    SUM(CASE WHEN e.event_type = 'view'        THEN 1 ELSE 0 END) AS view_sessions,
    SUM(CASE WHEN e.event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS cart_sessions,
    SUM(CASE WHEN e.event_type = 'checkout'    THEN 1 ELSE 0 END) AS checkout_sessions,
    SUM(CASE WHEN e.event_type = 'purchase'    THEN 1 ELSE 0 END) AS purchase_sessions,
    ROUND(1.0 * SUM(CASE WHEN e.event_type = 'add_to_cart' THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN e.event_type = 'view'        THEN 1 ELSE 0 END), 0), 4) AS view_to_cart,
    ROUND(1.0 * SUM(CASE WHEN e.event_type = 'checkout'    THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN e.event_type = 'add_to_cart' THEN 1 ELSE 0 END), 0), 4) AS cart_to_checkout,
    ROUND(1.0 * SUM(CASE WHEN e.event_type = 'purchase'    THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN e.event_type = 'checkout'    THEN 1 ELSE 0 END), 0), 4) AS checkout_to_purchase
FROM events e
LEFT JOIN customers c ON c.customer_id = e.customer_id
GROUP BY COALESCE(c.acquisition_channel, 'unknown')
ORDER BY channel ASC;
