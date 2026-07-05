# OR Logic in an Outer Join

With an outer join, *where* you put a condition on the optional table changes the answer.
A `LEFT JOIN dept -> emp` keeps every department even when no employee matches, filling
the employee columns with NULL. If you place `(e.deptno = 10 OR e.deptno = 20)` in the
`ON` clause, it only limits which employees are allowed to match; all four departments
still appear, and departments 30 and 40 come back with NULL employee names.

Move that same `OR` into a `WHERE` clause and it filters the joined result *after* the
join, throwing away the rows where `e.deptno` is NULL and collapsing the outer join into
an ordinary inner join. Keeping the predicate in `ON` is the whole point of this recipe.

## Task

List every department together with the names of its employees in departments 10 and 20
only. Departments 30 and 40 must still appear, but with no employee name (NULL). Keep the
join condition, including the OR, in the `ON` clause.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename` | employee name, or NULL for a department with no matching employee |
| 2 | `deptno` | department number |
| 3 | `dname` | department name |
| 4 | `loc` | department location |

**Order matters.** Return the rows `ORDER BY deptno, ename`.

## Worked example

Two employees in department 10 and one department (30) with none, joined:

| ename | deptno | dname | loc |
|---|---|---|---|
| CLARK | 10 | ACCOUNTING | NEW YORK |
| KING | 10 | ACCOUNTING | NEW YORK |
| (NULL) | 30 | SALES | CHICAGO |

Department 30 still appears because the OR lives in the `ON` clause; its employees simply
do not satisfy `deptno = 10 OR deptno = 20`, so `ename` is NULL.

On the canonical data the result has 10 rows: three for department 10 (`CLARK, KING,
MILLER`), five for department 20 (`ADAMS, FORD, JONES, SCOTT, SMITH`), then one NULL-name
row each for department 30 (`SALES`) and department 40 (`OPERATIONS`).
