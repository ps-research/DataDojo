-- NAIVE (WA): uses RANK() with no tie-break and filters rank <= 3.
-- When several products tie on units, RANK gives them all the same rank, so a
-- three-way tie at the cutoff returns more than three rows (and assigns duplicate
-- rank values). The task wants exactly three products per category with a
-- deterministic tie-break; RANK delivers neither.
WITH prod_units AS (
    SELECT p.category_id, oi.product_id, SUM(oi.quantity) AS units_sold
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.category_id, oi.product_id
),
ranked AS (
    SELECT
        category_id, product_id, units_sold,
        RANK() OVER (PARTITION BY category_id ORDER BY units_sold DESC) AS rnk
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
ORDER BY r.category_id ASC, r.rnk ASC, r.product_id ASC;
