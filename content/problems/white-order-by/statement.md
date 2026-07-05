# Sort Department 10 by Salary

Query results have no inherent order; if you need the rows in a particular sequence
you must ask for it with `ORDER BY`. `ORDER BY sal ASC` returns rows from the lowest
salary to the highest (`ASC` is the default and can be omitted; `DESC` reverses it).

## Task

Return the name, job, and salary of every employee in department `10`, ordered by
salary from lowest to highest.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename` | employee name |
| 2 | `job` | employee job title |
| 3 | `sal` | salary |

**Order matters:** rows must be sorted by `sal` ascending.

## Worked example

Department 10 contains:

| ename | job | sal |
|-------|-----|-----|
| CLARK | MANAGER | 2450 |
| KING | PRESIDENT | 5000 |
| MILLER | CLERK | 1300 |

Sorted by salary ascending, the query returns:

| ename | job | sal |
|-------|-----|-----|
| MILLER | CLERK | 1300 |
| CLARK | MANAGER | 2450 |
| KING | PRESIDENT | 5000 |
