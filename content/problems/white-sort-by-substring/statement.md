# Sort Jobs by Their Last Two Letters

You can sort by any expression, not just by a bare column. `SUBSTR(str, start)`
returns the piece of `str` beginning at position `start` (1-based) and running to the
end, and `LENGTH(str)` gives the character count. Together, `SUBSTR(job, LENGTH(job) -
1)` extracts the final two characters of each job, and sorting on that groups jobs by
their endings. We add `ename` as a tie-breaker so rows that share a job come out in a
fixed order.

## Task

Return every employee's name and job, ordered by the **last two characters of the job
title**, then by name.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename` | employee name |
| 2 | `job` | employee job title |

**Order matters:** sort by the last two characters of `job` ascending, then by
`ename` ascending.

## Worked example

Consider three jobs and their last two letters:

| ename | job | last two |
|-------|-----|----------|
| ALLEN | SALESMAN | AN |
| BLAKE | MANAGER | ER |
| FORD | ANALYST | ST |

Ordered by that suffix (`AN` < `ER` < `ST`), the query returns:

| ename | job |
|-------|-----|
| ALLEN | SALESMAN |
| BLAKE | MANAGER |
| FORD | ANALYST |
