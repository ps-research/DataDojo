-- Top 3 best-selling products within each leaf category, by total units sold.
-- Deterministic tie-break: when two products tie on units, the smaller product_id
-- ranks first. ROW_NUMBER (not RANK) assigns 1,2,3 with no duplicates and no
-- skips, so exactly three rows survive per category even when units tie at the
-- cutoff. Products that never sold are absent from order_items and never appear.
WITH prod_units AS (
    SELECT p.category_id, oi.product_id, SUM(oi.quantity) AS units_sold
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.category_id, oi.product_id
),
ranked AS (
    SELECT
        category_id,
        product_id,
        units_sold,
        ROW_NUMBER() OVER (
            PARTITION BY category_id
            ORDER BY units_sold DESC, product_id ASC
        ) AS rnk
    FROM prod_units
)
SELECT
    r.category_id,
    c.name       AS category_name,
    r.product_id,
    pr.title     AS product_title,
    r.units_sold,
    r.rnk
FROM ranked r
JOIN categories c  ON c.category_id = r.category_id
JOIN products   pr ON pr.product_id = r.product_id
WHERE r.rnk <= 3
ORDER BY r.category_id ASC, r.rnk ASC;
