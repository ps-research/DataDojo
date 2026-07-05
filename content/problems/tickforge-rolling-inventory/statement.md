# Rolling Inventory & Realized Cash

A market maker's risk desk needs to replay a single account's book fill by fill:
after every execution, what is the running **signed inventory** (shares long +, short
−) in each instrument, and what is the running **net cash** the account has taken in
or paid out? This is the tape that the end-of-month `positions` snapshot is supposed
to tie out against.

Reconstruct the series for account **`account_id = 2`** (the AAC market maker).

Two things make the ordering delicate:

- **Fills are not stored in chronological order.** `fill_id` is a surrogate key; a
  later `fill_id` can carry an *earlier* `fill_time` (reports arrive out of order,
  and some fills are even stamped before their parent order). The event order is
  `fill_time`, **not** `fill_id`.
- **Timestamps tie.** Several fills can share the exact same `fill_time` within an
  instrument. A running total that orders only by `fill_time` leaves those rows as
  window peers and assigns them all the same (end-of-group) total. You must break
  ties deterministically with `fill_id` so every row gets its own correct partial.

## Task

For each fill of account 2, in chronological order **per instrument**, emit:

| Column | Meaning |
|---|---|
| `instrument_id` | the instrument |
| `session_date` | the fill's authoritative session |
| `fill_time` | the fill timestamp |
| `fill_id` | the fill's surrogate id |
| `signed_qty` | `+fill_quantity` for BUY, `-fill_quantity` for SELL |
| `running_inventory` | cumulative `signed_qty` within `(account, instrument)` through this fill, ordered by `(session_date, fill_time, fill_id)` |
| `running_net_cash` | cumulative signed cash through this fill: a SELL adds `fill_price*fill_quantity`, a BUY subtracts it, and the (signed) `fee` is subtracted either way; rounded to 4 decimals |

Order the running windows by `(session_date, fill_time, fill_id)`. `fee` is signed —
a negative fee is a maker rebate, so subtracting it *adds* cash.

## Output

Columns exactly: `instrument_id`, `session_date`, `fill_time`, `fill_id`,
`signed_qty`, `running_inventory`, `running_net_cash`.

**Order:** by `instrument_id`, `session_date`, `fill_time`, `fill_id`.
`orderMatters` is true.

## Worked example (visible sample, first rows)

Note the `fill_id` column is *not* ascending — the rows are in `fill_time` order,
which is why ordering by `fill_id` would misattribute the running totals.

| instrument_id | session_date | fill_time | fill_id | signed_qty | running_inventory | running_net_cash |
|---|---|---|---|---|---|---|
| 2 | 2023-01-03 | 2023-01-03 10:15:32 | 13 | 200 | 200 | -16895.5471 |
| 2 | 2023-01-03 | 2023-01-03 10:15:44 | 18 | 300 | 500 | -42204.6276 |
| 2 | 2023-01-03 | 2023-01-03 10:15:55 | 11 | 100 | 600 | -50639.3372 |
| 2 | 2023-01-03 | 2023-01-03 10:16:02 | 15 | 300 | 900 | -75941.3656 |
| 2 | 2023-01-03 | 2023-01-03 10:16:25 | 10 | 500 | 1400 | -118141.7219 |

Later, two fills tie at `2023-01-27 10:13:49` (`fill_id` 226 then 229). The correct
series shows `running_inventory` 19400 at fill 226 and 19900 at fill 229 — a
`fill_time`-only running total would show 19900 for **both**.
