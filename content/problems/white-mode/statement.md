# Finding the Mode of a Column

The mode of a set of values is the value that appears most often. There is no built-in
`MODE()` in portable SQL, so we build it in three moves: `GROUP BY sal` with `COUNT(*)`
to find how often each salary occurs, then `DENSE_RANK() OVER (ORDER BY cnt DESC)` to
rank the salaries by frequency, then keep the rows with rank `1`.

Using `DENSE_RANK` rather than `ROW_NUMBER` matters: if two different salaries are tied
as the most frequent, they share rank 1 and both are returned, which is the correct
statistical behaviour (a set can have more than one mode).

## Task

Find the mode (the most frequently occurring salary) among the employees in department
20. Return every salary that ties for most frequent.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `sal` | a salary that occurs most frequently in department 20 |

Order does not matter.

## Worked example

The salaries in department 20 are:

| sal |
|---|
| 800 |
| 1100 |
| 2975 |
| 3000 |
| 3000 |

The value `3000` occurs twice; every other salary occurs once. So the mode is:

| sal |
|---|
| 3000 |

On the canonical 14-row EMP table the single row returned is `3000`.
