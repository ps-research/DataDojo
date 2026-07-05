# Stack Employees and Departments Together

`UNION ALL` stacks the rows of one query on top of another into a single result. The
branches must line up: the same number of columns, in the same order, with compatible
types. Unlike `UNION`, `UNION ALL` keeps every row, including duplicates -- it does no
extra work to remove them, so it is both faster and the right choice when you want all
rows preserved. The single-row pivot table `t1` is a handy way to emit exactly one
literal separator row.

## Task

Produce one combined list containing: the **name and department** of every employee
in department `10`, then a separator row whose first column is the literal
`----------` and whose department number is `NULL`, then the **name and department
number** of every row in `dept`.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename_and_dname` | an employee name, the separator, or a department name |
| 2 | `deptno` | the associated department number (`NULL` for the separator) |

Row order does not matter.

## Worked example

Department 10 has three employees (`CLARK`, `KING`, `MILLER`), and `dept` has four
rows. Stacked with a separator between, the result is the following eight-row bag:

| ename_and_dname | deptno |
|-----------------|--------|
| CLARK | 10 |
| KING | 10 |
| MILLER | 10 |
| ---------- | (null) |
| ACCOUNTING | 10 |
| RESEARCH | 20 |
| SALES | 30 |
| OPERATIONS | 40 |
