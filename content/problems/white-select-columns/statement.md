# Select Specific Columns

`SELECT *` is convenient, but most of the time you want just a few columns. Listing
them explicitly is called *projection*: you name the columns you care about, and the
result contains only those, in exactly the order you write them. This keeps output
narrow and lets you control the column layout.

## Task

For every employee, return only their name, department number, and salary, in that
column order.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename` | employee name |
| 2 | `deptno` | department number |
| 3 | `sal` | salary |

Order of rows does not matter; the **column** order above is required.

## Worked example

From an `emp` row of
`(empno=7782, ename=CLARK, job=MANAGER, mgr=7839, hiredate=2006-06-09, sal=2450, comm=NULL, deptno=10)`,
the projection keeps only three fields and returns `(CLARK, 10, 2450)`. Across the
visible fixture you get all fourteen employees, each reduced to these three columns.
