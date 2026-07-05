# End-of-Day PnL Attribution across Corporate Actions

Every trading day, an account's book equity moves. The risk desk wants that move
**explained** — decomposed into where it came from — for each account, each session,
so the pieces reconcile to the change in mark-to-market equity. The decomposition:

- **`price_pnl`** — mark-to-market on the inventory carried into the day: the
  position held at the previous close, re-marked from the previous mid to today's
  mid. Because a split re-bases shares **and** price together, price PnL uses the
  split-invariant form `Q_prev * (CF_d * m_d - CF_prev * m_prev)`, where `Q_prev` is
  the split-normalized carried position, `CF` is the cumulative split factor, and
  `m` is the carried EOD mid.
- **`trading_pnl`** — edge captured by the day's fills, marked to today's close:
  `SUM(signed_qty * (m_d - fill_price))` over the day's de-duplicated fills.
- **`dividend_pnl`** — cash accrued to holders across a dividend ex-date:
  `cash_amount * shares_held_entering_the_ex_day`.
- **`total_pnl`** = `price_pnl + trading_pnl + dividend_pnl` (this equals the day's
  book-equity change).

The traps, all live at red scale:

1. **Splits re-base on the ex-date**, not the announcement date. Key corporate
   actions on `ex_date`; `announced_at` can even post-date the ex-date. Ignoring a
   split leaves price PnL off by the split factor from the ex-date on.
2. **Marks carry forward over gaps.** On a session with no valid EOD mid (halts,
   thin names), carry the last valid mid forward — over holidays and weekends, using
   the **trading** calendar (the previous session is the previous `session_seq`,
   never `date - 1`).
3. **Boundaries and late events.** Bucket fills by `session_date` (not
   `date(fill_time)` — fills bleed across midnight), and the calendar spans the
   2024-02-29 leap trading day and multiple year-ends.
4. **Duplicates.** De-duplicate double-booked fills on
   `(order_id, side, fill_price, fill_quantity, fill_time)`.

A valid EOD mid needs both prices present, `ask > bid`, and both sizes `> 0`. The
cumulative split factor `CF_d` for an instrument is the product of `a/b` over its
splits with `ex_date <= session_date`; `Q` is the running sum of each day's signed
traded quantity divided by that day's `CF`, so `position = Q * CF`.

## Task

For each account and each session from the account's first trade onward, on which it
**held or traded** (a nonzero position entering the day, or any fill that day), emit
the daily attribution summed over the account's instruments:

| Column | Meaning |
|---|---|
| `account_id` | the account |
| `session_date` | the trading session |
| `price_pnl` | sum of price PnL over instruments, rounded to 4 decimals |
| `trading_pnl` | sum of trading PnL, rounded to 4 decimals |
| `dividend_pnl` | sum of dividend PnL, rounded to 4 decimals |
| `total_pnl` | `price_pnl + trading_pnl + dividend_pnl`, rounded to 4 decimals |

## Output

Columns exactly: `account_id`, `session_date`, `price_pnl`, `trading_pnl`,
`dividend_pnl`, `total_pnl`. **Order:** by `account_id`, `session_date`.
`orderMatters` is true.

## Worked example (visible sample, account 1)

Account 1 holds AAB, which pays a `0.9239` dividend **and** splits `3:2` on the same
ex-date, `2023-02-01`. On that day the dividend accrues on the 21700 shares held
entering the day (`0.9239 * 21700 = 20048.63`) and price PnL correctly absorbs the
split with no artificial jump. Early rows show a clean carry-and-trade series.

| account_id | session_date | price_pnl | trading_pnl | dividend_pnl | total_pnl |
|---|---|---|---|---|---|
| 1 | 2023-01-03 | 0.0 | -823.0 | 0.0 | -823.0 |
| 1 | 2023-01-04 | 1716.0 | -422.0 | 0.0 | 1294.0 |
| 1 | 2023-01-05 | -55.5 | 10.0 | 0.0 | -45.5 |
| 1 | 2023-01-31 | 7280.0 | 471.0 | 0.0 | 7751.0 |
| 1 | 2023-02-01 | -24412.5 | 111.0 | 20048.63 | -4252.87 |

By construction the three components sum to the day's book-equity change: on the
visible sample the reconstructed `total_pnl` reconciles to the independently computed
equity change to within floating error (0.0) across every account-instrument-day.
