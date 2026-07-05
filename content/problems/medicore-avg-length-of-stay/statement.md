# Average Length of Stay by Department

Length of stay (LOS) is the workhorse metric of hospital capacity planning: how many
days, on average, does a patient occupy a bed in each department? Operations wants it
computed **only over completed stays** -- the ones where the patient has actually been
discharged -- and reported in whole days, longest-staying department first.

The subtlety is in what counts:

- **A stay's length is elapsed time, not a calendar-date subtraction.** LOS in whole
  days is the number of complete 24-hour periods between `admit_ts` and `discharge_ts`
  -- i.e. `floor((discharge_ts - admit_ts))` in days. A patient admitted at
  `23:00` and discharged at `03:00` the next morning stayed **0 whole days** (four
  hours), even though the calendar date rolled over. Subtracting the date parts would
  wrongly score that as 1 day.
- **Same-day (0-day) stays are real and must be included.** A short observation stay
  that admits and discharges inside 24 hours is a legitimate 0-day stay; do not drop
  it as "invalid."
- **Still-open stays have no length yet.** A patient who is still in-house has
  `discharge_ts IS NULL`. They have no LOS to average -- exclude them. Do **not**
  treat an open stay as a 0-day stay.
- **February 2024 is a leap month.** A stay that spans 29 February must count that day
  like any other; the elapsed-time approach handles it automatically.

## Task

Over admissions with a recorded discharge (`discharge_ts IS NOT NULL`), compute each
stay's length as whole elapsed days, then report the per-department average.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `department` | the admitting ward's department |
| 2 | `avg_los_days` | average of the completed stays' whole-day lengths, rounded to 2 decimals |

**Order matters.** `ORDER BY avg_los_days DESC, department ASC`.

## Worked example

Two departments, five admissions (one still open):

| admission | department | admit_ts | discharge_ts |
|---|---|---|---|
| 1 | Cardiology | 2024-02-01 08:00:00 | 2024-02-01 20:00:00 |
| 2 | Cardiology | 2024-02-10 00:00:00 | 2024-02-13 12:00:00 |
| 3 | Cardiology | 2024-02-20 09:00:00 | (NULL, still in-house) |
| 4 | Neurology | 2024-02-05 00:00:00 | 2024-02-06 00:00:00 |
| 5 | Neurology | 2024-02-28 12:00:00 | 2024-03-02 12:00:00 |

Whole-day lengths: admission 1 is 12 hours -> **0** days; admission 2 is 3.5 days ->
**3**; admission 3 is open and excluded; admission 4 is exactly **1** day; admission 5
spans 29 February and is exactly **3** days. Cardiology averages `(0 + 3) / 2 = 1.5`;
Neurology averages `(1 + 3) / 2 = 2.0`.

Expected rows:

| department | avg_los_days |
|---|---|
| Neurology | 2.0 |
| Cardiology | 1.5 |

On the visible sample fixture the longest-staying department is General Medicine and
the shortest is Cardiology; the hidden fixture (different seed and scale) produces
different averages.
