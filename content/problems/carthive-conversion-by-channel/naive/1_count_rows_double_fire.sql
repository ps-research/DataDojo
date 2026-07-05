-- NAIVE (WA): counts event ROWS per stage instead of distinct sessions.
-- Analytics double-fires the add_to_cart event, so a single session can
-- contribute two add_to_cart rows. That inflates the denominator and drives
-- every affected channel's conversion rate below its true value.
SELECT
    COALESCE(c.acquisition_channel, 'unknown') AS channel,
    SUM(CASE WHEN e.event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS cart_sessions,
    SUM(CASE WHEN e.event_type = 'purchase'    THEN 1 ELSE 0 END) AS purchase_sessions,
    ROUND(1.0 * SUM(CASE WHEN e.event_type = 'purchase' THEN 1 ELSE 0 END)
          / NULLIF(SUM(CASE WHEN e.event_type = 'add_to_cart' THEN 1 ELSE 0 END), 0), 4) AS conversion_rate
FROM events e
LEFT JOIN customers c ON c.customer_id = e.customer_id
GROUP BY COALESCE(c.acquisition_channel, 'unknown')
HAVING SUM(CASE WHEN e.event_type = 'add_to_cart' THEN 1 ELSE 0 END) > 0
ORDER BY channel ASC;
