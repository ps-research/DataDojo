-- NAIVE (TLE-only): computes the same correct per-session deepest stage, but with
-- a correlated scalar subquery that rescans the events table once per session
-- instead of a single grouped pass. Over ~2.2M events and hundreds of thousands of
-- sessions this is quadratic and blows the time limit, while the set-based
-- reference stays linear. Output matches the reference on small data; it fails
-- only by timing out at Black scale.
WITH sess AS (
    SELECT DISTINCT session_id, customer_id FROM events
),
depth AS (
    SELECT
        s.session_id,
        s.customer_id,
        (SELECT MAX(CASE e2.event_type
                        WHEN 'view'        THEN 1
                        WHEN 'add_to_cart' THEN 2
                        WHEN 'checkout'    THEN 3
                        WHEN 'purchase'    THEN 4
                        ELSE 0 END)
         FROM events e2
         WHERE e2.session_id = s.session_id) AS deepest
    FROM sess s
)
SELECT
    COALESCE(c.acquisition_channel, 'unknown') AS channel,
    SUM(CASE WHEN d.deepest >= 1 THEN 1 ELSE 0 END) AS view_sessions,
    SUM(CASE WHEN d.deepest >= 2 THEN 1 ELSE 0 END) AS cart_sessions,
    SUM(CASE WHEN d.deepest >= 3 THEN 1 ELSE 0 END) AS checkout_sessions,
    SUM(CASE WHEN d.deepest >= 4 THEN 1 ELSE 0 END) AS purchase_sessions,
    ROUND(1.0 * SUM(CASE WHEN d.deepest >= 2 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN d.deepest >= 1 THEN 1 ELSE 0 END), 0), 4) AS view_to_cart,
    ROUND(1.0 * SUM(CASE WHEN d.deepest >= 3 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN d.deepest >= 2 THEN 1 ELSE 0 END), 0), 4) AS cart_to_checkout,
    ROUND(1.0 * SUM(CASE WHEN d.deepest >= 4 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN d.deepest >= 3 THEN 1 ELSE 0 END), 0), 4) AS checkout_to_purchase
FROM depth d
LEFT JOIN customers c ON c.customer_id = d.customer_id
GROUP BY COALESCE(c.acquisition_channel, 'unknown')
ORDER BY channel ASC;
