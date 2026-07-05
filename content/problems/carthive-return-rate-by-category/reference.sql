-- Unit return rate per leaf category = units_returned / units_sold.
-- Sold units and returned units are aggregated on SEPARATE grains, then joined,
-- so the many-returns-per-line fan-out never inflates the sold quantity.
--   * units_sold: sum of quantity over order_items (one row per line).
--   * units_returned: sum of quantity_returned over returns (many rows per line
--     is correct here -- we want every returned unit).
-- A LEFT JOIN keeps categories that sold something but had zero returns.
-- 1.0 * forces real division (quantity is INTEGER); NULLIF guards the divisor.
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
    c.name                                AS category_name,
    s.units_sold,
    COALESCE(rt.units_returned, 0)        AS units_returned,
    ROUND(1.0 * COALESCE(rt.units_returned, 0) / NULLIF(s.units_sold, 0), 4) AS return_rate
FROM sold s
JOIN categories c ON c.category_id = s.category_id
LEFT JOIN returned rt ON rt.category_id = s.category_id
ORDER BY return_rate DESC, s.category_id ASC;
