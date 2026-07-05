# Full Outer Join: Keep Both Sides

A *full outer join* returns the matched rows plus the **unmatched rows from both tables**:
departments that have no employees, and employees whose department is missing. Because several
engines lack a native `FULL OUTER JOIN`, a portable way to build one is to `UNION` two
`LEFT JOIN`s pointed in opposite directions — emp-to-dept for every employee, and dept-to-emp
for every department. `UNION` then removes the matched rows that both halves produce.

## Task

List each department number, department name, and employee name, keeping departments that have
**no** employees (their `ename` is `NULL`) as well as any employees whose `deptno` matches no
department.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `deptno` | department number (`NULL` if the employee has no department) |
| 2 | `dname` | department name (`NULL` if the employee has no department) |
| 3 | `ename` | employee name (`NULL` for a department with no employees) |

Order does not matter.

## Worked example

The canonical data has 14 employees, all assigned to departments 10, 20 or 30, plus department
40 (`OPERATIONS`) which has no one. The emp-side left join yields the 14 employee rows; the
dept-side left join additionally yields `40, OPERATIONS, NULL`. Unioned together that is 15
distinct rows.

Sample of the expected rows:

| deptno | dname | ename |
|---|---|---|
| 10 | ACCOUNTING | CLARK |
| ... | ... | ... |
| 30 | SALES | WARD |
| 40 | OPERATIONS | (NULL) |
