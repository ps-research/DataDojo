-- NAIVE (WA): computes the month offset from the month number alone, ignoring the
-- year. An order in the same calendar month of a later year collapses to a small
-- offset (Jan 2023 against a Jan 2022 signup becomes offset 0, colliding with the
-- signup month), and a December-to-January step goes negative instead of +1. The
-- offset must be full (year*12 + month) arithmetic on both dates.
WITH cust_cohort AS (
    SELECT
        customer_id,
        SUBSTR(signup_date, 1, 7) AS cohort_month,
        CAST(SUBSTR(signup_date, 6, 2) AS INTEGER) AS signup_month
    FROM customers
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS cohort_size FROM cust_cohort GROUP BY cohort_month
),
order_offset AS (
    SELECT
        cc.cohort_month,
        CAST(SUBSTR(o.order_ts, 6, 2) AS INTEGER) - cc.signup_month AS month_offset,
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
    a.cohort_month, a.month_offset, cs.cohort_size, a.active_customers,
    ROUND(1.0 * a.active_customers / NULLIF(cs.cohort_size, 0), 4) AS retention_rate
FROM active a
JOIN cohort_size cs ON cs.cohort_month = a.cohort_month
ORDER BY a.cohort_month ASC, a.month_offset ASC;
