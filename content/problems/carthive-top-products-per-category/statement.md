# Top 3 Products per Category by Units Sold

Merchandising wants a leaderboard: within each leaf category, the three
best-selling products by total units sold, with their rank.

Two facts about the data make the naive query wrong:

- **Units tie constantly.** The long tail of the catalog means many products in a
  category share the same small unit total. "Top 3" must therefore return
  **exactly three** products per category (when the category sold at least three),
  broken by a deterministic rule — otherwise a three-way tie at the cutoff returns
  four or five rows, or a nondeterministic three. Use `ROW_NUMBER`, not `RANK`, and
  break ties by the **smaller `product_id` first**.
- **Products that never sold do not appear.** A product with no line items has no
  units and is not a top seller; it must be absent, not shown with zero.

If a category sold fewer than three distinct products, return all of them.

## Task

Aggregate units sold per product within its category, rank products within each
category by units sold (descending) breaking ties by `product_id` (ascending), and
return the top three per category with their rank.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `category_id` | the leaf category id |
| 2 | `category_name` | the category `name` |
| 3 | `product_id` | the product id |
| 4 | `product_title` | the product `title` |
| 5 | `units_sold` | total `quantity` sold for that product |
| 6 | `rnk` | 1, 2, or 3 — the product's rank within its category |

**Order matters.** `ORDER BY category_id ASC, rnk ASC`.

## Worked example

One category `Audio` (20) with five products that sold, plus `Amp` which never
sold; and `Cables` (21) with two products:

| product | category | units_sold |
|---|---|---|
| 100 Headphones | Audio | 5 |
| 101 Earbuds | Audio | 3 |
| 102 Speaker | Audio | 3 |
| 103 Soundbar | Audio | 3 |
| 104 Mic | Audio | 1 |
| 105 Amp | Audio | (never sold) |
| 200 HDMI | Cables | 2 |
| 201 USB-C | Cables | 1 |

Audio has a three-way tie at 3 units (101, 102, 103). The tie-break (smaller
`product_id` first) makes 101 rank 2 and 102 rank 3; 103 falls to rank 4 and is
cut, so Audio returns exactly three rows. Product 105 never sold and is absent.
Cables sold only two products, so both are returned.

Expected rows:

| category_id | category_name | product_id | product_title | units_sold | rnk |
|---|---|---|---|---|---|
| 20 | Audio | 100 | Headphones | 5 | 1 |
| 20 | Audio | 101 | Earbuds | 3 | 2 |
| 20 | Audio | 102 | Speaker | 3 | 3 |
| 21 | Cables | 200 | HDMI | 2 | 1 |
| 21 | Cables | 201 | USB-C | 1 | 2 |

On the visible sample fixture every category with at least three sellers returns
exactly three rows, and ties at the cutoff (for example category 8, three products
tied at 3 units) are resolved by ascending `product_id`.
