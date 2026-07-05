-- NAIVE (WA): the "one big join" attempt. Three compounding errors.
--   1. INNER JOIN to returns drops every category with zero returns.
--   2. Joining returns to order_items fans out oi.quantity: a line with two
--      return rows has its sold quantity counted twice in the denominator.
--   3. SUM(quantity_returned) / SUM(quantity) is INTEGER / INTEGER, which
--      truncates toward zero -- most real rates collapse to 0.
SELECT
    p.category_id,
    c.name AS category_name,
    SUM(oi.quantity)          AS units_sold,
    SUM(r.quantity_returned)  AS units_returned,
    SUM(r.quantity_returned) / SUM(oi.quantity) AS return_rate
FROM order_items oi
JOIN products   p ON p.product_id  = oi.product_id
JOIN categories c ON c.category_id = p.category_id
JOIN returns    r ON r.order_item_id = oi.order_item_id
GROUP BY p.category_id, c.name
ORDER BY return_rate DESC, p.category_id ASC;
