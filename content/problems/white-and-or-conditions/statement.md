# Combine Conditions with AND and OR

Real filters usually mix several tests. `AND` requires both sides to be true;
`OR` requires at least one. When you mix them, precedence matters: SQL evaluates
`AND` before `OR`, just as multiplication comes before addition in arithmetic. So
`A OR B AND C` means `A OR (B AND C)`, not `(A OR B) AND C`.

## Task

Return every column of `emp` for each employee who satisfies **any** of the
following:

- works in department 10 (`deptno = 10`), **or**
- earns a commission (`comm` is not null), **or**
- is paid `2000` or less **and** works in department 20 (`sal <= 2000 AND deptno = 20`).

Because `AND` binds tighter than `OR`, the third bullet is a single grouped
condition sitting alongside the first two.

## Output columns

All eight columns of `emp`, in natural order: `empno`, `ename`, `job`, `mgr`,
`hiredate`, `sal`, `comm`, `deptno`.

Order does not matter.

## Worked example

| empno | ename | sal | comm | deptno | qualifies? |
|---|---|---|---|---|---|
| 7782 | CLARK | 2450 | (NULL) | 10 | yes — department 10 |
| 7499 | ALLEN | 1600 | 300 | 30 | yes — has a commission |
| 7369 | SMITH | 800 | (NULL) | 20 | yes — sal <= 2000 and dept 20 |
| 7566 | JONES | 2975 | (NULL) | 20 | no — dept 20 but sal > 2000, no commission |

`JONES` fails every branch and is dropped. On the visible fixture this filter
returns nine of the fourteen employees.
