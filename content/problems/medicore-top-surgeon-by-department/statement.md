# Top Surgeon by Billable Volume per Department (ties kept)

The surgical throughput review asks a ranking question: **within each department, which
surgeon performed the most billable procedures?** When two or more surgeons tie for the
top of a department, the review wants **all** of them listed -- naming only one and
dropping the co-leaders would misreport the workload.

The grain and the filters are where this is won or lost:

- **Count billable procedures, one row each.** The volume is the number of procedure
  rows with `is_billable = 1`. If a surgeon performed three billable procedures during a
  single admission, that is three -- do **not** collapse them to one per admission.
- **Only billable work counts.** Rows with `is_billable = 0` are excluded. Forgetting
  this inflates counts and can change who wins.
- **Unassigned procedures are ignored.** A procedure with `primary_surgeon_id IS NULL`
  has no surgeon and does not belong to anyone's total.
- **A procedure's department is the department of its admission's admitting ward.** Join
  `procedures` to `admissions` (on `admission_id`) to `wards` (on `ward_id`) to reach
  `department`.
- **Keep ties.** Use `RANK()` (or `DENSE_RANK()`) partitioned by department, ordered by
  the billable count descending, and keep every surgeon at rank 1 -- not `ROW_NUMBER()`,
  which arbitrarily keeps just one.

## Task

For each department, list the surgeon(s) whose billable-procedure count is the maximum
in that department.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `department` | the department |
| 2 | `surgeon_id` | `staff_id` of a top surgeon in that department |
| 3 | `surgeon_name` | that surgeon's `full_name` |
| 4 | `billable_count` | number of billable procedures they performed in that department |

**Order matters.** `ORDER BY department ASC, surgeon_id ASC`.

## Worked example

Two departments, three surgeons, eight procedures:

| procedure | admission | department | surgeon | is_billable |
|---|---|---|---|---|
| 1 | 100 | Cardiology | 10 | 1 |
| 2 | 100 | Cardiology | 10 | 1 |
| 3 | 101 | Cardiology | 11 | 1 |
| 4 | 101 | Cardiology | 11 | 1 |
| 5 | 100 | Cardiology | 12 | 0 |
| 6 | 102 | Orthopedics | 11 | 1 |
| 7 | 102 | Orthopedics | 12 | 1 |
| 8 | 102 | Orthopedics | (NULL) | 1 |

In Cardiology, surgeon 10 has 2 billable procedures and surgeon 11 has 2 -- a tie for
the top, so both are listed. Surgeon 12's Cardiology procedure is not billable and does
not count. In Orthopedics, surgeon 11 and surgeon 12 each have 1 billable procedure (the
unassigned procedure 8 is ignored), another tie.

Expected rows (surgeon names: 10 = Grace Kaur, 11 = Liam Novak, 12 = Mona Sato):

| department | surgeon_id | surgeon_name | billable_count |
|---|---|---|---|
| Cardiology | 10 | Grace Kaur | 2 |
| Cardiology | 11 | Liam Novak | 2 |
| Orthopedics | 11 | Liam Novak | 1 |
| Orthopedics | 12 | Mona Sato | 1 |

On the visible sample fixture several departments have multiple tied leaders at a count
of 1, and a `ROW_NUMBER()`-based query returns 6 rows where the correct answer returns
11 -- exactly the co-leaders it drops.
