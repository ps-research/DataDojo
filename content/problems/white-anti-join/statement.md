# Departments With No Employees

To find rows in one table that have **no** matching row in another, run a `LEFT OUTER JOIN`
from the table you want to keep to the other table, then filter to the rows where the
joined side came back `NULL`. This is called an *anti-join*: the outer join keeps every
row of the left table, and a `NULL` on the right marks the ones that had no match. A plain
inner (equi-)join would hide exactly these rows, and unlike a bare `NOT IN` on the keys, the
outer join lets you return every column of the unmatched rows.

## Task

Return every department in `dept` that has **no** employee in `emp`. Return all department
columns.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `deptno` | department number |
| 2 | `dname` | department name |
| 3 | `loc` | department location |

Order does not matter.

## Worked example

Using the canonical `DEPT`/`EMP` tables, departments 10, 20 and 30 each have employees, but
department 40 (`OPERATIONS`, `BOSTON`) has none — no `EMP` row carries `deptno = 40`. The
left join therefore produces a single `OPERATIONS` row whose employee side is all `NULL`, and
the `WHERE e.deptno IS NULL` filter keeps only that row.

Expected rows:

| deptno | dname | loc |
|---|---|---|
| 40 | OPERATIONS | BOSTON |
