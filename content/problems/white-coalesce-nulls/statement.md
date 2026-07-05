# Turn Missing Commissions Into Zero

A `NULL` marks a value that is *unknown or absent*, not zero. When a report needs a
real number in every row, use `COALESCE(x, fallback)`: it returns the first argument
when it is present and the fallback when the first argument is `NULL`. `COALESCE` is
part of standard SQL and behaves the same on every engine, so it is the portable way
to substitute a default for a missing value.

## Task

For every employee in `emp`, return their commission with any missing commission
reported as `0`.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `commission` | `comm` when it is present, otherwise `0` |

Row order does not matter.

## Worked example

Given these three employees:

| ename | comm |
|-------|------|
| ALLEN | 300 |
| SMITH | (null) |
| TURNER | 0 |

the query returns:

| commission |
|------------|
| 300 |
| 0 |
| 0 |

Note that `SMITH` (an unknown commission) and `TURNER` (a real commission of `0`)
both come out as `0` here, but for different reasons: one was substituted, the other
was already zero.
