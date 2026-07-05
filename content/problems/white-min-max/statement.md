# Finding the Min and Max

`MIN` and `MAX` return the smallest and largest value in a column. You can compute both in a
single pass by placing the two aggregates in one `SELECT`. Both ignore `NULL`s.

## Task

Return the lowest and highest salary among all employees, in that order.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `min_sal` | lowest `sal` |
| 2 | `max_sal` | highest `sal` |

Order does not matter (a single row).

## Worked example

Across the 14 canonical employees the lowest salary is SMITH's `800` and the highest is KING's
`5000`.

Expected rows:

| min_sal | max_sal |
|---|---|
| 800 | 5000 |
