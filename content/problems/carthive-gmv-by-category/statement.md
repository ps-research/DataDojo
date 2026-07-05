# Which Categories Move the Most Merchandise

The catalog team is planning shelf space and needs to know where the money is. In
CartHive every product lives in exactly one **leaf category** (a category with a
parent), and the marketplace stores no order-level total — value is computed from
the individual line items.

For a single line item, its **gross merchandise value (GMV)** is
`quantity * unit_price`. A category's GMV is the sum of that over every line that
sold one of its products.

Two facts about the data matter:

- **Departments hold no products.** Top-level departments (rows with
  `parent_id IS NULL`) never have products attached directly; products always sit
  on a leaf category. Joining products to their category therefore only ever lands
  on a leaf, and departments simply do not appear in the result.
- **Duplicate line rows are real sales.** The pipeline occasionally writes the same
  `(order_id, product_id)` twice. For GMV that is not a bug to remove: every line
  that was billed contributes its `quantity * unit_price`.

## Task

Join `order_items` to `products` to `categories`, and for each leaf category report
its total GMV. Return the **top 10 categories by GMV**, highest first.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `category_id` | the leaf category id |
| 2 | `category_name` | the category `name` |
| 3 | `gmv` | `SUM(quantity * unit_price)`, rounded to 2 decimals |

**Order matters.** `ORDER BY gmv DESC, category_id ASC` (ties on GMV break by the
smaller `category_id`). Return at most 10 rows.

## Worked example

Three categories — a department `Electronics` (id 10) and two leaves under it,
`Electronics Audio` (20) and `Electronics Cables` (21) — with four sold lines:

| line | product | category | quantity | unit_price | line GMV |
|---|---|---|---|---|---|
| 1 | 100 | Audio (20) | 2 | 50.00 | 100.00 |
| 2 | 101 | Audio (20) | 1 | 30.00 | 30.00 |
| 3 | 102 | Cables (21) | 3 | 10.00 | 30.00 |
| 4 | 100 | Audio (20) | 1 | 50.00 | 50.00 |

Line 4 repeats product 100 (a duplicate line) and still counts. Audio totals
`100 + 30 + 50 = 180.00`; Cables totals `30.00`. The department `Electronics` holds
no products of its own, so it does not appear.

Expected rows:

| category_id | category_name | gmv |
|---|---|---|
| 20 | Electronics Audio | 180.00 |
| 21 | Electronics Cables | 30.00 |

On the visible sample fixture the top category is `Electronics Pro` (category 8)
with a GMV of `1417.86`.
