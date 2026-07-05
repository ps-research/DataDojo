# Top Five Spenders

The retention team wants to reach out to the business's most valuable customers.
Value here means lifetime spend: the sum of every order amount a customer has
placed. You have a customer roster and a flat order log, and you need to rank
customers by how much they have spent in total.

The input data is already loaded into two data frames.

`customers`:

| Column | Type | Meaning |
|--------|------|---------|
| `customer_id` | integer | unique customer id |
| `name` | character | customer display name |
| `city` | character | customer home city |

`orders`:

| Column | Type | Meaning |
|--------|------|---------|
| `order_id` | integer | unique order id |
| `customer_id` | integer | the customer who placed the order |
| `amount` | numeric | dollar amount of the order |

Every `orders.customer_id` refers to a real customer. Some customers may have
placed no orders at all; those customers have no spend and cannot appear among the
top spenders.

## Task

Total each customer's spend across all of their orders, attach the customer's
name, and return the five customers with the highest total spend.

## Output columns

Print exactly these columns, in this order:

| # | Column | Meaning |
|---|--------|---------|
| 1 | `customer_id` | the customer id |
| 2 | `name` | the customer's name |
| 3 | `total_spend` | sum of `amount` across the customer's orders, rounded to 2 decimals |

**Order matters.** Sort by `total_spend` descending, breaking ties by
`customer_id` ascending. Return at most 5 rows.

## Worked example

Suppose two customers and four orders:

`customers`: `(1, "Ann", "Denver")`, `(2, "Bo", "Austin")`.

`orders`:

| order_id | customer_id | amount |
|----------|-------------|--------|
| 10 | 1 | 100.00 |
| 11 | 2 | 250.00 |
| 12 | 1 | 50.00 |
| 13 | 2 | 30.00 |

Ann's total is `100 + 50 = 150.00`; Bo's total is `250 + 30 = 280.00`. Bo ranks
first.

Expected output:

```
"customer_id","name","total_spend"
2,"Bo",280
1,"Ann",150
```
