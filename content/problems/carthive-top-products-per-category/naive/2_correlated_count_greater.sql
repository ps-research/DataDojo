-- NAIVE (WA + TLE): ranks a product by counting how many products in its
-- category sold strictly more, keeping those with fewer than 3 ahead of them.
-- Two failures:
--   * Correctness: ties are not broken, so a three-way tie at the cutoff lets all
--     tied products through -- more than three rows per category.
--   * Performance: the correlated subquery rescans the per-product aggregate once
--     per product, which is O(n^2) over the catalog and times out at Purple scale
--     (~15k products, ~60k line items) while the windowed reference stays linear.
WITH prod_units AS (
    SELECT p.category_id, oi.product_id, SUM(oi.quantity) AS units_sold
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.category_id, oi.product_id
)
SELECT
    pu.category_id,
    c.name       AS category_name,
    pu.product_id,
    pr.title     AS product_title,
    pu.units_sold,
    (SELECT COUNT(*) FROM prod_units g
      WHERE g.category_id = pu.category_id
        AND g.units_sold  > pu.units_sold) + 1 AS rnk
FROM prod_units pu
JOIN categories c  ON c.category_id = pu.category_id
JOIN products   pr ON pr.product_id = pu.product_id
WHERE (SELECT COUNT(*) FROM prod_units g
        WHERE g.category_id = pu.category_id
          AND g.units_sold  > pu.units_sold) < 3
ORDER BY pu.category_id ASC, rnk ASC, pu.product_id ASC;
