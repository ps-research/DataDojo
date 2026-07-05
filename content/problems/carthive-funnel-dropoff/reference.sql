-- Sessionized funnel drop-off by acquisition channel.
-- The deepest stage a session reached is the MAX of its events' funnel ranks
-- (view=1, add_to_cart=2, checkout=3, purchase=4). Using MAX over the funnel
-- hierarchy -- never the timestamp order -- means out-of-order sessions (a
-- purchase logged before its checkout) are classified correctly, and duplicate
-- (double-fired) events do not change the max. A session reaches a stage if its
-- deepest rank is at least that stage's rank, so counts are monotonic down the
-- funnel. Channel is the session's customer's channel; anonymous sessions (NULL
-- customer) fold into 'unknown'. NULLIF guards each stage-to-stage divisor.
WITH stage_rank AS (
    SELECT
        e.session_id,
        MAX(CASE e.event_type
                WHEN 'view'        THEN 1
                WHEN 'add_to_cart' THEN 2
                WHEN 'checkout'    THEN 3
                WHEN 'purchase'    THEN 4
                ELSE 0 END)        AS deepest,
        MAX(e.customer_id)         AS customer_id
    FROM events e
    GROUP BY e.session_id
),
sess AS (
    SELECT
        s.session_id,
        s.deepest,
        COALESCE(c.acquisition_channel, 'unknown') AS channel
    FROM stage_rank s
    LEFT JOIN customers c ON c.customer_id = s.customer_id
)
SELECT
    channel,
    SUM(CASE WHEN deepest >= 1 THEN 1 ELSE 0 END) AS view_sessions,
    SUM(CASE WHEN deepest >= 2 THEN 1 ELSE 0 END) AS cart_sessions,
    SUM(CASE WHEN deepest >= 3 THEN 1 ELSE 0 END) AS checkout_sessions,
    SUM(CASE WHEN deepest >= 4 THEN 1 ELSE 0 END) AS purchase_sessions,
    ROUND(1.0 * SUM(CASE WHEN deepest >= 2 THEN 1 ELSE 0 END)
          / NULLIF(SUM(CASE WHEN deepest >= 1 THEN 1 ELSE 0 END), 0), 4) AS view_to_cart,
    ROUND(1.0 * SUM(CASE WHEN deepest >= 3 THEN 1 ELSE 0 END)
          / NULLIF(SUM(CASE WHEN deepest >= 2 THEN 1 ELSE 0 END), 0), 4) AS cart_to_checkout,
    ROUND(1.0 * SUM(CASE WHEN deepest >= 4 THEN 1 ELSE 0 END)
          / NULLIF(SUM(CASE WHEN deepest >= 3 THEN 1 ELSE 0 END), 0), 4) AS checkout_to_purchase
FROM sess
GROUP BY channel
ORDER BY channel ASC;
