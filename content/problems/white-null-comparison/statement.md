# Comparing Through NULLs with COALESCE

`NULL` is not a value, so a test like `comm < 500` evaluates to *unknown* (never true) whenever
`comm` is `NULL`, and those rows quietly disappear from the result. When you want a missing
value to behave like a real one, wrap the nullable column in `COALESCE` to substitute a default
first — here `COALESCE(comm, 0)` treats a `NULL` commission as `0` so those employees are
compared and kept.

## Task

Return every employee whose commission is **less than WARD's commission**, counting a `NULL`
commission as `0`.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename` | employee name |
| 2 | `comm` | the employee's commission (may be `NULL`) |

Order does not matter.

## Worked example

WARD's commission is `500`. Employees with a commission below that include ALLEN (`300`) and
TURNER (`0`). Every employee with a `NULL` commission — SMITH, JONES, BLAKE, CLARK, SCOTT,
KING, ADAMS, JAMES, FORD, MILLER — counts as `0`, which is below `500`, so they are included
too. WARD (`500`, not less than itself) and MARTIN (`1400`) are excluded. That leaves 12 rows.

Sample of the expected rows:

| ename | comm |
|---|---|
| SMITH | (NULL) |
| ALLEN | 300 |
| TURNER | 0 |
| ... | ... |
