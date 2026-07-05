-- Order volume per calendar month across the whole history.
-- Count order rows directly: guest checkouts (customer_id IS NULL) are still
-- orders and must count. The month key carries the year, so 2022-01 and 2023-01
-- stay distinct, and a 'YYYY-MM' string sorts chronologically.
SELECT
    SUBSTR(order_ts, 1, 7) AS order_month,
    COUNT(*)               AS order_count
FROM orders
GROUP BY SUBSTR(order_ts, 1, 7)
ORDER BY order_month ASC;
