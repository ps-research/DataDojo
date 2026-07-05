-- NAIVE (WA): aggregates sold and returned on separate grains (so no fan-out)
-- and divides in real arithmetic (so no integer truncation) -- but joins the two
-- with an INNER JOIN. Every category that sold something yet had zero returns
-- disappears, when it should appear with a return_rate of 0. Missing rows.
WITH sold AS (
    SELECT p.category_id, SUM(oi.quantity) AS units_sold
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.category_id
),
returned AS (
    SELECT p.category_id, SUM(r.quantity_returned) AS units_returned
    FROM returns r
    JOIN order_items oi ON oi.order_item_id = r.order_item_id
    JOIN products    p  ON p.product_id     = oi.product_id
    GROUP BY p.category_id
)
SELECT
    s.category_id,
    c.name AS category_name,
    s.units_sold,
    rt.units_returned,
    ROUND(1.0 * rt.units_returned / NULLIF(s.units_sold, 0), 4) AS return_rate
FROM sold s
JOIN categories c  ON c.category_id = s.category_id
JOIN returned rt   ON rt.category_id = s.category_id
ORDER BY return_rate DESC, s.category_id ASC;
