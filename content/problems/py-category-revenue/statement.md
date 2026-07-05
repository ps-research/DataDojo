# Revenue by Product Category

The merchandising team wants a clean summary of where sales value is concentrated.
The order-line data is already loaded for you into a pandas DataFrame named `sales`,
with one row per billed line:

| Column | Meaning |
|---|---|
| `order_id` | the order the line belongs to |
| `category` | product category for the line |
| `quantity` | units sold on the line |
| `unit_price` | price per unit |

A line's revenue is `quantity * unit_price`. There is no pre-computed total column,
so you derive it. Every line counts, including any that repeat a category.

## Task

For each `category`, report how many order lines it has, the total units sold, and
the total revenue. Return one row per category, most valuable first.

## Output columns

Print exactly these columns, in this order:

| # | Column | Meaning |
|---|--------|---------|
| 1 | `category` | the category name |
| 2 | `order_count` | number of order lines in the category |
| 3 | `total_units` | sum of `quantity` |
| 4 | `total_revenue` | sum of `quantity * unit_price`, rounded to 2 decimals |

**Order matters.** Sort by `total_revenue` descending, breaking ties by `category`
ascending.

## Worked example

Five lines across two categories:

| order_id | category | quantity | unit_price | line revenue |
|---|---|---|---|---|
| 1 | Books | 2 | 10.00 | 20.00 |
| 2 | Books | 1 | 15.00 | 15.00 |
| 3 | Toys | 3 | 9.00 | 27.00 |
| 4 | Toys | 1 | 9.00 | 9.00 |
| 5 | Books | 4 | 5.00 | 20.00 |

`Books` has 3 lines, 7 units, revenue `20 + 15 + 20 = 55.00`. `Toys` has 2 lines,
4 units, revenue `27 + 9 = 36.00`. Books outranks Toys on revenue, so:

| category | order_count | total_units | total_revenue |
|---|---|---|---|
| Books | 3 | 7 | 55.00 |
| Toys | 2 | 4 | 36.00 |

The result must be printed as CSV to standard output (a header row followed by the
data rows) and nothing else.
