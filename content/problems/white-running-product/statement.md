# Building a Running Product

A running product is like a running total, but the values are multiplied together
instead of added. SQL has `SUM(...) OVER (...)` but no `PRODUCT(...) OVER (...)`, so we
use a logarithm trick: because `ln(a * b) = ln(a) + ln(b)`, adding up logarithms and
then exponentiating gives the product. That is, `EXP(SUM(LN(sal)) OVER (...))` produces
the running product of `sal`.

Floating-point `EXP`/`LN` introduce a tiny rounding error, so the result is rounded to
two decimal places to recover the exact product.

## Task

For the employees in department 10, report the running product of salary, accumulated
in order of increasing salary (ties broken by `empno`).

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `empno` | employee number |
| 2 | `ename` | employee name |
| 3 | `sal` | that employee's salary |
| 4 | `running_prod` | product of all salaries up to and including this row, rounded to 2 decimals |

**Order matters.** Return the rows `ORDER BY sal, empno`.

## Worked example

Department 10 has three employees, ordered by salary:

| empno | ename | sal |
|---|---|---|
| 7934 | MILLER | 1300 |
| 7782 | CLARK | 2450 |
| 7839 | KING | 5000 |

The running product is `1300`, then `1300 * 2450 = 3185000`, then
`3185000 * 5000 = 15925000000`:

| empno | ename | sal | running_prod |
|---|---|---|---|
| 7934 | MILLER | 1300 | 1300.0 |
| 7782 | CLARK | 2450 | 3185000.0 |
| 7839 | KING | 5000 | 15925000000.0 |
