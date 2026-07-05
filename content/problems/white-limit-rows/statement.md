# Cap the Number of Rows with LIMIT

When you only want to peek at a handful of rows, `LIMIT n` returns at most `n` of
them. One subtlety: `LIMIT` by itself makes no promise about *which* rows you get —
the database may return them in any order, and that order can change between runs or
engines. To get a stable, repeatable "first n," pair `LIMIT` with an `ORDER BY` so
the rows are ranked before the cap is applied.

## Task

Return the five employees with the smallest `empno` values. Order the rows by
`empno` ascending, then keep only the first five.

## Output columns

All eight columns of `emp`, in natural order: `empno`, `ename`, `job`, `mgr`,
`hiredate`, `sal`, `comm`, `deptno`.

**Order matters.** `ORDER BY empno ASC`, then `LIMIT 5`.

## Worked example

Suppose `emp` held employee numbers `7369, 7499, 7521, 7566, 7654, 7698, 7782`.
Ordering ascending and limiting to five keeps the first five and drops `7698` and
`7782`:

| empno | ename |
|---|---|
| 7369 | SMITH |
| 7499 | ALLEN |
| 7521 | WARD |
| 7566 | JONES |
| 7654 | MARTIN |

These are exactly the five rows returned on the visible fixture.
