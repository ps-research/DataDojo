# Cohort Retention Grid

Group customers into **cohorts** by their signup month. For each cohort and each
month-offset `m = 0, 1, 2, ...`, compute the fraction of that cohort's customers who
placed at least one order in the `m`-th month after signup. The result is the
retention triangle.

The month-offset arithmetic and the denominator are where this goes wrong:

- **Offset is `(year*12 + month)` arithmetic, on both dates.** Approximating the
  offset as `days_between / 30` drifts across long months and the leap day; using
  the month **number** alone (ignoring the year) collapses the same calendar month
  of different years onto the same offset and turns a December-to-January step
  negative. Compute
  `(order_year*12 + order_month) - (signup_year*12 + signup_month)`.
- **The cohort denominator is every signup, including the dormant.** Roughly a tenth
  of customers sign up and never order. They stay in the cohort's denominator (they
  are simply never retained). Counting only customers who ordered inflates every
  rate.
- **The numerator is distinct customers, not orders.** A customer who orders three
  times in one month is retained once. `COUNT(DISTINCT customer_id)`, never
  `COUNT(*)`.
- **Guest orders have no cohort.** Orders with `customer_id IS NULL` do not belong to
  any cohort and are excluded (an inner join to the cohort table drops them).

Emit only cells where at least one customer was active (the populated triangle).

## Task

Assign each customer to their signup-month cohort, compute the month offset of each
of their orders, and for each `(cohort_month, month_offset)` report the cohort size,
the number of distinct active customers, and the retention rate.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `cohort_month` | signup month as `'YYYY-MM'` |
| 2 | `month_offset` | whole months since signup (0 = signup month) |
| 3 | `cohort_size` | customers who signed up that month (dormant included) |
| 4 | `active_customers` | distinct cohort customers who ordered at this offset |
| 5 | `retention_rate` | `active_customers / cohort_size`, real division, rounded to 4 decimals |

**Order matters.** `ORDER BY cohort_month ASC, month_offset ASC`.

## Worked example

Three customers signed up in January 2022; one is dormant. Plus a guest order:

| customer | signup | orders |
|---|---|---|
| 1 | 2022-01-05 | 2022-01-10, 2022-01-15, 2023-01-08 |
| 2 | 2022-01-20 | 2022-02-03 |
| 3 | 2022-01-25 | (none — dormant) |
| — | — | 2022-01-30 (guest, `customer_id` NULL) |

The `2022-01` cohort has **size 3** (dormant customer 3 counts; the guest order does
not add anyone). Customer 1 ordered twice in the signup month — both are offset 0,
and customer 1 is counted **once** there. Customer 1's `2023-01-08` order is offset
**12**, not 0: it is January of the *next* year. Customer 2 is active at offset 1.

Expected rows:

| cohort_month | month_offset | cohort_size | active_customers | retention_rate |
|---|---|---|---|---|
| 2022-01 | 0 | 3 | 1 | 0.3333 |
| 2022-01 | 1 | 3 | 1 | 0.3333 |
| 2022-01 | 12 | 3 | 1 | 0.3333 |

On the visible sample fixture the `2022-01` cohort (size 6) shows activity at
offsets 22, 23, 24 and 25 — the forced November-2023-to-February-2024 run that
crosses the year boundary — which a month-number-only offset places incorrectly.
