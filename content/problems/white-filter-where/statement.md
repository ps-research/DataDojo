# Filter Rows with WHERE

A table usually holds more than you want to look at. The `WHERE` clause is how you
narrow the result to rows that satisfy a condition: SQL tests the predicate against
each row and keeps only the ones for which it is true. A condition like
`deptno = 10` therefore returns only the employees who work in department 10.

## Task

Return every column of `emp`, but only for employees in department 10 (`deptno = 10`).

## Output columns

All eight columns of `emp`, in natural order: `empno`, `ename`, `job`, `mgr`,
`hiredate`, `sal`, `comm`, `deptno`.

Order does not matter.

## Worked example

Given these four employees:

| empno | ename | deptno |
|---|---|---|
| 7782 | CLARK | 10 |
| 7788 | SCOTT | 20 |
| 7839 | KING | 10 |
| 7900 | JAMES | 30 |

Only `CLARK` and `KING` sit in department 10, so the query returns just those two
rows (with all their columns). `SCOTT` (20) and `JAMES` (30) are filtered out. On
the visible fixture, department 10 holds three employees: `CLARK`, `KING`, and
`MILLER`.
