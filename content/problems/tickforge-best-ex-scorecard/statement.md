# Adverse-Selection Best-Execution Scorecard

The exchange grades taker execution quality on every listed name for the year and
looks for **adverse selection** — the signal that a taker who lifted the offer (or
hit the bid) was picked off right before the market moved. For each name, over
de-duplicated TAKER fills that have a valid arrival mid:

- **`avg_slippage_bps`** — average signed effective spread versus the *arrival mid*
  (the last valid quote at/before the fill). Signed so positive = worse than mid:
  `side_sign * (fill_price - arrival_mid) / arrival_mid * 10000`, `side_sign` = +1
  BUY, -1 SELL.
- **`avg_markout_bps`** — average signed **markout** to the *next* mid: the first
  valid quote strictly **after** the fill (`markout_mid`). Signed the taker's way:
  `side_sign * (markout_mid - arrival_mid) / arrival_mid * 10000`. Positive means the
  mid moved in the taker's favor after they traded; persistently negative markouts
  are the adverse-selection tell. A fill with **no** later valid quote has no markout
  and is excluded from this average only (a missing future quote must never divide
  or count).
- **`sector_slippage_pctile`** — the name's `avg_slippage_bps` percentile
  (`PERCENT_RANK`) **within its sector cohort**. Unclassified names (NULL sector)
  are their own cohort `'UNCLASSIFIED'` — they must not vanish.
- **`vol_rank`** — `DENSE_RANK` over taker volume descending; the twin names tie and
  must share a rank.

A **valid** quote (for either mid) has both prices present, `ask_price > bid_price`,
and both sizes `> 0`. De-duplicate double-booked fills on
`(order_id, side, fill_price, fill_quantity, fill_time)`. Only fills with a valid
arrival mid are scored.

## Task

Over sessions **`2023-01-01` through `2023-12-31`**, TAKER fills only, produce one
row per instrument that has at least one scored fill:

| Column | Meaning |
|---|---|
| `sector_cohort` | `COALESCE(sector, 'UNCLASSIFIED')` |
| `symbol` | instrument ticker |
| `taker_volume` | `SUM(fill_quantity)` over scored (arrival-mid-having) de-duped taker fills |
| `avg_slippage_bps` | as above, rounded to 4 decimals |
| `n_markout` | count of scored fills that also have a valid next-quote markout mid |
| `avg_markout_bps` | as above over those fills, rounded to 4 decimals (NULL if none) |
| `sector_slippage_pctile` | `PERCENT_RANK()` of `avg_slippage_bps` within `sector_cohort`, rounded to 6 decimals |
| `vol_rank` | `DENSE_RANK()` over `taker_volume` descending |

## Output

Columns exactly: `sector_cohort`, `symbol`, `taker_volume`, `avg_slippage_bps`,
`n_markout`, `avg_markout_bps`, `sector_slippage_pctile`, `vol_rank`.
**Order:** by `sector_cohort`, `avg_slippage_bps`, `symbol`. `orderMatters` is true.

## Worked example (visible sample)

Each sector has a single name in the sample, so every `sector_slippage_pctile` is 0
(percentiles only bite at red scale, ~82 names per sector). Twins `AAB`/`AAC` tie on
volume (both `vol_rank` 1); `AAD`/`AAE` tie (both 5). No NULL-sector names exist
below 13 instruments, so the `UNCLASSIFIED` cohort is empty here — but on the hidden
red fixture it is populated and must appear.

| sector_cohort | symbol | taker_volume | avg_slippage_bps | n_markout | avg_markout_bps | sector_slippage_pctile | vol_rank |
|---|---|---|---|---|---|---|---|
| Consumer | AAF | 5 | 41.9394 | 3 | -0.6698 | 0.0 | 6 |
| Energy | AAC | 20400 | 109.9304 | 76 | 54.5481 | 0.0 | 1 |
| Financials | AAB | 20400 | -163.809 | 80 | -171.2274 | 0.0 | 1 |
| Healthcare | AAD | 13 | -19.8026 | 2 | -0.6213 | 0.0 | 5 |
| Industrials | AAE | 13 | -116.935 | 4 | 10.9171 | 0.0 | 5 |
| Materials | AAG | 5764 | 3.7739 | 19 | -0.8425 | 0.0 | 2 |
| RealEstate | AAI | 4958 | -18.0106 | 8 | -18.6439 | 0.0 | 3 |
| Utilities | AAH | 480 | 26.6136 | 9 | 93.1928 | 0.0 | 4 |
