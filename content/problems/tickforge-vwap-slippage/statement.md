# Best-Execution VWAP Slippage

The execution-quality desk grades each listed name over a full quarter. For the
**taker** flow (liquidity-removing fills only) it wants:

- the name's **realized VWAP** — the volume-weighted average execution price across
  genuine executions, `SUM(fill_price * fill_quantity) / SUM(fill_quantity)`; and
- its **average signed slippage in basis points** versus the *arrival mid* — the mid
  of the top-of-book quote prevailing at each fill. Slippage is signed so that
  **positive = worse than mid**: a BUY that paid above the mid, or a SELL that sold
  below it, is positive. For a fill,
  `slippage_bps = side_sign * (fill_price - mid) / mid * 10000`, where `side_sign` is
  `+1` for BUY and `-1` for SELL.

Then it ranks the names by **taker volume** (a liquidity league table).

Three traps sit in the tape:

1. **Double-booked fills.** Some executions are reported twice — same order, price,
   quantity and timestamp, but a fresh `fill_id`. They were never applied to the
   real book. Counting them inflates volume and distorts VWAP. De-duplicate on the
   business key `(order_id, side, fill_price, fill_quantity, fill_time)`.
2. **Dirty market data.** A usable arrival mid needs a quote with both prices
   present, `ask_price > bid_price` (not crossed/locked), and **both sizes positive**
   (`bid_size > 0 AND ask_size > 0`). Skip everything else; guard the division so a
   non-positive mid never divides.
3. **Exact ties.** The scripted twin names print identical taker volume every
   session, so they **tie** in the league table. `ROW_NUMBER` would silently give
   one of them a better rank and renumber everything below; use `RANK` so tied names
   share a rank.

## Task

Over sessions **`2023-01-01` through `2023-03-31`** (Q1), across **TAKER** fills
only, after de-duplication, report one row per instrument that had at least one
taker fill:

| Column | Meaning |
|---|---|
| `vol_rank` | `RANK()` over `taker_volume` descending (ties share a rank) |
| `symbol` | instrument ticker |
| `taker_volume` | `SUM(fill_quantity)` over de-duplicated taker fills |
| `realized_vwap` | `SUM(fill_price*fill_quantity)/SUM(fill_quantity)`, rounded to 6 decimals |
| `avg_slippage_bps` | `AVG(slippage_bps)` over de-duplicated taker fills **that have a valid arrival mid**, rounded to 4 decimals (NULL if none) |

The arrival mid is the latest **valid** quote for the instrument with
`quote_time <= fill_time` (an as-of join). Volume and VWAP are over *all* de-duped
taker fills; the slippage average is only over the subset with a valid mid.

## Output

Columns exactly: `vol_rank`, `symbol`, `taker_volume`, `realized_vwap`,
`avg_slippage_bps`. **Order:** by `vol_rank`, then `symbol`. `orderMatters` is true.

## Worked example (visible sample)

Twins `AAB` and `AAC` tie at 23000 shares (both `vol_rank` 1); `AAD` and `AAE` tie
at 13 (both `vol_rank` 6). A `ROW_NUMBER` solution would instead print 1,2 and 6,7.

| vol_rank | symbol | taker_volume | realized_vwap | avg_slippage_bps |
|---|---|---|---|---|
| 1 | AAB | 23000 | 52.235826 | -163.809 |
| 1 | AAC | 23000 | 91.097426 | 109.9304 |
| 3 | AAG | 5764 | 248.259068 | 3.7739 |
| 4 | AAI | 4958 | 295.400774 | -18.0106 |
| 5 | AAH | 480 | 278.460563 | 26.6136 |
| 6 | AAD | 13 | 125.281538 | -19.8026 |
| 6 | AAE | 13 | 151.576469 | -116.935 |
| 8 | AAF | 5 | 177.743 | 41.9394 |

The mild visible sample carries no double-booked fills; the hidden quarter does, and
a no-dedup solution over-counts there.
