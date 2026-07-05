# Return Rate by Category

The returns team wants to see which leaf categories get sent back the most. For
each category, compute the **unit return rate**:

```
return_rate = units_returned / units_sold
```

where `units_sold` is the total `quantity` of that category's lines and
`units_returned` is the total `quantity_returned` against those lines.

Three facts about the data make the naive query wrong:

- **A single line can be returned in several parts.** One `order_item` may have two
  or more rows in `returns` (a partial return, then another). If you join
  `order_items` to `returns` and then sum `quantity`, the line's sold quantity is
  counted once per return row — the denominator inflates. Sold units and returned
  units must be aggregated **separately**, then combined.
- **Categories that sold something but had zero returns must stay.** They belong in
  the report with a return rate of `0`. An inner join to returns deletes them.
- **`quantity` is an integer.** `SUM(quantity_returned) / SUM(quantity)` is
  integer division and truncates every real rate below 1 to `0`. Force real
  division (e.g. multiply by `1.0`) and guard the divisor.

Include only categories that **sold at least one unit**.

## Task

Report, for each leaf category that sold something, its `units_sold`,
`units_returned`, and `return_rate`, ranked from highest return rate to lowest.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `category_id` | the leaf category id |
| 2 | `category_name` | the category `name` |
| 3 | `units_sold` | total `quantity` sold in the category |
| 4 | `units_returned` | total `quantity_returned`, `0` if none |
| 5 | `return_rate` | `units_returned / units_sold`, real division, rounded to 4 decimals |

**Order matters.** `ORDER BY return_rate DESC, category_id ASC`.

## Worked example

Three categories, three sold lines, and returns on two of them:

| line (order_item) | category | quantity |
|---|---|---|
| 1 | Audio (20) | 10 |
| 2 | Cables (21) | 4 |
| 3 | Chargers (22) | 5 |

| return | of line | quantity_returned |
|---|---|---|
| 500 | 1 | 2 |
| 501 | 1 | 1 |
| 502 | 2 | 1 |

Line 1 has **two** return rows (a two-part return) totalling 3 units — its sold
quantity is still 10, not 20. Audio: `3 / 10 = 0.3`. Cables: `1 / 4 = 0.25`.
Chargers sold 5 and had no returns, so `0 / 5 = 0.0` and it must still appear.

Expected rows:

| category_id | category_name | units_sold | units_returned | return_rate |
|---|---|---|---|---|
| 20 | Audio | 10 | 3 | 0.3 |
| 21 | Cables | 4 | 1 | 0.25 |
| 22 | Chargers | 5 | 0 | 0.0 |

On the visible sample fixture the highest-rate category is `Electronics Pro`
(category 10) at `0.6667`, and several zero-return categories appear at the bottom
with `return_rate = 0.0`.
