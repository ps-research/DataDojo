# Admissions by Department, Month of Record

It is your first week on the MediCore operations desk. The nightly batch has landed
February 2024 into the reporting warehouse, and the floor managers want a single,
honest number for each clinical department: **how many patients were admitted to that
department in February 2024**, busiest department first.

Every admission is recorded against an *admitting ward*, and every ward rolls up to a
`department` (Cardiology, Emergency, Intensive Care, and so on). You join the two,
keep only the February admissions, and count.

Two things to get right, both easy once you see them:

- **Filter on the admission time, not the id.** `admission_id` is a surrogate key and
  is **not** in chronological order across patients, so you cannot slice a month with
  it. Filter on `admit_ts`.
- **Use a half-open month range.** February is bounded by
  `admit_ts >= '2024-02-01' AND admit_ts < '2024-03-01'`. `admit_ts` is a timestamp,
  so an admission at `2024-02-29 15:00:00` is a genuine February admission and must be
  counted -- a `BETWEEN '2024-02-01' AND '2024-02-29'` would quietly drop it.

## Task

Join `admissions` to `wards` on `ward_id`, keep admissions whose `admit_ts` falls in
February 2024, and report one row per department with its admission count.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `department` | the ward's department |
| 2 | `admission_count` | number of admissions to that department in February 2024 |

**Order matters.** `ORDER BY admission_count DESC, department ASC` -- busiest
department first, ties broken alphabetically by department name.

## Worked example

Three wards and five admissions:

| admission | ward | department | admit_ts |
|---|---|---|---|
| 1 | 1 | Cardiology | 2024-02-03 08:00:00 |
| 2 | 1 | Cardiology | 2024-02-20 14:00:00 |
| 3 | 2 | Emergency | 2024-02-29 15:00:00 |
| 4 | 2 | Emergency | 2024-02-10 09:00:00 |
| 5 | 3 | Neurology | 2024-03-02 10:00:00 |

Admissions 1 and 2 are Cardiology in February; admissions 3 and 4 are Emergency in
February (the `2024-02-29 15:00:00` admission counts). Admission 5 is in March, so it
is excluded, and Neurology has no February admissions and therefore never appears.
Cardiology and Emergency tie at 2, so the alphabetical tie-break lists Cardiology
first.

Expected rows:

| department | admission_count |
|---|---|
| Cardiology | 2 |
| Emergency | 2 |

On the visible sample fixture the busiest department is General Medicine, followed by
Intensive Care. The hidden judge fixture uses a different seed and a larger scale, so
the counts there are entirely different -- a hardcoded copy of the sample answer fails
it.
