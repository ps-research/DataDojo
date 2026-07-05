# CartHive universe

| | |
|---|---|
| **Slug** | `carthive` |
| **Theme** | E-commerce marketplace: catalog, orders, order items, returns, web funnels, cohorts |
| **Problem budget** | Blue 2, Purple 3, Black 2, Red 0 |
| **Tables** | 8 (`categories`, `sellers`, `products`, `customers`, `orders`, `order_items`, `returns`, `events`) |
| **Largest fact** | `events` (web-funnel stream): ~2.2M rows at Black scale |

## 1. Narrative

CartHive is a third-party marketplace: independent sellers list products in a
shared catalog, and shoppers browse, add to cart, check out, and occasionally
send things back. The data captures the whole loop. A taxonomy of departments and
leaf categories organizes the catalog; sellers of varying health (active,
suspended, closed) supply the listings; a heavily skewed popularity curve means a
handful of hero products drive most of the volume while a long tail never sells at
all. Every order is a header with one or more line items, and the marketplace
deliberately stores **no order-level total** — money is something you compute from
the lines, and getting that computation right in the presence of duplicate lines,
partial returns, and per-order shipping is most of the difficulty.

Alongside the transactional core sits a raw **web-funnel event stream**: `view ->
add_to_cart -> checkout -> purchase`, grouped by session. This is the messiest
table in the universe and the most realistic. Analytics tags double-fire, so the
same logical event lands twice with different ids. Client clocks drift, so a
session's events do not always arrive in funnel order — a purchase can be
timestamped a few seconds *before* the checkout that produced it. Sessions can be
anonymous (no logged-in customer), and many events are non-product page views.
The stream is what powers funnel-conversion and drop-off analysis, and it is where
naive "just order by timestamp" and "just count the rows" solutions go to die.

The universe is built for **cohort and retention** work as well. Customers carry a
`signup_date`; their orders spread across a three-year window (2022-2024, leap year
included) with realistic decay and seasonality. A share of customers are dormant —
signed up and never seen again — which is exactly the empty-denominator case that
retention math must survive. The result is a compact world that still exercises
multi-table joins, window functions, funnel sessionization, and cohort date
arithmetic, with enough scale in the event stream to make the hard problems bite.

## 2. Table dictionary

### `categories` — catalog taxonomy (two levels)
| column | type | notes |
|---|---|---|
| `category_id` | INTEGER PK | surrogate key |
| `parent_id` | INTEGER | **NULL for a top-level department**; otherwise the department it belongs to (self-reference) |
| `name` | VARCHAR(60) | display name |

Departments never hold products directly — products live only on leaf categories —
so department revenue must roll up through children. A couple of leaf categories
are deliberately product-less (empty groups).

### `sellers` — marketplace merchants
| column | type | notes |
|---|---|---|
| `seller_id` | INTEGER PK | |
| `seller_name` | VARCHAR(80) | |
| `country` | VARCHAR(2) | ISO alpha-2 |
| `joined_date` | DATE | |
| `status` | VARCHAR(10) | `active` \| `suspended` \| `closed` |

Some sellers never make a sale (empty group on the sell side).

### `products` — catalog listings
| column | type | notes |
|---|---|---|
| `product_id` | INTEGER PK | index order also encodes popularity (low id = popular) |
| `seller_id` | INTEGER | FK -> `sellers` |
| `category_id` | INTEGER | FK -> `categories` (always a leaf) |
| `title` | VARCHAR(120) | |
| `list_price` | DECIMAL(10,2) | drawn from a small set of shared price points -> **many ties** |
| `launch_date` | DATE | |
| `is_active` | INTEGER | 0/1 |

### `customers` — acquired accounts
| column | type | notes |
|---|---|---|
| `customer_id` | INTEGER PK | |
| `signup_date` | DATE | cohort anchor |
| `country` | VARCHAR(2) | **NULLable** |
| `acquisition_channel` | VARCHAR(20) | **NULLable**; `organic`/`paid_search`/`social`/`referral`/`email` |
| `birth_year` | INTEGER | **NULLable** |

~10% of customers are dormant (no sessions, no orders).

### `orders` — order headers
| column | type | notes |
|---|---|---|
| `order_id` | BIGINT PK | |
| `customer_id` | INTEGER | **NULL for guest checkouts** (FK -> `customers` otherwise) |
| `order_ts` | TIMESTAMP | |
| `status` | VARCHAR(12) | `placed`/`paid`/`shipped`/`delivered`/`cancelled`/`refunded` |
| `ship_country` | VARCHAR(2) | NULLable |
| `payment_method` | VARCHAR(16) | NULLable; `card`/`paypal`/`wallet`/`giftcard` |
| `shipping_fee` | DECIMAL(8,2) | **order-level** — double-counts if summed after joining line items |

There is no order total column by design; value is derived from `order_items`.

### `order_items` — order line items (primary large fact)
| column | type | notes |
|---|---|---|
| `order_item_id` | BIGINT PK | |
| `order_id` | BIGINT | FK -> `orders` |
| `product_id` | INTEGER | FK -> `products` |
| `seller_id` | INTEGER | FK -> `sellers` (denormalized at sale time) |
| `quantity` | INTEGER | >= 1; **integer** — naive rate math truncates |
| `unit_price` | DECIMAL(10,2) | price charged (may differ from `list_price`) |
| `discount` | DECIMAL(10,2) | **NULLable**; NULL means no discount and must be coalesced |

The same `(order_id, product_id)` can appear on two lines (**duplicate line** /
pipeline double-insert).

### `returns` — returns / refunds (fan-out)
| column | type | notes |
|---|---|---|
| `return_id` | BIGINT PK | |
| `order_item_id` | BIGINT | FK -> `order_items` — **many returns per item possible** |
| `return_ts` | TIMESTAMP | occasionally **before** the order (clock skew) |
| `reason` | VARCHAR(30) | **NULLable** |
| `quantity_returned` | INTEGER | 1 .. line quantity |
| `refund_amount` | DECIMAL(10,2) | |

A single line can be returned in two parts across time, so summing item value via a
join to `returns` fans out.

### `events` — web-funnel stream (largest table)
| column | type | notes |
|---|---|---|
| `event_id` | BIGINT PK | |
| `session_id` | BIGINT | groups a visit |
| `customer_id` | INTEGER | **NULL for anonymous sessions** |
| `product_id` | INTEGER | **NULL for non-product events** (e.g. homepage view) |
| `event_type` | VARCHAR(16) | `view`/`add_to_cart`/`checkout`/`purchase` |
| `event_ts` | TIMESTAMP | **not guaranteed in funnel order** within a session |
| `order_id` | BIGINT | non-NULL only on `purchase`, links to `orders` |

Analytics double-fires produce **duplicate event rows** (identical
session/customer/product/type/ts, different `event_id`).

## 3. Landmine inventory (mapped to CONTENT-SPEC section 5 families)

Every family below is planted by `generator.py`. A handful of small-index
customers carry **forced** plants so the family is present even at `sample` scale;
the rest arise from realistic probabilistic distributions and grow with scale.

| # | CONTENT-SPEC family | How it is planted in CartHive |
|---|---|---|
| 1 | **NULL-in-NOT-IN** | `orders.customer_id` NULL (guest checkouts, forced on customer 3); `customers.acquisition_channel` NULL (~8%); `events.customer_id` NULL (anonymous sessions, forced on customer 5); `returns.reason` NULL; `categories.parent_id` NULL (departments); `payment_method`, `ship_country`, `birth_year` NULL. `WHERE x NOT IN (SELECT ...)` silently empties whenever the subquery yields a NULL. |
| 2 | **Ranking ties** (ROW_NUMBER vs RANK vs DENSE_RANK) | `list_price`/`unit_price` drawn from ~18 shared price points, so many products tie on price; the long popularity tail gives many products identical small unit totals, so "top N by units sold" produces ties at the cutoff. |
| 3 | **Join fan-out double-counting** | An order has many line items, so summing order-level `shipping_fee` (or `COUNT(*)` of orders) after joining `order_items` multiplies; multi-part partial returns give an item several `returns` rows, so item value summed through a returns join fans out; duplicate `(order_id, product_id)` lines. |
| 4 | **Empty / one-row groups** | Dormant customers (~10%, forced on customer 7) have no orders; product-less leaf categories (2 forced) and departments (no direct products); sellers with no sales; categories/months with no returns. INNER JOIN silently drops them. |
| 5 | **Boundary dates** (leap year, month end, year 53) | Forced orders on **2024-02-29** (customer 1), **2023-12-31** (customer 2), **2023-01-31** (customer 3); a forced four-month consecutive run Nov-2023 -> Feb-2024 crossing the **year boundary** (customer 4); return windows straddling month ends. |
| 6 | **Duplicate rows** | Duplicate `order_items` lines (same order+product+qty+price, ~2% + forced on customer 2); double-fired analytics `events` (identical business columns, distinct `event_id`). |
| 7 | **Type-coercion traps** | `quantity` and `quantity_returned` are INTEGER, so `SUM(returned)/SUM(sold)` integer-divides to 0 unless cast; money is DECIMAL; NULL `discount` poisons arithmetic unless coalesced; `birth_year` for age math. |
| 8 | **Gaps vs islands off-by-one** | Cohort month-offset arithmetic across the leap/year boundary; the forced consecutive-active-months run (customer 4) exposes `MONTH()`-only reasoning, which collides Jan-2023 with Jan-2024 and breaks the Dec->Jan adjacency. |
| 9 | **Late / out-of-order events** | ~2% of returns (forced on customer 2) are timestamped before their order; every out-of-order session (forced on customer 6) has a guaranteed funnel-stage timestamp inversion (purchase before checkout), so "order events by ts and read the sequence" misclassifies the funnel. |
| 10 | **Division by zero in rates** | Return-rate denominators that go to zero in a filtered window; funnel conversion for a channel/segment with zero at a stage; cohort retention where a cohort has zero customers at an offset. `NULLIF` / `CASE` required. |

Referential integrity is otherwise clean: **zero** dangling non-NULL foreign keys
at every scale (verified). The only "missing" links are the intentional NULLs
above.

## 4. Scale row counts (measured)

| scale | customers | total rows | largest fact (`events`) | `order_items` | `orders` |
|---|---|---|---|---|---|
| sample | 40 | ~650 | 362 | 94 | 44 |
| blue | 3,000 | ~39.8k (< 50k) | 26k | 6.0k | 2.7k |
| purple | 30,000 | ~401k (< 500k) | 262k | 60k | 27k |
| black | 250,000 | ~3.36M | 2.20M (in 1M-5M) | 517k | 228k |
| red | 900,000 | ~12M | ~7.9M (in 5M-10M) | ~1.9M | ~0.8M |

Deterministic (`random.Random(seed)`, no clock, no globals): identical
`(seed, scale)` produces byte-identical CSVs. Streaming keeps peak RSS at ~24 MB
even at Black scale.

## 5. Problem plan

Ladder: no Red in this universe, so the only rule to honor is **every Black needs
a Purple prerequisite in CartHive** — satisfied below (Bk1 <- P2, Bk2 <- P1/P3).

### B1 — Blue — "Which departments move the most merchandise"
- **Scenario.** The catalog team wants the leaf categories with the highest gross
  merchandise value (GMV = `quantity * unit_price`, summed over all sold lines).
  Return the top 10 categories by GMV, highest first.
- **Techniques.** Three-table join (`order_items` -> `products` -> `categories`),
  `GROUP BY`, `SUM`, `ORDER BY ... DESC`, `LIMIT`.
- **Landmines stepped on.** None material — Blue is deliberately clean. (GMV counts
  every line, so duplicate lines are legitimately part of GMV; departments simply
  never appear because they hold no direct products.)
- **Naive it kills.** Nothing; this is an honest single-technique warm-up.

### B2 — Blue — "Order volume, month by month"
- **Scenario.** Report the number of orders placed in each calendar month across
  the whole history, in chronological order.
- **Techniques.** Timestamp-to-month bucketing, `GROUP BY` a derived month key,
  `ORDER BY` chronologically, `COUNT(*)`.
- **Landmines stepped on.** Gentle: guest orders (NULL `customer_id`) still count as
  orders — a solver who "joins customers to attribute orders" would silently drop
  them, but the clean phrasing rewards counting order rows directly.
- **Naive it kills.** `COUNT(customer_id)` instead of `COUNT(*)` (undercounts guest
  orders); grouping by month-name/number without the year (collides 2022-01 with
  2023-01).

### P1 — Purple — "Return rate by category"
- **Scenario.** For each leaf category, compute the unit return rate =
  `units_returned / units_sold`, keeping categories that sold something even if
  nothing was returned. Rank categories by return rate.
- **Techniques.** Multi-join with a `LEFT JOIN` to `returns`, conditional
  aggregation, safe division (`NULLIF`/`CAST`), `GROUP BY`, `ORDER BY`.
- **Landmines.** Division by zero / integer division (`quantity` is INTEGER, so
  `SUM(returned)/SUM(sold)` truncates to 0); partial-return fan-out (an item with two
  return rows inflates `units_returned` if joined naively at the item grain);
  empty groups (zero-return categories vanish under INNER JOIN); NULL `reason`.
- **Naive it kills.** `SELECT category, SUM(quantity_returned)/SUM(quantity) FROM
  order_items JOIN returns ...` — INNER JOIN drops zero-return categories, the join
  fans out `quantity` across return rows (wrong denominator), and integer division
  yields 0 for every low-rate category.

### P2 — Purple — "Cart-to-purchase conversion by acquisition channel"
- **Scenario.** For each acquisition channel, compute the conversion rate =
  `distinct sessions that reached purchase / distinct sessions that reached
  add_to_cart`. Include a row for unknown-channel traffic.
- **Techniques.** Join `events` -> `customers`, conditional `COUNT(DISTINCT
  session_id)` per stage, safe division, `GROUP BY` a NULL-bearing channel.
- **Landmines.** Duplicate events (a double-fired `add_to_cart` inflates the
  denominator unless `COUNT(DISTINCT session_id)`); NULL `acquisition_channel`
  becomes its own group, not discarded; anonymous sessions (NULL `customer_id`)
  have no channel; division by zero for a channel with carts but zero purchases.
- **Naive it kills.** `COUNT(*)` per stage (duplicate events break it); an INNER
  join that drops NULL-channel / anonymous traffic; `WHERE channel NOT IN (...)`
  emptied by NULLs.

### P3 — Purple — "Top 3 products per category by units sold"
- **Scenario.** Within each leaf category, list the three best-selling products by
  total units, with a deterministic tie-break, and return their rank.
- **Techniques.** Window ranking (`DENSE_RANK`/`ROW_NUMBER`) over a per-product
  aggregate partitioned by category, `QUALIFY`/subquery filter, tie handling, join.
- **Landmines.** Ranking ties (many products share small unit totals, so `RANK`
  returns more than three rows while `ROW_NUMBER` needs an explicit tie-break to be
  reproducible); price ties as a red herring; products that never sold must not
  appear (empty group).
- **Naive it kills.** A correlated subquery counting "how many products in this
  category sold more" (O(n^2), TLE at Purple scale on ~60k line items), and any
  ranking that ignores ties and returns a nondeterministic three.

### Bk1 — Black — "Sessionized funnel drop-off" — prereq: P2
- **Scenario.** Over the full event stream, determine for each session the deepest
  funnel stage it truly reached, correctly handling duplicate events and
  out-of-order timestamps, then report stage-to-stage drop-off (view -> cart ->
  checkout -> purchase) broken down by acquisition channel, with conversion rates.
- **Techniques.** Sessionization, dedup of double-fired events, stage-max logic that
  relies on the funnel hierarchy rather than timestamp order, window/aggregate over
  ~2.2M events, conditional aggregation, safe division, NULL-channel grouping.
- **Landmines.** Out-of-order events (ordering by `event_ts` and reading the last
  stage misclassifies the ~guaranteed inverted sessions); duplicate events
  (double-count every stage under `COUNT(*)`); anonymous / NULL-channel sessions
  (empty groups); division by zero at a stage; the full 2.2M-row scan is real TLE
  pressure.
- **Naive it kills.** "Per session take the `event_type` with `MAX(event_ts)` as the
  outcome" (wrong for inverted sessions); `COUNT(*)` per stage (duplicates); a
  self-join of `events` to `events` to order stages (O(n^2), TLE).

### Bk2 — Black — "Cohort retention grid" — prereq: P1, P3
- **Scenario.** Group customers by signup month (cohort). For each cohort and each
  month-offset m = 0,1,2,..., compute the fraction of that cohort's customers who
  placed at least one order in the m-th month after signup. Emit the retention
  triangle.
- **Techniques.** Cohort assignment, month-offset date arithmetic
  (`(order_year*12 + order_month) - (signup_year*12 + signup_month)`),
  `COUNT(DISTINCT customer_id)`, division by cohort size, generation of the offset
  grid, careful handling of customers with no orders.
- **Landmines.** Boundary / off-by-one date math (offsets computed via
  `datediff/30` or `MONTH()` alone break across month ends, the leap day, and the
  year boundary — see the forced Nov-2023 -> Feb-2024 run); fan-out
  (`COUNT(orders)` instead of `COUNT(DISTINCT customer)` overstates retention when a
  customer orders twice in a month); NULL `customer_id` guests must be excluded from
  cohorts, not counted as an anonymous mega-cohort; empty cohorts / zero-at-offset
  cells force `NULLIF`; duplicate orders in a month.
- **Naive it kills.** Month offset as `CAST((julianday(order_ts) -
  julianday(signup_date))/30 AS INT)` (drifts and mislabels offsets around long
  months / the leap year); `COUNT(*)` orders as the numerator (double counts repeat
  buyers); a per-cohort-per-offset correlated subquery over 228k orders (TLE), all
  while the set-based reference stays well under the limit.

## 6. Self-verification performed

- `python3 generator.py --seed 42 --scale sample --out /tmp/uv_carthive` exits 0 and
  emits all 8 table CSVs; headers match `schema.sql` column order exactly.
- Two runs at the same seed/scale are **byte-identical** (determinism proven).
- Sample CSVs loaded into an in-memory SQLite database against the schema: all
  foreign-key checks show **zero** dangling non-NULL references; sanity joins
  (funnel-purchase -> orders, three-table GMV) return sensible results.
- Every landmine family above was spot-checked present at `sample` scale (NULL
  guests/channels/discounts/reasons/parents, duplicate lines, multi-part returns,
  leap/year-end/month-end orders, price ties, unit-sold ties, dormant customers,
  late returns, funnel-stage timestamp inversions, integer-division truncation, and
  the forced cross-year consecutive-month run on customer 4).
- Scale budgets confirmed by running `blue` (39.8k rows), `purple` (401k rows), and
  `black` (3.36M rows; largest fact 2.2M in the 1M-5M band; peak RSS ~24 MB).
