# Top Two Products per Region

The regional managers each want to know their two best-selling products by revenue.
The sales data is already loaded for you into a pandas DataFrame named `sales`, with
one row per sale line:

| Column | Meaning |
|---|---|
| `sale_id` | unique sale line id |
| `region` | one of `East`, `North`, `South`, `West` |
| `product` | product name |
| `amount` | line value |

A product can appear on many lines within a region; its revenue in that region is
the sum of `amount` over all of its lines there.

## Task

For each region, total revenue per product, then keep the **top two products by
revenue**. Rank them within the region: the highest-revenue product is rank 1, the
next is rank 2. If two products in the same region tie on revenue, the one whose
name sorts earlier alphabetically ranks ahead.

## Output columns

Print exactly these columns, in this order:

| # | Column | Meaning |
|---|--------|---------|
| 1 | `region` | the region |
| 2 | `product` | the product name |
| 3 | `product_revenue` | that product's total revenue in the region, rounded to 2 decimals |
| 4 | `rank` | `1` for the region's top product, `2` for the runner-up |

**Order matters.** Sort by `region` ascending, then `rank` ascending. At most two
rows per region.

## Worked example

Sales in one region, `East`:

| sale_id | region | product | amount |
|---|---|---|---|
| 1 | East | Alpha | 50.00 |
| 2 | East | Alpha | 30.00 |
| 3 | East | Bravo | 70.00 |
| 4 | East | Charlie | 10.00 |

Per-product revenue in East: Alpha `80.00`, Bravo `70.00`, Charlie `10.00`. The top
two are Alpha (rank 1) and Bravo (rank 2); Charlie drops off:

| region | product | product_revenue | rank |
|---|---|---|---|
| East | Alpha | 80.00 | 1 |
| East | Bravo | 70.00 | 2 |

The result must be printed as CSV to standard output (a header row followed by the
data rows) and nothing else.
