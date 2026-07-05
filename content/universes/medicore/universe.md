# MediCore -- universe design

| | |
|---|---|
| **Slug** | `medicore` |
| **Theme** | Hospital operations: admissions, wards, staffing rosters, procedures, bed transfers, readmissions |
| **Problem budget** | Blue 1, Purple 3, Black 2, Red 0 (6 problems) |
| **Tables** | 8 (`patients`, `wards`, `staff`, `diagnoses`, `admissions`, `procedures`, `bed_transfers`, `roster_shifts`) |
| **Largest fact table** | `bed_transfers` / `roster_shifts` (both cross 1M at black, 5M at red) |

---

## 1. Narrative

MediCore is the shared operational data platform of a mid-sized teaching hospital. Every night a batch job lifts the day's activity out of the electronic health record and the workforce-management system and lands it, warts and all, in a reporting warehouse. The people who query it are not clinicians but operations analysts: they answer questions about how full the wards are, how long patients stay, how often people come back through the emergency doors, and whether the roster actually put enough nurses on each floor. The data is faithful to a real hospital, which means it is faithful to a real hospital's mess -- a patient admitted at 3 a.m. whose discharge has not been keyed yet, a procedure charge that lands two days after the patient went home, a ward whose bed count was zeroed out during a decommissioning that never quite finished, and a night nurse whose shift starts on the twenty-ninth of February and ends in March.

The universe is deliberately built around the two questions hospital operations teams lose sleep over. The first is **readmission**: when a discharged patient reappears as an emergency within thirty days, that is a quality-and-cost signal that gets reported to regulators, and computing it correctly is a minefield of boundary conditions -- who counts as an "index" stay, whether a planned return or an internal transfer counts, what to do with patients who died or are still in-house, and how to pair a discharge with the *next* admission when the raw rows are not even sorted by time. The second is **coverage**: whether the staffing roster met the minimum nurse count on every ward, every day, on every shift -- a question whose hardest cases are the shifts that have *no rows at all*, because an empty slot is precisely a gap you cannot see by looking only at the shifts that exist.

Around those two flagship problems sits a normal hospital schema. Patients accumulate admissions; admissions accumulate procedures and ward-to-ward transfers; staff are rostered onto shifts. Popularity follows a power law (a handful of frequent-flyer patients drive a disproportionate share of admissions; emergency and ICU wards run hotter than a quiet nephrology floor), activity follows weekday and seasonal rhythms, and the fields correlate the way they should -- surgical wards generate more procedures, longer stays generate more transfers, night and weekend shifts are thinner. The traps are not sprinkled on top as flavor; they are load-bearing features of the domain, and each one is planted so that a specific, plausible, expert-looking query gets the wrong answer.

---

## 2. Table dictionary

Conventions: an **empty CSV field means SQL NULL** (the loaders convert empty to NULL). Timestamps are `YYYY-MM-DD HH:MM:SS`, dates are `YYYY-MM-DD`. Foreign keys are documented in `schema.sql` and enforced per-engine by the loaders; a small, documented set of rows breaks referential integrity on purpose (see the landmine inventory).

### `patients` -- registered patients (dimension)
| Column | Type | Meaning / notes |
|---|---|---|
| `patient_id` | INTEGER PK | Surrogate key. |
| `mrn` | VARCHAR(20) | Medical record number. **Not unique** -- patient-merge events reuse an earlier MRN, so distinct-patient counts by MRN are wrong. |
| `birth_date` | DATE | Nullable (unknown DOB). Includes 29 Feb births. |
| `sex` | VARCHAR(1) | `'M'`/`'F'`/`'U'` (unknown), or NULL. `'U'` and NULL are distinct. |
| `blood_type` | VARCHAR(3) | e.g. `'O+'`; nullable. |
| `postal_code` | VARCHAR(10) | **Leading zeros are significant** -- casting to integer corrupts it (type-coercion trap). Nullable. |
| `registered_date` | DATE | First registration. |
| `deceased_date` | DATE | Mostly NULL; set only where a death is on file. |

### `wards` -- physical care units (dimension)
| Column | Type | Meaning / notes |
|---|---|---|
| `ward_id` | INTEGER PK | |
| `ward_code` | VARCHAR(10) | Short code. |
| `ward_name` | VARCHAR(60) | |
| `department` | VARCHAR(40) | Reporting grouping (Cardiology, Emergency, Intensive Care, Palliative Care, ...). |
| `ward_type` | VARCHAR(20) | `'ICU'`,`'ED'`,`'SURGICAL'`,`'GENERAL'`,`'MATERNITY'`. |
| `bed_capacity` | INTEGER | **Can be 0** for a decommissioned / mis-recorded unit -- occupancy-rate denominators divide by zero. |
| `min_nurses_per_shift` | INTEGER | Required nurse count per shift slot. **0 for the decommissioned ward** (never in breach). |
| `opened_date` | DATE | |
| `closed_date` | DATE | Mostly NULL. |

### `staff` -- clinical staff (dimension)
| Column | Type | Meaning / notes |
|---|---|---|
| `staff_id` | INTEGER PK | |
| `staff_code` | VARCHAR(12) | |
| `full_name` | VARCHAR(80) | Non-unique (name collisions are realistic). |
| `role` | VARCHAR(20) | `'NURSE'`,`'PHYSICIAN'`,`'SURGEON'`,`'RESIDENT'`,`'TECH'`. Only `'NURSE'` counts toward coverage. |
| `department` | VARCHAR(40) | Home department. |
| `home_ward_id` | INTEGER | FK -> `wards`; **NULL for float/agency staff**. |
| `hire_date` | DATE | |
| `termination_date` | DATE | Mostly NULL. |
| `fte` | DECIMAL(3,2) | 0.00-1.00. **0.00 = on extended leave** -- per-FTE metrics divide by zero. |

### `diagnoses` -- coded diagnosis reference (dimension)
| Column | Type | Meaning / notes |
|---|---|---|
| `diagnosis_code` | VARCHAR(10) PK | Fictional ICD-style codes. |
| `description` | VARCHAR(120) | |
| `category` | VARCHAR(40) | Body-system chapter. |
| `chronic_flag` | INTEGER | 0/1. |
| `severity_weight` | DECIMAL(4,2) | Comorbidity weight. |

### `admissions` -- inpatient encounters (**primary fact**, readmission spine)
| Column | Type | Meaning / notes |
|---|---|---|
| `admission_id` | BIGINT PK | **Not monotonic with `admit_ts`** across patients -- ordering by id mis-sequences time. |
| `patient_id` | INTEGER | FK -> `patients`. |
| `ward_id` | INTEGER | FK -> `wards` (admitting ward). |
| `attending_staff_id` | INTEGER | FK -> `staff`; **NULL when unassigned** (NULL-in-`NOT IN` trap). |
| `admit_ts` | TIMESTAMP | Admission time. |
| `discharge_ts` | TIMESTAMP | **NULL for a still-open (in-house) stay.** |
| `admit_type` | VARCHAR(12) | `'EMERGENCY'`,`'ELECTIVE'`,`'TRANSFER'`,`'NEWBORN'`. Only EMERGENCY returns count as readmissions. |
| `admit_source` | VARCHAR(20) | `'ED'`,`'REFERRAL'`,`'TRANSFER'`,`'CLINIC'`. |
| `discharge_disposition` | VARCHAR(20) | `'HOME'`,`'SNF'`,`'AMA'`,`'TRANSFER'`,`'EXPIRED'`; NULL if open. |
| `primary_diagnosis_code` | VARCHAR(10) | FK -> `diagnoses`; NULL (undocumented) **or an orphan code** absent from `diagnoses`. |
| `total_charge` | DECIMAL(12,2) | NULL or 0.00 possible. |

### `procedures` -- procedures within an admission (fact; child of `admissions`)
| Column | Type | Meaning / notes |
|---|---|---|
| `procedure_id` | BIGINT PK | |
| `admission_id` | BIGINT | FK -> `admissions`. One admission has 0..N procedures -> **join fan-out**. |
| `procedure_code` | VARCHAR(10) | |
| `procedure_name` | VARCHAR(80) | |
| `performed_ts` | TIMESTAMP | NULL, or occasionally **before admit / after discharge** (late / out-of-order event). |
| `primary_surgeon_id` | INTEGER | FK -> `staff`; NULL when not recorded. |
| `duration_min` | INTEGER | NULL or 0 possible. |
| `is_billable` | INTEGER | 0/1. |

### `bed_transfers` -- ward-to-ward movements within an admission (fact)
| Column | Type | Meaning / notes |
|---|---|---|
| `transfer_id` | BIGINT PK | |
| `admission_id` | BIGINT | FK -> `admissions`. |
| `seq_no` | INTEGER | Intended step number within the stay. |
| `from_ward_id` | INTEGER | FK -> `wards`; **NULL for the initial placement** of a stay. |
| `to_ward_id` | INTEGER | FK -> `wards`. Consecutive same-ward rows (`from = to`) are **island** merges. |
| `transfer_ts` | TIMESTAMP | **Ties and out-of-order values occur**; needs a `seq_no` tiebreak. |
| `reason` | VARCHAR(30) | Nullable. |

### `roster_shifts` -- staffing roster, one row per assigned shift slot (**large fact**)
| Column | Type | Meaning / notes |
|---|---|---|
| `shift_id` | BIGINT PK | |
| `staff_id` | INTEGER | FK -> `staff`. |
| `ward_id` | INTEGER | FK -> `wards`. |
| `shift_date` | DATE | Calendar date the shift **starts** on. |
| `shift_type` | VARCHAR(6) | `'DAY'`,`'NIGHT'`,`'SWING'`. |
| `scheduled_start` | TIMESTAMP | |
| `scheduled_end` | TIMESTAMP | **NIGHT shifts end on the following calendar day** (cross midnight / month end / 29 Feb). |
| `scheduled_hours` | DECIMAL(4,2) | 12.00 (DAY/NIGHT) or 8.00 (SWING). |
| `actual_hours` | DECIMAL(4,2) | **NULL for a no-show**; 0.00 for cancelled; may exceed scheduled (overtime). |
| `status` | VARCHAR(10) | `'WORKED'`,`'NOSHOW'`,`'CANCELLED'`,`'SWAPPED'`. A `(ward,date,shift_type)` slot may have **zero rows** (a coverage gap). |

**Reporting month.** Every scale's simulation window includes **February 2024** (a leap February). The Black problems pin their reporting window to `2024-02-01 .. 2024-02-29` so the same clause works against every fixture.

---

## 3. Landmine inventory

Each entry maps to a canonical family from CONTENT-SPEC section 5 and names where the generator plants it and the naive query it breaks. Items marked **[G]** are *guaranteed* (forced onto low-index rows) so even the tiny `sample` fixture carries them.

| # | Family | Where planted | The naive it kills |
|---|--------|---------------|--------------------|
| 1 | **division by zero in rates** | `wards.bed_capacity = 0` **[G]** (ward 4); `staff.fte = 0.00` **[G]** (staff 3); the all-`EXPIRED` **Palliative Care** department **[G]** yields a zero readmission denominator | occupancy `beds/capacity`, activity `per fte`, and `readmits/COUNT(index)` without `NULLIF` -> RE or WA |
| 2 | **boundary dates (leap/month-end)** | 29 Feb 2024 births **[G]** (patient 3); the exactly-30-day readmission **[G]** (patient 1); NIGHT shifts crossing midnight / month-end / 29 Feb->01 Mar | `< 30 days` (exclusive) readmission windows; a 28-day-February or `end`-date month attribution -> WA on the boundary |
| 3 | **NULL-in-`NOT IN`** | `admissions.attending_staff_id` NULLs; NULL `discharge_disposition` on open stays | `staff_id NOT IN (SELECT attending_staff_id FROM admissions)` returns **zero rows**; `disposition NOT IN ('EXPIRED','TRANSFER')` silently drops open stays |
| 4 | **ranking ties** | Surgeon billable-procedure counts tie within departments; roster hours and `scheduled_hours` tie en masse; readmission rates tie across departments | `ROW_NUMBER() ... = 1` keeps one of several tied leaders -> WA (drops co-leaders) |
| 5 | **join fan-out / double-count** | `admissions`->`procedures` (1:N); `admissions`->`bed_transfers` (1:N); joining `wards`/`staff` onto a fact multiplies rows | counting admissions instead of procedures; `SUM`/`COUNT(*)` after a fan-out join -> WA |
| 6 | **empty / one-row groups** | `(ward,date,shift_type)` slots with **no roster rows** **[G]** (ward 2 / 29 Feb / NIGHT); departments/patients with a single row | anti-join gap detection done as `... FROM roster_shifts GROUP BY ... HAVING COUNT<min` never emits the zero-row slot -> WA |
| 7 | **duplicate rows** | Duplicate `mrn` across patient_ids (merge) **[G present at sample]**; double-booked `roster_shifts`; duplicate `bed_transfers` (same business content, new surrogate id) | `COUNT(*)`/`SUM` that should be `COUNT(DISTINCT ...)` -> over-counts coverage and hours -> WA |
| 8 | **late / out-of-order events** | `admission_id` not chronological with `admit_ts` **[verified]**; procedures `performed_ts` before admit / after discharge; tie/out-of-order `transfer_ts` | pairing "next admission" by `admission_id`; assuming `performed_ts BETWEEN admit AND discharge` -> WA |
| 9 | **gaps vs islands (off-by-one)** | Consecutive same-ward `bed_transfers` (`from=to`) that must merge into one island; the discharge->admit interval | counting each transfer row as a separate ward stay; off-by-one on the 30-day interval endpoints -> WA |
| 10 | **type-coercion** | `postal_code` leading zeros **[verified]**; timestamps stored as text; `sex='U'` vs NULL; `duration_min` 0 vs NULL | `CAST(postal_code AS INT)`; conflating `'U'` with NULL; treating NULL duration as 0 -> WA |
| 11 | **NULL in aggregates** | `discharge_ts` NULL (open stays) **[G]** (patient 1 last stay); `actual_hours` NULL (no-shows) | `COALESCE(discharge, admit)` treats open stays as 0-day LOS; `AVG(actual_hours)` mis-handles no-shows -> WA |
| 12 | **orphan foreign keys** | ~2% of `admissions.primary_diagnosis_code` reference a fabricated `Z999` absent from `diagnoses` **[G]** (patient 4) | `INNER JOIN diagnoses` silently drops those admissions from totals -> WA |

Only #12 breaks declared referential integrity, and only for `primary_diagnosis_code` (~2% of admissions; documented, intentional). All other FKs load clean (verified: zero unintended orphans on `patient_id`, `ward_id`, `admission_id`, roster `staff_id`/`ward_id`, transfer `to_ward_id`).

---

## 4. Problem plan

Ladder rule: both Blacks have Purple prerequisites **in this universe** (satisfied below). No Red in the budget, so no Black->Red chain is required. Anti-hardcode (G2) holds throughout because the hidden judge fixture uses a different seed and a larger scale, so every count/rate differs from the visible sample.

### Blue 1 -- "Admissions by Department, Month of Record"
**Scenario.** Operations wants a one-line-per-department count of how many admissions each department received in a single named calendar month (the reporting month, February 2024), sorted busiest department first, ties broken by department name. A clean, honest warehouse question that an analyst answers on their first week.
**Techniques.** INNER JOIN (`admissions`->`wards`), half-open date-range filter on `admit_ts` (`>= 2024-02-01 AND < 2024-03-01`), `GROUP BY` department, `COUNT(*)`, `ORDER BY`.
**Landmines stepped on.** Kept clean by design (Blue = one technique, clean computation): counting admissions is robust to open stays, NULLs, and the capacity-0 ward. The only real requirement is to filter by `admit_ts` rather than by the non-chronological `admission_id`, and to use a range rather than a fragile string match.
**Naive it kills.** No landmine-proof gate applies at Blue, but the anti-hardcode gate does: a submission that hardcodes the visible month's per-department counts as `SELECT` literals fails the hidden fixture (different seed/scale -> different counts). A `substr(admit_ts,1,7)='2024-02'` string filter is accepted as an alternative; a `BETWEEN '2024-02-01' AND '2024-02-29'` on a timestamp column that silently excludes the last day's afternoon admissions is the gentle teaching point.

### Purple 1 -- "Average Length of Stay by Department"
**Scenario.** For **completed** stays only (those with a recorded discharge), report each department's average length of stay in whole days, longest first. Same-day stays are genuine 0-day stays and must be included; patients who are still in-house have no length of stay yet and must be excluded, not counted as zero.
**Techniques.** Timestamp difference to whole days, `WHERE discharge_ts IS NOT NULL`, `GROUP BY` + `AVG`, `ORDER BY`/ranking, correct day flooring across the 29 Feb boundary.
**Landmines.** #11 NULL-in-aggregate (open stays), #2 boundary (LOS spanning 29 Feb), #6 one-row department groups.
**Naive it kills.** `AVG(julianday(COALESCE(discharge_ts, admit_ts)) - julianday(admit_ts))` -- filling open stays as 0-day inflates the denominator and drags the average down -> **WA**. Also killed: filtering `discharge_ts <> ''` (empty-string) instead of `IS NOT NULL`, and any solution that drops 0-day stays as "invalid."

### Purple 2 -- "Top Surgeon by Billable Volume per Department (ties kept)"
**Scenario.** For each department, list the surgeon(s) who performed the most **billable** procedures. When two or more surgeons tie for the top of a department, list all of them. Unassigned procedures (no surgeon) are ignored.
**Techniques.** Multi-table join (`procedures`->`admissions`->`wards`, `procedures`->`staff`), `WHERE is_billable=1 AND primary_surgeon_id IS NOT NULL`, `GROUP BY` department+surgeon, `COUNT(*)`, then `RANK()/DENSE_RANK() OVER (PARTITION BY department ORDER BY cnt DESC)` keeping rank 1.
**Landmines.** #4 ranking ties, #5 join fan-out, #3 NULL surgeon, #6 empty groups (a department with no billable procedures).
**Naive it kills.** `ROW_NUMBER() OVER (PARTITION BY department ORDER BY cnt DESC) = 1` -> returns exactly one surgeon per department, silently dropping tied co-leaders -> **WA**. Also killed: `COUNT(DISTINCT admission_id)` (undercounts surgeons who did several procedures in one stay) and forgetting `is_billable=1`.

### Purple 3 -- "Worked Nursing Hours by Ward and Month"
**Scenario.** Reconcile the roster: for each ward and calendar month, total the **actual** hours worked by nurses, attributing each shift to the month it **starts** in (a night shift that begins on 29 Feb and ends on 1 Mar belongs to February). No-shows contribute zero worked hours but must not remove the ward from the report; cancelled shifts are excluded; a shift entered twice (double-booked) is counted once.
**Techniques.** Month grouping on `shift_date` (the start date), status filtering, `SUM(COALESCE(actual_hours,0))`, de-duplication of double-booked rows, boundary handling of the midnight/month-end crossing.
**Landmines.** #11 NULL `actual_hours`, #7 duplicate roster rows, #2 boundary (night start-date attribution, month end, 29 Feb), #10/#8 attributing by `scheduled_end` instead of `shift_date`.
**Naive it kills.** Grouping by `substr(scheduled_end,1,7)` -> month-end night shifts land in the wrong month -> **WA**; and `SUM(actual_hours)` over raw rows without de-duping double-booked shifts -> over-counts -> **WA**.

### Black 1 -- "Thirty-Day Emergency Readmission Rate by Department" (flagship)
**Prerequisite (ladder).** Requires an in-universe Purple AC; the temporal/NULL reasoning of **Purple 1** and the ranking/grain discipline of **Purple 2** are its ancestors.
**Scenario.** Compute, per department, the 30-day unplanned readmission rate. An **eligible index** admission is a completed stay (has a discharge) that was not a transfer-out and whose patient did not die (`discharge_disposition` not `'EXPIRED'`/`'TRANSFER'`). A **readmission** is that same patient's *next* `EMERGENCY` admission whose `admit_ts` is within **30 days inclusive** of the index discharge; planned (`ELECTIVE`) and internal `TRANSFER` returns do not count. Rate = readmitted index stays / eligible index stays, grouped by the *index* stay's department; a department with **zero** eligible index stays reports NULL rather than erroring. Rows are not time-ordered and `admission_id` is not chronological.
**Techniques.** Per-patient temporal sequencing via `LEAD(...) OVER (PARTITION BY patient_id ORDER BY admit_ts, admission_id)` (or a bounded self-join with a deterministic tiebreak), inclusive 30-day interval arithmetic, multi-predicate eligibility, correct grain (the index stay), `NULLIF`-guarded division, NULL discharge handling.
**Landmines.** #2 exact-30-day boundary, #11 NULL discharge (open index stays excluded), #8 out-of-order rows / non-chronological id, #4 same-timestamp ties, #5/#7 fan-out and duplicate double-counting, #1 zero denominator (Palliative Care), #3 NULL-in-`NOT IN` on disposition.
**Naives it kills.**
- Self-join to **any** later admission within 30 days (not the immediate next) and counting `ELECTIVE`/`TRANSFER` returns -> double counts bounce-backs and over-counts -> **WA**.
- `julianday(next)-julianday(discharge) < 30` (exclusive) -> misses the exact-30-day case -> **WA**.
- Ordering "next" by `admission_id` -> mis-pairs because id is not chronological -> **WA**.
- `readmits*1.0/COUNT(*)` without excluding deaths/open/transfers and without `NULLIF` -> wrong rate plus division-by-zero on Palliative Care -> **WA/RE**.
- `WHERE discharge_disposition NOT IN ('EXPIRED','TRANSFER')` -> NULL dispositions vanish (NULL-in-`NOT IN`) -> **WA**.
**TLE.** At black (~1.3M admissions) an O(n^2) unbounded self-join blows the limit; the reference's per-patient window finishes well under it.

### Black 2 -- "Nurse Coverage Gaps in the Reporting Month"
**Prerequisite (ladder).** Requires an in-universe Purple AC; **Purple 3** (roster filtering, status handling, night/month-boundary attribution, de-dup) is its direct ancestor.
**Scenario.** For the reporting month (Feb 2024), find every `(ward, date, shift_type)` slot that missed minimum nurse coverage: the number of **distinct nurses who actually worked** the slot is below that ward's `min_nurses_per_shift`. Wards requiring zero nurses are never in breach. A slot with **no roster rows at all** is the worst gap (fully uncovered) and must still be reported -- it is the *absence* of a row. No-shows and cancelled shifts are not coverage; a nurse double-booked into the same slot counts once. Report each breach with its shortfall.
**Techniques.** Build a calendar/shift **spine** (wards x dates-in-Feb-2024 x 3 shift types) via a recursive date CTE or a `CROSS JOIN` over distinct values, `LEFT JOIN` the roster filtered to `role='NURSE' AND status='WORKED'`, `COUNT(DISTINCT staff_id)` per slot, compare to `min_nurses_per_shift`, and surface the zero-match slots. Anti-join / empty-group reasoning, DISTINCT de-duplication.
**Landmines.** #6 empty/zero-row slots (the central kill -- ward 2 / 29 Feb / NIGHT), #7 double-booked nurse (COUNT DISTINCT), #11 no-show/cancelled excluded (ward 2 / 29 Feb / DAY is all-NOSHOW: looks staffed, is not), #2 leap-February spine must contain 29 Feb, #1 min=0 ward never flagged.
**Naives it kills.**
- `SELECT ward,date,shift FROM roster_shifts GROUP BY ward,date,shift HAVING COUNT(*) < min` -- computed from the roster alone, it can never emit a slot that has zero rows -> misses every fully-uncovered slot -> **WA** (the designed kill).
- `COUNT(*)` instead of `COUNT(DISTINCT staff_id)`, or counting rows regardless of `status` -> double-booked nurses and no-shows count as coverage -> **WA**.
- A spine built with `date + INTERVAL '1 month'` arithmetic or a 28-day February -> drops 29 Feb -> **WA** on the leap date.
**TLE.** At black (~1.1M roster rows) a per-slot correlated subquery over the spine is O(slots x roster) and times out; the reference does a single grouped left join.

---

## 5. Generator and self-verification

- **CLI.** `python3 generator.py --seed N --scale {sample|blue|purple|black|red} --out DIR`; one RFC4180 CSV per table with a header row.
- **Determinism.** All randomness flows through a single `random.Random(seed)`; no global `random`, no wall-clock. Same seed+scale is byte-identical (verified: `seed 42 sample` diffs clean across two runs; `seed 7` differs from `seed 42`).
- **Scale (measured, largest fact table).** sample ~538 rows total; blue 22,041 (<=50k); purple 256,933 (<=500k); black 2,086,117 (1M-5M, with `admissions` at 1.30M); red 5,094,887 (5M-10M). Others scale proportionally.
- **Memory.** Only the small dimensions (`wards`, `staff`, `diagnoses`, plus a 64-entry MRN ring buffer) are held in memory; `patients`/`admissions`/`procedures`/`bed_transfers`/`roster_shifts` are streamed row-by-row to disk. Red (12.7M total rows, 1.2 GB) generates without accumulating rows in memory.
- **Integrity + landmines (SQLite load of the sample).** Zero unintended orphans on every enforced FK; the ~2% `Z999` diagnosis orphan and every landmine family in section 3 were queried and confirmed present in the sample fixture, including the guaranteed exact-30-day readmission (patient 1) and the guaranteed uncovered / all-no-show roster slots (ward 2, 29 Feb 2024).
