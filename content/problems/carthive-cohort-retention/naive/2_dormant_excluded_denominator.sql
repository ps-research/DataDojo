-- NAIVE (WA): builds cohort_size from the customers who actually ordered, instead
-- of everyone who signed up. Dormant customers (signed up, never ordered) vanish
-- from the denominator, so every retention rate is overstated. Cohort size is the
-- count of signups in the month, dormant customers included.
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
cohort_size AS (
    -- WRONG: only customers who placed an order, so dormant signups are missing.
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size
    FROM order_offset
    GROUP BY cohort_month
),
active AS (
    SELECT cohort_month, month_offset, COUNT(DISTINCT customer_id) AS active_customers
    FROM order_offset
    WHERE month_offset >= 0
    GROUP BY cohort_month, month_offset
)
SELECT
    a.cohort_month, a.month_offset, cs.cohort_size, a.active_customers,
    ROUND(1.0 * a.active_customers / NULLIF(cs.cohort_size, 0), 4) AS retention_rate
FROM active a
JOIN cohort_size cs ON cs.cohort_month = a.cohort_month
ORDER BY a.cohort_month ASC, a.month_offset ASC;
