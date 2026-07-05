# Royalty Attribution and Payout Reconciliation

Finance closes the books every month by paying each artist the royalties their
music earned. You are auditing those payments against the ground truth in the play
firehose. Recompute what each artist **should** have earned per accounting month,
then reconcile it against what `artist_payouts` actually recorded, and surface every
artist-month that does not line up.

## How a stream earns

Each play earns a per-stream micro-royalty, attributed to **the artist who owns the
played track** (`tracks.artist_id`) and booked into the **accounting month of
`played_at`** (first day of that month). The rate for one play is found in three
steps:

1. **Active plan.** Among the listener's `subscriptions` active on the play's date
   (`started_at <= date <= ended_at`, where a NULL `ended_at` means *still
   active*), take the one with the highest plan precedence
   **premium > family > student > trial > free** (ties broken by the later
   `started_at`). A listener can have two overlapping paid periods — only the
   highest-precedence one counts, never both. If no subscription is active, treat
   the play as `free`.
2. **Rate card.** Look up `royalty_rates` for that plan in the listener's market:
   the row for the listener's `country` if one exists, otherwise the **global**
   row (`country IS NULL`). Use the epoch whose half-open window
   `[effective_from, effective_to)` covers the play date — the rate card was
   revised on `2024-01-01`, and a play on that day earns the **new** rate.
3. **Amount.** `free` and `trial` plans earn `0`. Otherwise the play earns
   `per_play_usd`.

Sum every play's earning to the `(artist_id, month)` grain and round to cents. Only
reconcile artist-months that accrued **at least USD 0.01**.

## The reconciliation

Aggregate `artist_payouts` to `(artist_id, month)`. `paid_usd` is the sum of
amounts on rows whose `status = 'paid'` (0 if none — `pending` and `reversed`
amounts do **not** count as paid). An artist-month is **reconciled** (and omitted
from the report) only when a paid amount lands within **one cent** of the computed
royalty. Report every artist-month that is not reconciled, tagged by
`payout_status`:

- `missing` — no payout row exists for that artist-month at all (includes newly
  signed artists withheld from payouts entirely). Note that `artist_payouts`
  contains unattributed rows with a **NULL `artist_id`**, so this "never paid" set
  must be found with an anti-join, not `NOT IN`.
- `pending` — payout rows exist but none are paid, and at least one is pending.
- `reversed` — payout rows exist, none paid or pending.
- `paid` — a paid amount exists but differs from the computed royalty by more than
  one cent (over- or underpaid).

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `artist_id` | the artist |
| 2 | `artist_name` | `artists.name` |
| 3 | `period_month` | first day of the accounting month (`YYYY-MM-01`) |
| 4 | `computed_usd` | royalty recomputed from the firehose, rounded to cents |
| 5 | `paid_usd` | sum of `paid`-status payout amounts for that artist-month (0 if none) |
| 6 | `payout_status` | `missing` / `pending` / `reversed` / `paid` (as above) |
| 7 | `discrepancy_usd` | `computed_usd - paid_usd` (positive = owed more, negative = overpaid) |

**Order matters.** `ORDER BY artist_id, period_month`.

## Worked example

Four artists, all activity in January 2024. Every listener is on **premium**; the
2024 premium rate is `0.0048` in the US and `0.0038` globally (used for markets
with no bespoke rate, such as FR). Listener U1 additionally carries an overlapping
**family** subscription in January — a glitch — but premium outranks family, so it
must not double-count.

| artist | plays (Jan 2024) | listener market | computed | payout row |
|---|---|---|---|---|
| 1 Aurora Line | 100 × premium (incl. overlap) | US → 0.0048 | 100 × 0.0048 = **0.48** | paid 0.48 |
| 2 Bass Theory | 100 × premium | FR → global 0.0038 | 100 × 0.0038 = **0.38** | pending 0.38 |
| 3 Cobalt Sky | 50 × premium | US → 0.0048 | 50 × 0.0048 = **0.24** | *(none)* |
| 4 Dawn Signal | 100 × premium | US → 0.0048 | 100 × 0.0048 = **0.48** | paid 0.60 |

Expected output:

| artist_id | artist_name | period_month | computed_usd | paid_usd | payout_status | discrepancy_usd |
|---|---|---|---|---|---|---|
| 2 | Bass Theory | 2024-01-01 | 0.38 | 0.00 | pending | 0.38 |
| 3 | Cobalt Sky | 2024-01-01 | 0.24 | 0.00 | missing | 0.24 |
| 4 | Dawn Signal | 2024-01-01 | 0.48 | 0.60 | paid | -0.12 |

Artist 1 is **reconciled** (computed 0.48 = paid 0.48) and is omitted — proving the
overlapping family subscription did **not** double-count (had it, artist 1 would
show 0.85 and appear as a discrepancy). Artist 2 uses the global fallback rate.
Artist 3 has no payout row (`missing`). Artist 4 was overpaid.

On the visible sample fixture (only ~480 plays, so amounts are tiny), the reference
returns five artist-months — a mix of `missing` and `reversed` discrepancies.
