# Summing a Column

`SUM` adds up all the values in a numeric column and, like the other aggregates, **ignores
`NULL`s** (a column that is entirely `NULL` sums to `NULL`, not `0`). Give the result a clear
alias so the output column has a portable name across engines.

## Task

Return the total of all employee salaries.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `total_sal` | sum of `sal` over all employees |

Order does not matter (a single row).

## Worked example

Adding the 14 canonical salaries (`800 + 1600 + 1250 + ... + 1300`) gives `29025`.

Expected rows:

| total_sal |
|---|
| 29025 |
