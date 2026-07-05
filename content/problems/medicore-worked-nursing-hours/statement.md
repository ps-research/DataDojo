# Worked Nursing Hours by Ward and Month

Payroll reconciliation needs the actual nursing hours logged on each ward, month by
month. The roster is faithful to a real workforce system, which means it carries the
messy cases that make a naive `SUM` wrong.

The rules the finance team agreed on:

- **Nurses only.** Join `roster_shifts` to `staff` and keep `role = 'NURSE'`. Other
  roles are rostered too but are out of scope.
- **Attribute a shift to the month it *starts* in.** Use `shift_date` -- the calendar
  date the shift begins. A NIGHT shift's `scheduled_end` falls on the **next** calendar
  day, so a night shift that starts on `2024-02-29` and ends on `2024-03-01` belongs to
  **February**. Bucketing on `scheduled_end` would misfile every month-end night shift.
- **Sum actual hours, treating a no-show as zero.** The metric is
  `SUM(actual_hours)` with `NULL` (a no-show) read as `0`. A ward-month that consists
  only of no-shows still appears, with `0.00` hours -- it is not dropped.
- **Exclude cancelled shifts.** Rows with `status = 'CANCELLED'` never happened; leave
  them out. (Worked, no-show and swapped shifts all stay in.)
- **Count a double-booked shift once.** The feed occasionally emits the same shift
  twice -- identical nurse, ward, date, shift type, scheduled times, hours and status,
  but a new `shift_id`. That is one shift, not two; de-duplicate on the business content
  before summing so the duplicate does not double-count.

## Task

For each ward and each calendar month present in the roster, report the total actual
nursing hours, following the rules above.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ward_id` | the ward |
| 2 | `shift_month` | the month the shift starts in, as `'YYYY-MM'` |
| 3 | `worked_hours` | sum of actual hours (no-show = 0), duplicates counted once, rounded to 2 decimals |

**Order matters.** `ORDER BY ward_id ASC, shift_month ASC`.

## Worked example

One ward (7), three staff (1 and 2 are nurses, 3 is a physician), six roster rows:

| shift | staff | role | shift_date | shift_type | scheduled_end | actual_hours | status |
|---|---|---|---|---|---|---|---|
| 1 | 1 | NURSE | 2024-02-15 | DAY | 2024-02-15 19:00 | 12.5 | WORKED |
| 2 | 1 | NURSE | 2024-02-15 | DAY | 2024-02-15 19:00 | 12.5 | WORKED |
| 3 | 2 | NURSE | 2024-02-16 | NIGHT | 2024-02-17 07:00 | (NULL) | NOSHOW |
| 4 | 2 | NURSE | 2024-02-29 | NIGHT | 2024-03-01 07:00 | 11.0 | WORKED |
| 5 | 1 | NURSE | 2024-02-20 | SWING | 2024-02-20 23:00 | 0.0 | CANCELLED |
| 6 | 3 | PHYSICIAN | 2024-02-18 | DAY | 2024-02-18 19:00 | 12.0 | WORKED |

Shifts 1 and 2 are an identical double-booking -> counted once (12.5). Shift 3 is a
no-show -> 0. Shift 4 starts on 29 February, so despite ending in March it is a
February shift and contributes 11.0. Shift 5 is cancelled -> excluded. Shift 6 is a
physician -> out of scope. February total for ward 7: `12.5 + 0 + 11.0 = 23.5`.

Expected rows:

| ward_id | shift_month | worked_hours |
|---|---|---|
| 7 | 2024-02 | 23.5 |

On the visible sample fixture each ward reports both a `2024-02` and a `2024-03`
bucket; attributing by `scheduled_end` moves a ward's 29-February night hours into
March, and skipping the de-duplication over-counts the wards that carry a double-booked
shift.
