# Departments With No Employees

The `EXCEPT` set operator returns the rows produced by the first query that are **not**
produced by the second -- a set difference. `SELECT deptno FROM dept EXCEPT SELECT
deptno FROM emp` therefore yields the department numbers that exist in `dept` but never
appear in `emp`: the departments with nobody assigned. Like other set operators,
`EXCEPT` removes duplicates and requires the two queries to have matching columns.

## Task

Return the department numbers that appear in `dept` but have no matching employee in
`emp`.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `deptno` | a department number with no employees |

Row order does not matter.

## Worked example

`dept` lists departments `10, 20, 30, 40`. Employees are assigned to `10, 20,` and
`30` only. Subtracting the departments that appear in `emp` leaves:

| deptno |
|--------|
| 40 |

## Note

`EXCEPT` is supported by SQLite, DuckDB, PostgreSQL, and SQL Server, and by MySQL
8.0.31 and later. The MySQL reference expresses the same set difference with `NOT
EXISTS` so it runs on every MySQL version.
