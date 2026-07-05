# Averaging a Nullable Column

Aggregate functions skip NULLs. `AVG(comm)` sums the commissions and divides by the
count of employees who *have* a commission, ignoring everyone whose `comm` is NULL. That
is often not what you want: if an employee earns no commission, their contribution to the
average commission should be zero, not "excluded".

Wrapping the column in `COALESCE(comm, 0)` turns each NULL into `0` before averaging, so
those employees are counted in the denominator and pull the average down, giving the true
average commission across the whole group.

## Task

Report the average commission for the employees in department 30, treating a NULL
commission as `0`.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `avg_comm` | the average of `COALESCE(comm, 0)` over department 30 |

Order does not matter (the result is a single row).

## Worked example

Department 30 has six employees; three earn no commission:

| ename | comm |
|---|---|
| ALLEN | 300 |
| WARD | 500 |
| MARTIN | 1400 |
| BLAKE | (NULL) |
| TURNER | 0 |
| JAMES | (NULL) |

Coalescing the NULLs to `0`, the six values are `300, 500, 1400, 0, 0, 0`, summing to
`2200`. Dividing by all six rows gives `2200 / 6 = 366.6666666666667`:

| avg_comm |
|---|
| 366.6666666666667 |

(By contrast, a plain `AVG(comm)` would divide `2200` by only the four non-NULL rows and
report `550` — the wrong answer for this question.)
