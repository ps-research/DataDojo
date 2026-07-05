# Order Volume, Month by Month

Operations wants a simple pulse of the marketplace: how many orders were placed in
each calendar month across the whole history, in chronological order.

Two facts about the data matter:

- **Guest checkouts are real orders.** An order may have `customer_id IS NULL` (the
  shopper checked out without an account). These are still orders and must be
  counted. Counting through a join to `customers` would silently drop them.
- **The year is part of the month.** January 2022 and January 2023 are different
  months. Bucketing by month name or month number alone collapses them; the bucket
  must carry the year.

## Task

From `orders` alone, report the number of orders placed in each `YYYY-MM` month,
ordered chronologically.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `order_month` | the calendar month as `'YYYY-MM'` (e.g. `'2023-11'`) |
| 2 | `order_count` | number of orders placed that month |

**Order matters.** `ORDER BY order_month ASC`. Because `'YYYY-MM'` sorts
lexicographically in calendar order, ordering by the month key is chronological.

## Worked example

Four orders, one of them a guest checkout:

| order | customer_id | order_ts |
|---|---|---|
| 1 | 7 | 2022-01-15 09:12:00 |
| 2 | (NULL, guest) | 2022-01-20 14:03:00 |
| 3 | 7 | 2023-01-05 11:00:00 |
| 4 | 7 | 2022-02-02 08:30:00 |

Orders 1 and 2 both fall in `2022-01` (the guest order counts), order 4 is
`2022-02`, and order 3 is `2023-01` — a separate bucket from `2022-01` because the
year differs.

Expected rows:

| order_month | order_count |
|---|---|
| 2022-01 | 2 |
| 2022-02 | 1 |
| 2023-01 | 1 |

On the visible sample fixture the first month is `2022-04` and the busiest months
fall in late 2024.
