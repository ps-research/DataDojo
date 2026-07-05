# Thirty-Day Emergency Readmission Rate by Department

The thirty-day unplanned readmission rate is the number regulators watch and the one
the hospital board loses sleep over: of the patients a department discharges, what
fraction come back through the emergency doors within a month? Computing it correctly is
a minefield of boundary conditions, and the raw data does nothing to help you -- the
admission rows are not sorted by time, and `admission_id` is **not** chronological
across patients, so you cannot use it to find "the next stay."

Work to these definitions exactly:

- **Eligible index stay.** An admission counts as an index stay only if it is
  **completed** (`discharge_ts IS NOT NULL`) and the patient neither died nor was
  transferred out: `discharge_disposition NOT IN ('EXPIRED', 'TRANSFER')`. Still-open
  stays and deaths/transfer-outs are not index stays. (The index stay's own
  `admit_type` is irrelevant -- a planned elective stay can be an index.)
- **The readmission is the *immediate next* admission.** For each patient, order their
  admissions by `admit_ts` (break ties on `admission_id`). An index stay is
  **readmitted** if that patient's very next admission is an `EMERGENCY` admission whose
  `admit_ts` is **within 30 days, inclusive**, of the index discharge -- i.e.
  `discharge_ts <= next_admit_ts <= discharge_ts + 30 days`. A return at **exactly** 30
  days counts.
- **Planned and internal returns do not count.** If the next admission is `ELECTIVE`
  (planned) or `TRANSFER` (internal), it is not a readmission -- even if it lands inside
  the window. Only an `EMERGENCY` next admission qualifies.
- **Group by the *index* stay's department**, and compute
  `rate = readmitted index stays / eligible index stays`.
- **A department with zero eligible index stays reports `NULL`, not an error and not a
  missing row.** Palliative Care discharges are all deaths, so it has no eligible index
  stays; it must still appear, with a `NULL` rate. Guard the division against a zero
  denominator.

## Task

Sequence each patient's admissions in time, flag each eligible index stay as readmitted
or not, and report per department: the eligible index count, the readmitted count, and
the rate.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `department` | the index stay's department |
| 2 | `eligible_index_stays` | number of eligible index stays in that department |
| 3 | `readmissions` | how many of those were readmitted within 30 days |
| 4 | `readmission_rate` | `readmissions / eligible_index_stays`, rounded to 4 decimals; `NULL` when there are zero eligible index stays |

**Order matters.** `ORDER BY department ASC`.

## Worked example

Five patients across three departments (each patient's rows shown in time order):

| adm | patient | dept | admit_ts | discharge_ts | admit_type | disposition |
|---|---|---|---|---|---|---|
| 10 | A | Cardiology | 2024-02-01 09:00 | 2024-02-04 09:00 | ELECTIVE | HOME |
| 11 | A | Cardiology | 2024-03-05 09:00 | (open) | EMERGENCY | (open) |
| 12 | B | Cardiology | 2024-02-05 08:00 | 2024-02-10 08:00 | ELECTIVE | HOME |
| 13 | B | Cardiology | 2024-04-01 08:00 | (open) | EMERGENCY | (open) |
| 14 | C | Emergency | 2024-02-05 00:00 | 2024-02-06 00:00 | EMERGENCY | HOME |
| 15 | C | Emergency | 2024-02-20 00:00 | (open) | ELECTIVE | (open) |
| 16 | D | Emergency | 2024-02-07 00:00 | 2024-02-09 00:00 | EMERGENCY | EXPIRED |
| 17 | E | Palliative Care | 2024-02-03 00:00 | 2024-02-08 00:00 | ELECTIVE | EXPIRED |

- **Adm 10 (index)**: patient A's next admission (adm 11) is `EMERGENCY` and admits on
  `2024-03-05 09:00`, exactly 30 days after the `2024-02-04 09:00` discharge -> **readmitted**.
- **Adm 12 (index)**: B's next (adm 13) is `EMERGENCY` but ~51 days later -> not readmitted.
- **Adm 14 (index)**: C's next (adm 15) lands inside 30 days but is `ELECTIVE` (planned)
  -> not a readmission.
- **Adm 11, 13, 15** are still open -> not eligible index stays. **Adm 16** is a death
  (`EXPIRED`) -> not eligible. **Adm 17** is a Palliative Care death -> not eligible.

Cardiology: 2 eligible (adm 10, 12), 1 readmitted -> `0.5`. Emergency: 1 eligible (adm
14), 0 readmitted -> `0.0`. Palliative Care: 0 eligible -> rate `NULL`.

Expected rows:

| department | eligible_index_stays | readmissions | readmission_rate |
|---|---|---|---|
| Cardiology | 2 | 1 | 0.5 |
| Emergency | 1 | 0 | 0.0 |
| Palliative Care | 0 | 0 | (NULL) |

On the visible sample fixture only Cardiology carries the guaranteed exact-30-day
readmission; Palliative Care reports a `NULL` rate. A strict `< 30 day` window drops
that readmission, and aggregating only over the eligible set makes Palliative Care
vanish instead of reporting `NULL`.
