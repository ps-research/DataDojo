-- Cohort retention grid. Each customer belongs to the cohort of their signup
-- month. For each cohort and each month-offset m, the retention rate is the
-- fraction of the cohort's customers who placed at least one order in the m-th
-- month after signup.
--
-- Month offset is computed as (year*12 + month) arithmetic on both dates, which
-- is correct across month ends, the leap day, and the year boundary -- unlike a
-- day-difference / 30 approximation or a month-number-only difference.
--
-- cohort_size counts ALL signups in the month (dormant customers included), so
-- they sit in the denominator and are never retained. The numerator is
-- COUNT(DISTINCT customer_id): a customer who orders several times in one month is
-- retained once. Guest orders (NULL customer_id) do not join to a cohort and are
-- excluded. Only cohort/offset cells with at least one active customer are emitted.
WITH cust_cohort AS (
    SELECT
        customer_id,
        SUBSTR(signup_date, 1, 7) AS cohort_month,
        CAST(SUBSTR(signup_date, 1, 4) AS INTEGER) * 12
          + CAST(SUBSTR(signup_date, 6, 2) AS INTEGER) AS signup_idx
    FROM customers
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM cust_cohort
    GROUP BY cohort_month
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
active AS (
    SELECT cohort_month, month_offset, COUNT(DISTINCT customer_id) AS active_customers
    FROM order_offset
    WHERE month_offset >= 0
    GROUP BY cohort_month, month_offset
)
SELECT
    a.cohort_month,
    a.month_offset,
    cs.cohort_size,
    a.active_customers,
    ROUND(1.0 * a.active_customers / NULLIF(cs.cohort_size, 0), 4) AS retention_rate
FROM active a
JOIN cohort_size cs ON cs.cohort_month = a.cohort_month
ORDER BY a.cohort_month ASC, a.month_offset ASC;
