# Join Employees to Their Location

Related facts often live in separate tables. `emp` records which department each
person is in; `dept` records where each department sits. To pair a person with their
location you **join** the two tables on their shared key, `deptno`, keeping only the
combinations where the department numbers match (an equi-join). The matching
condition is what prevents every employee from being paired with every department.

## Task

Return the name of each employee in department `10` together with the location of
that department.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename` | employee name |
| 2 | `loc` | the location of the employee's department |

Row order does not matter.

## Worked example

Department 10 is `ACCOUNTING`, located in `NEW YORK`, and holds three employees.
Joining each to their department's location:

| ename | loc |
|-------|-----|
| CLARK | NEW YORK |
| KING | NEW YORK |
| MILLER | NEW YORK |
