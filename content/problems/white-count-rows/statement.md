# Counting the Rows in a Table

The simplest aggregate answers the question "how many rows are there?". `COUNT(*)`
collapses an entire table into a single number by counting every row, whether or not
any of its columns are NULL. This is different from `COUNT(comm)`, which would count
only the employees who actually have a commission; `COUNT(*)` always counts the whole
row.

## Task

Report the total number of employees in the `emp` table as a single row.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `total_employees` | the number of rows in `emp` |

Order does not matter (the result is a single row).

## Worked example

Given a tiny `emp` of three rows:

| empno | ename | comm |
|---|---|---|
| 7001 | SMITH | (NULL) |
| 7002 | ALLEN | 300 |
| 7003 | WARD | (NULL) |

`COUNT(*)` returns `3` — all three rows count, even the two with a NULL commission.

On the canonical 14-row EMP table the answer is:

| total_employees |
|---|
| 14 |
