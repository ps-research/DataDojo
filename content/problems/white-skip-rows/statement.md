# Returning Every Other Row

Table rows have no built-in position, so to pick "every other row" you first have to
number them. `ROW_NUMBER() OVER (ORDER BY ename)` assigns `1, 2, 3, ...` to the rows in
name order. Wrapping that in a subquery lets you filter on the number: keeping the odd
positions with `rn % 2 = 1` returns the 1st, 3rd, 5th, and so on.

The `%` (modulo) operator returns the remainder of a division and is portable across all
target engines; `rn % 2` is `1` for odd row numbers and `0` for even ones.

## Task

Number the employees by name (`ename` ascending) and return the name of every
odd-numbered employee: the 1st, 3rd, 5th, and so on.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename` | name of an odd-positioned employee (positions counted in `ename` order) |

**Order matters.** Return the rows `ORDER BY ename`.

## Worked example

Five employees in name order get numbered `1..5`:

| rn | ename |
|---|---|
| 1 | ADAMS |
| 2 | ALLEN |
| 3 | BLAKE |
| 4 | CLARK |
| 5 | FORD |

Keeping the odd numbers (`rn % 2 = 1`) leaves rows 1, 3, and 5:

| ename |
|---|
| ADAMS |
| BLAKE |
| FORD |

On the canonical 14-row EMP table the seven rows returned are `ADAMS, BLAKE, FORD,
JONES, MARTIN, SCOTT, TURNER`.
