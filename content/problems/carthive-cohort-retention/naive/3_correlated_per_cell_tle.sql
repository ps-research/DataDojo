-- NAIVE (TLE-only): produces the correct retention triangle, but fills each cell
-- with correlated scalar subqueries -- one pass over customers for the cohort size
-- and one pass over the orders join for the active count, per (cohort, offset)
-- cell. Over hundreds of thousands of orders this is quadratic and exceeds the
-- time limit, while the set-based reference computes every cell in a single grouped
-- pass. Output matches the reference on small data; it fails only by timing out at
-- Black scale.
WITH cust_cohort AS (
    SELECT
        customer_id,
        SUBSTR(signup_date, 1, 7) AS cohort_month,
        CAST(SUBSTR(signup_date, 1, 4) AS INTEGER) * 12
          + CAST(SUBSTR(signup_date, 6, 2) AS INTEGER) AS signup_idx
    FROM customers
),
order_offset AS (
    SELECT
        cc.cohort_month,
        (CAST(SUBSTR(o.order_ts, 1, 4) AS INTEGER) * 12
           + CAST(SUBSTR(o.order_ts, 6, 2) AS INTEGER)) - cc.signup_idx AS month_offset,
        o.customer_id
    FROM orders o
    JOIN cust_cohort cc ON cc.customer_id = o.customer_id
),
cells AS (
    SELECT DISTINCT cohort_month, month_offset
    FROM order_offset
    WHERE month_offset >= 0
)
SELECT
    g.cohort_month,
    g.month_offset,
    (SELECT COUNT(*) FROM cust_cohort cc WHERE cc.cohort_month = g.cohort_month) AS cohort_size,
    (SELECT COUNT(DISTINCT oo.customer_id) FROM order_offset oo
       WHERE oo.cohort_month = g.cohort_month AND oo.month_offset = g.month_offset) AS active_customers,
    ROUND(1.0 *
        (SELECT COUNT(DISTINCT oo.customer_id) FROM order_offset oo
           WHERE oo.cohort_month = g.cohort_month AND oo.month_offset = g.month_offset)
        / NULLIF((SELECT COUNT(*) FROM cust_cohort cc WHERE cc.cohort_month = g.cohort_month), 0), 4) AS retention_rate
FROM cells g
ORDER BY g.cohort_month ASC, g.month_offset ASC;
