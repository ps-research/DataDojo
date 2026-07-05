# Computing a Percentage of a Total

To express one part as a percentage of a whole, aggregate the part and the whole in the
same query and divide. A `CASE` expression inside `SUM` acts as a filter that only adds
up the matching rows: `SUM(CASE WHEN deptno = 10 THEN sal END)` totals just department
10's salaries, while `SUM(sal)` totals everyone's.

The one trap to know is integer division. In SQLite, PostgreSQL, and several other
engines, `integer / integer` truncates toward zero, so `8750 / 29025` would come out as
`0`. Multiplying by `100.0` (a decimal) instead of `100` forces real division on every
engine, giving the true percentage. The result is rounded to two decimal places.

## Task

Report what percentage of the company's total salary is paid to department 10, rounded
to two decimal places, as a single row.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `pct` | department 10 salary as a percentage of all salary, rounded to 2 decimals |

Order does not matter (the result is a single row).

## Worked example

Suppose four employees, one of them in department 10:

| ename | deptno | sal |
|---|---|---|
| CLARK | 10 | 2450 |
| SMITH | 20 | 800 |
| ALLEN | 30 | 1600 |
| WARD | 30 | 1250 |

Department 10's salary is `2450`; the total is `2450 + 800 + 1600 + 1250 = 6100`. The
percentage is `2450 * 100.0 / 6100 = 40.16`:

| pct |
|---|
| 40.16 |

On the canonical 14-row EMP table, department 10 pays `8750` of the `29025` total, so
the answer is:

| pct |
|---|
| 30.15 |
