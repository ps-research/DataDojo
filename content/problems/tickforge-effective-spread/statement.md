# Effective Spread vs Mid

Best-execution analysis starts with a simple question: when a trade printed, how
far was the execution price from the fair mid-quote *prevailing at that instant*?
The **effective spread** of a fill is `2 * |fill_price - mid|`, where `mid` is the
midpoint of the top-of-book quote in effect at (or just before) the fill. A fill
that executes strictly **inside** the quoted spread (`bid < fill_price < ask`)
earned **price improvement**.

The market-data feed is noisy. A **valid** quote (a usable mid) requires **all** of:
a bid price and an ask price both present, `ask_price > bid_price` (not crossed or
locked), and **both sizes positive** (`bid_size > 0 AND ask_size > 0` — a size-0 side
is a one-sided market, not a real two-sided quote). Quotes failing any of these are
skipped when choosing the prevailing quote. The mid is `(bid_price + ask_price) / 2`.

## Task

For every fill in sessions **`2023-01-03` through `2023-01-31`** (inclusive), find
the **latest valid quote for the same instrument with `quote_time <= fill_time`**
(an as-of join — this is the mid that was showing when the trade printed; a fill's
own clock may even skew before its parent order, so key strictly off `fill_time`).
Score each such fill, then aggregate per instrument:

| Column | Meaning |
|---|---|
| `symbol` | instrument ticker |
| `n_fills` | number of the instrument's fills that had a valid prevailing quote (were scored) |
| `avg_effective_spread` | `AVG(2 * |fill_price - mid|)` over the scored fills, rounded to 6 decimals |
| `price_improve_share` | fraction of scored fills with `bid < fill_price < ask`, rounded to 6 decimals |

Notes:

- The as-of match is **top-of-book at the fill**, not a day average. Joining fills
  to quotes on `session_date` alone fans every fill out across all of that day's
  quotes and averages the wrong mid.
- A fill whose instrument has **no** valid quote at or before its `fill_time` has no
  mid and is **not** scored (it drops out). An instrument with zero scored fills
  does not appear in the output.
- Replayed/duplicate ticks (same timestamp, same prices) do not change the mid, so
  no de-duplication of quotes is required here — each fill still maps to exactly one
  prevailing quote.

## Output

Columns exactly: `symbol`, `n_fills`, `avg_effective_spread`, `price_improve_share`.
**Order:** by `symbol` ascending. `orderMatters` is true.

## Worked example (visible sample)

`AAB` and `AAC` are the scripted twins and tie on `n_fills` (76 each). Note the
never-traded names (`AAJ`, `AAK`) never appear.

| symbol | n_fills | avg_effective_spread | price_improve_share |
|---|---|---|---|
| AAB | 76 | 1.395395 | 0.026316 |
| AAC | 76 | 2.876336 | 0.0 |
| AAD | 3 | 7.94 | 0.0 |
| AAE | 5 | 5.59698 | 0.0 |
| AAF | 5 | 0.658 | 0.0 |
| AAG | 39 | 2.782051 | 0.128205 |
| AAH | 12 | 4.624167 | 0.0 |
| AAI | 15 | 9.127627 | 0.0 |
