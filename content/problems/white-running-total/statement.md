# Building a Running Total

A running total accumulates a column value row by row: each row shows the sum of
itself and everything that came before it. You get this with a windowed aggregate,
`SUM(sal) OVER (ORDER BY ...)`. The `ORDER BY` inside `OVER (...)` decides the order in
which values accumulate; a plain `SUM(sal)` without a window would instead collapse the
whole table to one number.

Because two employees can share the same salary, the window orders by `sal` first and
then by `empno`, so the accumulation is deterministic even across ties.

## Task

For every employee, report the name, salary, and the running total of salary
accumulated in order of increasing salary (ties broken by `empno`).

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename` | employee name |
| 2 | `sal` | that employee's salary |
| 3 | `running_total` | sum of all salaries up to and including this row |

**Order matters.** Return the rows `ORDER BY sal, empno` (the same order the total
accumulates in).

## Worked example

Three employees ordered by salary:

| ename | sal |
|---|---|
| SMITH | 800 |
| JAMES | 950 |
| ADAMS | 1100 |

The running total is `800`, then `800 + 950 = 1750`, then `1750 + 1100 = 2850`:

| ename | sal | running_total |
|---|---|---|
| SMITH | 800 | 800 |
| JAMES | 950 | 1750 |
| ADAMS | 1100 | 2850 |

On the canonical 14-row EMP table the first row is `SMITH, 800, 800` and the final row
is `KING, 5000, 29025` (the grand total of all salaries).
