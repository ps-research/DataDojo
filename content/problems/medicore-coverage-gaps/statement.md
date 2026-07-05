# Nurse Coverage Gaps in the Reporting Month

Every ward has a minimum nurse count it must field on every shift. The safety review
wants the opposite of a staffing report: not who was on, but **every slot that fell
short** in the reporting month, February 2024. A "slot" is one `(ward, date,
shift_type)` -- a ward, one of the 29 days of February 2024, and one of `DAY`, `NIGHT`,
`SWING`.

The trap that makes this a hard problem is that **the worst gaps are invisible in the
roster.** A slot that nobody was ever assigned to has *no rows at all* in
`roster_shifts`; a slot where everyone assigned then no-showed has rows, but none of
them are coverage. You cannot find an absence by grouping the rows that exist -- you
have to enumerate every slot that *should* exist and left-join the roster onto it.

Definitions:

- **Coverage = distinct nurses who actually worked.** For a slot, coverage is
  `COUNT(DISTINCT staff_id)` over `roster_shifts` rows where the staff member is a nurse
  (`role = 'NURSE'`) and the shift `status = 'WORKED'`. No-shows, cancellations and
  swaps are **not** coverage. A nurse double-booked into the same slot (a duplicated
  row) counts **once** -- hence `DISTINCT`.
- **Breach = coverage below the requirement.** A slot is a breach when its coverage is
  strictly less than that ward's `min_nurses_per_shift`. Report the `shortfall =
  min_nurses_per_shift - coverage`.
- **A fully-uncovered slot is the worst breach and must still be reported.** If a slot
  has zero worked nurses -- whether because no one was rostered or because everyone
  no-showed -- coverage is `0`, and if the ward requires more than zero nurses it is a
  breach with `shortfall = min_nurses_per_shift`.
- **Wards requiring zero nurses are never in breach.** A ward with
  `min_nurses_per_shift = 0` (the decommissioned unit) is excluded.
- **February 2024 has 29 days.** The slot spine must include 29 February; a spine built
  by "add one month" arithmetic or a 28-day February silently drops the leap day and
  every gap on it.

## Task

Build the full slot spine (wards with `min_nurses_per_shift > 0`, crossed with the 29
February-2024 dates and the three shift types), left-join the worked-nurse counts onto
it, and return every slot whose coverage is below the ward's minimum.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ward_id` | the ward |
| 2 | `shift_date` | the slot's calendar date (a February 2024 date) |
| 3 | `shift_type` | `'DAY'`, `'NIGHT'` or `'SWING'` |
| 4 | `required_nurses` | the ward's `min_nurses_per_shift` |
| 5 | `nurses_worked` | distinct nurses who worked the slot (0 if none) |
| 6 | `shortfall` | `required_nurses - nurses_worked` |

**Order matters.** `ORDER BY ward_id ASC, shift_date ASC, shift_type ASC`.

## Worked example

One ward (2), requiring 2 nurses. Two staff are nurses (1, 2); staff 3 is a physician.
The roster for this ward:

| shift | staff | role | shift_date | shift_type | status |
|---|---|---|---|---|---|
| 1 | 1 | NURSE | 2024-02-15 | DAY | WORKED |
| 2 | 2 | NURSE | 2024-02-15 | DAY | WORKED |
| 3 | 1 | NURSE | 2024-02-29 | DAY | NOSHOW |
| 4 | 2 | NURSE | 2024-02-29 | DAY | NOSHOW |
| 5 | 1 | NURSE | 2024-02-29 | SWING | WORKED |
| 6 | 1 | NURSE | 2024-02-29 | SWING | WORKED |
| 7 | 3 | PHYSICIAN | 2024-02-29 | SWING | WORKED |

- **2024-02-15 DAY**: two distinct nurses worked -> coverage 2 = requirement -> **not a
  breach** (does not appear).
- **2024-02-29 DAY**: both assigned nurses no-showed -> coverage 0 -> breach, shortfall 2.
- **2024-02-29 NIGHT**: no roster rows at all -> coverage 0 -> breach, shortfall 2.
- **2024-02-29 SWING**: nurse 1 is double-booked (shifts 5 and 6) -> counts once; the
  physician does not count -> coverage 1 -> breach, shortfall 1.

Focusing on 29 February, the expected rows for ward 2 are:

| ward_id | shift_date | shift_type | required_nurses | nurses_worked | shortfall |
|---|---|---|---|---|---|
| 2 | 2024-02-29 | DAY | 2 | 0 | 2 |
| 2 | 2024-02-29 | NIGHT | 2 | 0 | 2 |
| 2 | 2024-02-29 | SWING | 2 | 1 | 1 |

(The full result also contains breach rows for every other February date on which this
ward's coverage falls short -- for example 2024-02-15 `NIGHT` and `SWING`, which have no
worked nurses at all. Only 2024-02-15 `DAY` is covered and thus excluded.)

On the visible sample fixture ward 2 on 29 February is guaranteed to be uncovered on
`NIGHT` (no rows) and all-no-show on `DAY` -- both fully-uncovered breaches that a
roster-only `GROUP BY ... HAVING COUNT < min` never emits.
