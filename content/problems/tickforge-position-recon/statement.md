# Position Reconstruction & Mark-to-Market

The risk system stores an end-of-month snapshot of every account's net position in
`positions`. Compliance wants those snapshots independently **rebuilt from the raw
fills** and reconciled: for each month-end holding, reconstruct the signed share
position from the tape, mark it to the closing mid, and flag whether the
reconstruction ties out to the stored snapshot.

Three things break a naive rebuild:

1. **Splits re-base the share count.** On a split ex-date the book is re-based: a
   `'a:b'` split multiplies existing shares by `a/b` (a `'2:1'` doubles them; a
   reverse `'1:10'` scales them to a tenth). To reconstruct today's share count from
   historical fills, every fill executed **strictly before** a split's `ex_date`
   must be scaled by that split's multiplier; fills on or after the ex-date are
   already on the new basis. Ignoring this leaves the position off by the split
   factor after the ex-date. The token must be interpreted, not cast (`CAST('3:2')`
   is not `1.5`).
2. **Duplicate rows.** Fills can be double-booked (same order/price/quantity/time,
   new `fill_id`) and snapshots can be double-posted (same account/instrument/date,
   new `position_id`). De-duplicate both on their business keys.
3. **Month-ends are trading sessions, not calendar dates.** The reporting dates are
   the real month-end sessions (the dates on which `positions` snapshots are taken)
   — never a raw 30th/31st, and note the exchange trades on the 2024-02-29 leap day.

## Task

The reporting dates are the distinct `positions.as_of_date` values (the month-end
sessions). For each de-duplicated snapshot row `(account_id, instrument_id,
as_of_date)`, emit:

| Column | Meaning |
|---|---|
| `account_id`, `instrument_id`, `as_of_date` | the snapshot key |
| `recon_qty` | signed position rebuilt from de-duplicated fills with `session_date <= as_of_date`, split-adjusted, rounded to the nearest whole share |
| `snap_qty` | the snapshot's stored `quantity` (de-duplicated) |
| `mark` | mid of the **last valid** two-sided quote (`bid`/`ask` present, `ask > bid`, both sizes `> 0`) on `as_of_date` for the instrument, rounded to 6 decimals; NULL if none |
| `recon_mtm` | `recon_qty * mark`, rounded to 4 decimals; NULL when `mark` is NULL |
| `qty_reconciles` | `1` if `recon_qty = snap_qty`, else `0` |

Split re-basing: for a fill in session `SD`, multiply its signed quantity by the
product of `a/b` over every split of that instrument with `ex_date > SD` and
`ex_date <= as_of_date`. Bucket fills by `session_date` (the authoritative session),
never `date(fill_time)`.

## Output

Columns exactly: `account_id`, `instrument_id`, `as_of_date`, `recon_qty`,
`snap_qty`, `mark`, `recon_mtm`, `qty_reconciles`. **Order:** by `as_of_date`,
`account_id`, `instrument_id`. `orderMatters` is true.

## Worked example (visible sample, first rows)

Instrument 5 splits `3:1` on 2023-01-31 and instrument 1 splits `3:2` on 2023-02-01,
so their pre-ex fills must be scaled up. On the clean sample every holding
reconciles (`qty_reconciles` = 1). Account 2 / instrument 2 on 2023-02-01 has no
valid closing quote, so `mark` and `recon_mtm` are NULL.

| account_id | instrument_id | as_of_date | recon_qty | snap_qty | mark | recon_mtm | qty_reconciles |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 2023-01-31 | 21700 | 21700 | 54.12 | 1174404.0 | 1 |
| 2 | 2 | 2023-01-31 | 21700 | 21700 | 90.7375 | 1969003.75 | 1 |
| 3 | 4 | 2023-01-31 | -10 | -10 | 135.6273 | -1356.273 | 1 |
| 3 | 5 | 2023-01-31 | -15 | -15 | 69.55 | -1043.25 | 1 |
| 1 | 1 | 2023-02-01 | 33850 | 33850 | 35.33 | 1195920.5 | 1 |
| 2 | 2 | 2023-02-01 | 23000 | 23000 |  |  | 1 |

A rebuild without split re-basing would report `recon_qty` = -5 for account 3 /
instrument 5 (versus -15) and 23000 for account 1 / instrument 1 on 2023-02-01
(versus 33850), failing to reconcile.
