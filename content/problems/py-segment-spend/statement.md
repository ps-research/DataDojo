# Spend by Customer Segment

The growth team wants total spend broken out by customer segment. Two DataFrames are
already loaded for you.

`customers`, the customer master, one row per registered customer:

| Column | Meaning |
|---|---|
| `customer_id` | unique customer id |
| `name` | customer handle |
| `segment` | one of `Enterprise`, `Consumer`, `SMB` |

`orders`, the order log, one row per order:

| Column | Meaning |
|---|---|
| `order_id` | unique order id |
| `customer_id` | who placed the order |
| `amount` | order value |

Some orders were placed as **guest checkouts**: their `customer_id` has no matching
row in `customers`. Those orders belong to no segment and must be excluded. Join the
two tables so that only orders with a matching customer are kept.

## Task

Join `orders` to `customers` on `customer_id`, keeping only matched orders, and for
each `segment` report the number of matched orders and the total amount.

## Output columns

Print exactly these columns, in this order:

| # | Column | Meaning |
|---|--------|---------|
| 1 | `segment` | the customer segment |
| 2 | `order_count` | number of matched orders in the segment |
| 3 | `total_amount` | sum of `amount` over matched orders, rounded to 2 decimals |

**Order matters.** Sort by `total_amount` descending, breaking ties by `segment`
ascending.

## Worked example

`customers`:

| customer_id | name | segment |
|---|---|---|
| 1 | a | Consumer |
| 2 | b | Enterprise |
| 3 | c | Consumer |

`orders`:

| order_id | customer_id | amount |
|---|---|---|
| 10 | 1 | 40.00 |
| 11 | 2 | 100.00 |
| 12 | 3 | 60.00 |
| 13 | 9 | 500.00 |

Order 13 references customer 9, who is not in `customers`, so it is dropped.
`Consumer` keeps orders 10 and 12 (total `100.00`, 2 orders); `Enterprise` keeps
order 11 (total `100.00`, 1 order). They tie on total, so `Consumer` sorts first by
segment name:

| segment | order_count | total_amount |
|---|---|---|
| Consumer | 2 | 100.00 |
| Enterprise | 1 | 100.00 |

The result must be printed as CSV to standard output (a header row followed by the
data rows) and nothing else.
