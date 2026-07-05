# Find Rows Where a Column Is NULL

`NULL` represents an unknown or missing value, and it behaves unlike any real value.
In particular, comparisons with `=` never succeed against `NULL` — even
`comm = NULL` is never true. To test whether a column has no value, SQL provides the
dedicated `IS NULL` predicate (and its opposite, `IS NOT NULL`). Note that `NULL` is
not the same as `0`: an employee who genuinely earns a `0` commission is a known
value, not a missing one.

## Task

Return every column of `emp` for the employees whose commission (`comm`) is `NULL` —
that is, employees with no recorded commission at all.

## Output columns

All eight columns of `emp`, in natural order: `empno`, `ename`, `job`, `mgr`,
`hiredate`, `sal`, `comm`, `deptno`.

Order does not matter.

## Worked example

| ename | comm | returned? |
|---|---|---|
| SMITH | (NULL) | yes — no commission recorded |
| ALLEN | 300 | no — has a commission |
| TURNER | 0 | no — 0 is a real value, not NULL |
| JONES | (NULL) | yes |

Watch `TURNER`: a commission of `0` is a known value, so `IS NULL` excludes it. On
the visible fixture, ten of the fourteen employees have a `NULL` commission.
