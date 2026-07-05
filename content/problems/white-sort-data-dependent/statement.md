# Sort by a Value That Depends on the Row

Sometimes the column you sort on changes from row to row. A `CASE` expression inside
`ORDER BY` lets you choose the sort value per row: here, salespeople are ranked by
their **commission** while everyone else is ranked by **salary**. Because a
salesperson's commission can be missing, we pin any such rows last (a portable
`NULL`-handling flag) and use `empno` as a final tie-breaker so the order is fully
determined.

## Task

Return each employee's name, salary, job, and commission, ordered by a data-dependent
key: for a `SALESMAN` sort on `comm`, for everyone else sort on `sal`. Any salesperson
whose commission is missing sorts last; break remaining ties by `empno` ascending.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename` | employee name |
| 2 | `sal` | salary |
| 3 | `job` | employee job title |
| 4 | `comm` | commission (may be null) |

**Order matters:** ascending by the per-row key (commission for salespeople, salary
otherwise), missing keys last, then `empno` ascending.

## Worked example

Given:

| ename | sal | job | comm |
|-------|-----|-----|------|
| TURNER | 1500 | SALESMAN | 0 |
| SMITH | 800 | CLERK | (null) |
| ALLEN | 1600 | SALESMAN | 300 |

TURNER and ALLEN sort by commission (`0`, `300`); SMITH, a clerk, sorts by salary
(`800`). Ordered by the per-row key `0 < 300 < 800`:

| ename | sal | job | comm |
|-------|-----|-----|------|
| TURNER | 1500 | SALESMAN | 0 |
| ALLEN | 1600 | SALESMAN | 300 |
| SMITH | 800 | CLERK | (null) |
