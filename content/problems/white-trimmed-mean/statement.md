# Averaging Without the Highest and Lowest Values

A trimmed mean reduces the pull of outliers by discarding the extreme values before
averaging. Here we compute the average salary after removing every employee earning the
lowest salary and every employee earning the highest salary. Two scalar subqueries,
`(SELECT MIN(sal) FROM emp)` and `(SELECT MAX(sal) FROM emp)`, supply the extremes, and
`NOT IN` filters them out; `AVG(sal)` then runs over the rows that survive.

`NOT IN` is safe in this case because `sal` is never NULL and the MIN/MAX of a non-empty
column are always real values. (With a NULL in the exclusion list, `NOT IN` can silently
return nothing.)

## Task

Report the average salary of all employees, excluding everyone who earns the single
lowest salary and everyone who earns the single highest salary.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `avg_sal` | average salary after removing the min and max earners |

Order does not matter (the result is a single row).

## Worked example

Five salaries:

| sal |
|---|
| 800 |
| 1250 |
| 2450 |
| 3000 |
| 5000 |

The minimum `800` and the maximum `5000` are removed, leaving `1250, 2450, 3000`, whose
average is `(1250 + 2450 + 3000) / 3 = 2233.3333...`.

On the canonical 14-row EMP table, the min `800` (SMITH) and the max `5000` (KING) are
dropped, leaving 12 employees whose salaries sum to `23225`, so the answer is:

| avg_sal |
|---|
| 1935.4166666666667 |
