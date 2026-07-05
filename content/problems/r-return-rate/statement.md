# Category Return-Rate Leaderboard

The merchandising team wants to know which product categories get sent back the
most. You have a log of shipment lines and the product catalog that maps each
product to its category. Your job is to build a return-rate leaderboard, but the
denominator has to be counted carefully.

The input data is already loaded into two data frames.

`order_items` (one row per shipped or attempted line):

| Column | Type | Meaning |
|--------|------|---------|
| `order_id` | integer | unique line id |
| `product_id` | integer | product on this line |
| `quantity` | integer | units on this line |
| `status` | character | one of `delivered`, `returned`, `cancelled` |

`products`:

| Column | Type | Meaning |
|--------|------|---------|
| `product_id` | integer | unique product id |
| `product_name` | character | product name |
| `category` | character | the product's category |

## Definitions and rules

- **Shipped units** for a category are the total `quantity` on its `delivered`
  and `returned` lines. A `cancelled` line never shipped, so it is excluded from
  the shipped total entirely.
- **Returned units** for a category are the total `quantity` on its `returned`
  lines.
- **Return rate** is `returned units / shipped units`, rounded to 4 decimals.
- A category that ships but has zero returns still belongs on the board with a
  return rate of `0`.
- Only include categories whose **shipped units are at least 100**. Smaller
  categories are dropped.

## Task

Join each line to its product's category, compute the shipped and returned unit
totals per category, keep the categories at or above the shipped threshold, and
rank them by return rate.

## Output columns

Print exactly these columns, in this order:

| # | Column | Meaning |
|---|--------|---------|
| 1 | `category` | the category name |
| 2 | `total_shipped` | sum of `quantity` on delivered and returned lines |
| 3 | `total_returned` | sum of `quantity` on returned lines |
| 4 | `return_rate` | `total_returned / total_shipped`, rounded to 4 decimals |

**Order matters.** Sort by `return_rate` descending, breaking ties by `category`
ascending.

## Worked example

Suppose one category, `Widgets`, had these four lines:

| product | quantity | status |
|---------|----------|--------|
| A | 4 | delivered |
| B | 2 | returned |
| C | 5 | cancelled |
| A | 3 | delivered |

Shipped units are `4 + 2 + 3 = 9` (the cancelled line of 5 is excluded). Returned
units are `2`. The return rate is `2 / 9 = 0.2222`.

Expected row:

```
"category","total_shipped","total_returned","return_rate"
"Widgets",9,2,0.2222
```

On the visible fixture, `Home` tops the board and the `Footwear` category is
dropped for shipping fewer than 100 units.
