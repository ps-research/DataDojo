# Sort Commissions With Nulls Last

Engines disagree on where `NULL`s land in an `ORDER BY`: some place them first, some
last, and the `NULLS LAST` keyword is not available everywhere (MySQL, for one, does
not accept it). The portable way to pin `NULL`s to a chosen end is to sort first on a
`CASE` flag that is `0` for real values and `1` for `NULL`, and only then on the value
itself. That guarantees the same placement on every engine.

## Task

Return each employee's name, salary, and commission, ordered so that employees **with
a commission come first** (lowest commission to highest), followed by employees with
**no commission**. Break ties by name.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename` | employee name |
| 2 | `sal` | salary |
| 3 | `comm` | commission (may be null) |

**Order matters:** non-null commissions first in ascending order, then the null
commissions; within the nulls, order by `ename` ascending.

## Worked example

Given:

| ename | sal | comm |
|-------|-----|------|
| ALLEN | 1600 | 300 |
| BLAKE | 2850 | (null) |
| TURNER | 1500 | 0 |
| ADAMS | 1100 | (null) |

the query returns the real commissions in order, then the nulls sorted by name:

| ename | sal | comm |
|-------|-----|------|
| TURNER | 1500 | 0 |
| ALLEN | 1600 | 300 |
| ADAMS | 1100 | (null) |
| BLAKE | 2850 | (null) |
