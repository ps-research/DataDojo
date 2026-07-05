# Sort by Department, Then Salary

`ORDER BY` accepts several keys, applied left to right: rows are sorted by the first
key, and only rows that tie on it are ordered by the next key, and so on. Each key
carries its own direction. Here we sort by department ascending, then by salary
descending *within* each department. Because two employees can share the same
salary, we add `empno` as a final tie-breaker so the ordering is fully determined.

## Task

Return every employee ordered by department number ascending, then by salary
descending, then by employee number ascending.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `empno` | employee number |
| 2 | `deptno` | department number |
| 3 | `sal` | salary |
| 4 | `ename` | employee name |
| 5 | `job` | employee job title |

**Order matters:** sort by `deptno` ascending, then `sal` descending, then `empno`
ascending.

## Worked example

Two department-20 analysts earn the same `3000`:

| empno | deptno | sal | ename |
|-------|--------|-----|-------|
| 7788 | 20 | 3000 | SCOTT |
| 7902 | 20 | 3000 | FORD |
| 7566 | 20 | 2975 | JONES |

Within department 20 they sort by salary descending; the two `3000` rows tie, so the
lower `empno` (`7788`, SCOTT) comes first:

| empno | deptno | sal | ename |
|-------|--------|-----|-------|
| 7788 | 20 | 3000 | SCOTT |
| 7902 | 20 | 3000 | FORD |
| 7566 | 20 | 2975 | JONES |
