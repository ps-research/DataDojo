# Avoiding an Accidental Cartesian Product

When you list two tables in the `FROM` clause you must connect them with a **join predicate**.
If you leave it out, the database pairs every row of one table with every row of the other — a
*Cartesian product* — so three employees against four departments would return twelve rows
instead of three. The fix is to require the shared key to match (`d.deptno = e.deptno`) so each
employee lines up with only its own department.

## Task

For every employee in **department 10**, return the employee name together with that
department's location. Join `emp` to `dept` on `deptno`.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename` | employee name |
| 2 | `loc` | location of the employee's department |

Order does not matter.

## Worked example

Department 10 is `ACCOUNTING`, located in `NEW YORK`, and holds CLARK, KING and MILLER. With
the `d.deptno = e.deptno` predicate in place, each employee is matched only to `NEW YORK`.
Drop that predicate and each name would be repeated once per department (CLARK / NEW YORK,
CLARK / DALLAS, CLARK / CHICAGO, ...) — the Cartesian product.

Expected rows:

| ename | loc |
|---|---|
| CLARK | NEW YORK |
| KING | NEW YORK |
| MILLER | NEW YORK |
