# Region by Category Revenue Matrix

The planning team wants a compact cross-tab of revenue: regions down the side,
product categories across the top. The sales data is already loaded for you into a
pandas DataFrame named `sales`, with one row per sale:

| Column | Meaning |
|---|---|
| `sale_id` | unique sale id |
| `region` | one of `East`, `North`, `South`, `West` |
| `category` | one of `Apparel`, `Electronics`, `Home`, `Toys` |
| `amount` | sale value |

## Task

Build a matrix whose rows are regions and whose columns are the four categories,
where each cell is the total `amount` for that region and category.

The column set is **fixed**: always emit all four category columns in the order
`Apparel`, `Electronics`, `Home`, `Toys`, even if a particular region never sold a
category. A region-category pair with no sales must show `0` (or `0.0`), not be
dropped. Then add a `row_total` column holding the sum of the four category cells
for that region.

## Output columns

Print exactly these columns, in this order:

| # | Column | Meaning |
|---|--------|---------|
| 1 | `region` | the region |
| 2 | `Apparel` | total `amount` for Apparel in the region, rounded to 2 decimals |
| 3 | `Electronics` | total `amount` for Electronics in the region, rounded to 2 decimals |
| 4 | `Home` | total `amount` for Home in the region, rounded to 2 decimals |
| 5 | `Toys` | total `amount` for Toys in the region, rounded to 2 decimals |
| 6 | `row_total` | sum of the four category cells, rounded to 2 decimals |

**Order matters.** Sort by `region` ascending. One row per region.

## Worked example

Four sales:

| sale_id | region | category | amount |
|---|---|---|---|
| 1 | East | Apparel | 100.00 |
| 2 | East | Home | 40.00 |
| 3 | West | Toys | 25.00 |
| 4 | East | Apparel | 60.00 |

East sold Apparel `100 + 60 = 160.00` and Home `40.00`, with no Electronics or Toys
(both `0.0`); its row total is `200.00`. West sold only Toys `25.00`:

| region | Apparel | Electronics | Home | Toys | row_total |
|---|---|---|---|---|---|
| East | 160.00 | 0.0 | 40.00 | 0.0 | 200.00 |
| West | 0.0 | 0.0 | 0.0 | 25.00 | 25.00 |

The result must be printed as CSV to standard output (a header row followed by the
data rows) and nothing else.
