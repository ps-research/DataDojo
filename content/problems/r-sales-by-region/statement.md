# Regional Sales Roll-Up

The sales operations team keeps a flat log of individual sale lines. Each row is a
single line: which sales `region` it belongs to, the `product` sold, the number of
`units`, and the line `revenue` in dollars. Leadership wants a compact regional
summary to see where the money and the volume are concentrated.

The input data is already loaded into a data frame named `sales` with these
columns:

| Column | Type | Meaning |
|--------|------|---------|
| `region` | character | sales region the line belongs to |
| `product` | character | product code sold on the line |
| `units` | integer | units sold on the line |
| `revenue` | numeric | dollar revenue for the line |

## Task

For each `region`, add up the total units sold and the total revenue across all of
its lines. Report one row per region.

## Output columns

Print exactly these columns, in this order:

| # | Column | Meaning |
|---|--------|---------|
| 1 | `region` | the sales region |
| 2 | `total_units` | sum of `units` for that region |
| 3 | `total_revenue` | sum of `revenue` for that region, rounded to 2 decimals |

**Order matters.** Sort by `total_revenue` descending, breaking ties by `region`
ascending (alphabetical).

## Worked example

Suppose `sales` held just these five lines:

| region | product | units | revenue |
|--------|---------|-------|---------|
| North | SKU-1 | 3 | 100.00 |
| South | SKU-2 | 1 | 40.00 |
| North | SKU-3 | 2 | 60.00 |
| South | SKU-4 | 5 | 40.00 |
| North | SKU-1 | 1 | 25.00 |

North sums to `3 + 2 + 1 = 6` units and `100 + 60 + 25 = 185.00` revenue. South
sums to `1 + 5 = 6` units and `40 + 40 = 80.00` revenue. North outranks South
because its revenue is higher.

Expected output:

```
"region","total_units","total_revenue"
"North",6,185
"South",6,80
```
