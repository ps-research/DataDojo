# Computing an Average

`AVG` returns the arithmetic mean of a numeric column — the sum of the values divided by how
many there are. Like the other aggregate functions it **ignores `NULL`s**: they are neither
added to the total nor counted in the denominator.

## Task

Compute the average salary across all employees.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `avg_sal` | mean of `sal` over all employees |

Order does not matter (a single row).

## Worked example

The 14 canonical salaries sum to `29025`, and `29025 / 14 = 2073.214...`, so `avg_sal` is
approximately `2073.21`.

Expected rows:

| avg_sal |
|---|
| 2073.214285714286 |
