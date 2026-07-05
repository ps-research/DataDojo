-- GMV (gross merchandise value) by leaf category, top 10.
-- GMV of a line = quantity * unit_price; a category's GMV sums every line that
-- sold a product in that category. Duplicate lines are legitimate sales and
-- count. Departments hold no products directly, so they never appear here --
-- product -> category is always a leaf join.
SELECT
    c.category_id,
    c.name                                    AS category_name,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS gmv
FROM order_items oi
JOIN products   p ON p.product_id  = oi.product_id
JOIN categories c ON c.category_id = p.category_id
GROUP BY c.category_id, c.name
ORDER BY gmv DESC, c.category_id ASC
LIMIT 10;
