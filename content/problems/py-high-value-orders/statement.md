# High-Value Completed Orders

The finance team is auditing large settled sales. The order data is already loaded
for you into a pandas DataFrame named `orders`, with one row per order:

| Column | Meaning |
|---|---|
| `order_id` | unique order id |
| `customer_id` | the customer who placed the order |
| `region` | sales region |
| `status` | one of `cancelled`, `completed`, `pending`, `refunded` |
| `amount` | order value |

## Task

Return the orders that are both **completed** and worth **at least 100**. An order
qualifies only when `status` equals `completed` and `amount` is greater than or
equal to `100`. Pending, cancelled, and refunded orders never qualify, whatever
their amount.

## Output columns

Print exactly these columns, in this order:

| # | Column | Meaning |
|---|--------|---------|
| 1 | `order_id` | the order id |
| 2 | `customer_id` | the customer id |
| 3 | `region` | the sales region |
| 4 | `amount` | the order value |

**Order matters.** Sort by `amount` descending, breaking ties by `order_id`
ascending.

## Worked example

Six orders:

| order_id | customer_id | region | status | amount |
|---|---|---|---|---|
| 1 | 10 | East | completed | 250.00 |
| 2 | 11 | West | pending | 300.00 |
| 3 | 12 | East | completed | 99.50 |
| 4 | 13 | North | completed | 120.00 |
| 5 | 14 | South | refunded | 500.00 |
| 6 | 15 | West | completed | 120.00 |

Order 2 is pending, order 3 is below 100, and order 5 is refunded, so all three are
excluded. The rest are completed and at least 100. Sorting by amount descending,
then order_id ascending (orders 4 and 6 tie at 120.00, so 4 comes first):

| order_id | customer_id | region | amount |
|---|---|---|---|
| 1 | 10 | East | 250.00 |
| 4 | 13 | North | 120.00 |
| 6 | 15 | West | 120.00 |

The result must be printed as CSV to standard output (a header row followed by the
data rows) and nothing else.
