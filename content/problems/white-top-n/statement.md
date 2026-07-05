# Selecting the Top N with Ties

"Give me the top five salaries" is a question about ranking, not about counting rows.
`DENSE_RANK() OVER (ORDER BY sal DESC)` numbers the salaries from the top down with no
gaps: the highest salary is rank 1, the next distinct salary is rank 2, and so on. Every
employee who earns a rank-`k` salary shares rank `k`. Filtering `dr <= 5` keeps the five
highest *distinct* salaries.

The payoff is correct handling of ties. If two employees share the fifth-highest salary,
both are kept, so the result may contain more than five rows. A blunt `LIMIT 5` would
keep one of them and silently drop the other; `DENSE_RANK` keeps everyone who qualifies.

## Task

Return the name and salary of the employees whose salary is among the five highest
distinct salaries. Include everyone tied at a qualifying salary.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename` | employee name |
| 2 | `sal` | that employee's salary |

**Order matters.** Return the rows `ORDER BY sal DESC, ename ASC`.

## Worked example

Six employees with these salaries produce five distinct salary ranks:

| ename | sal | dense_rank |
|---|---|---|
| KING | 5000 | 1 |
| FORD | 3000 | 2 |
| SCOTT | 3000 | 2 |
| JONES | 2975 | 3 |
| BLAKE | 2850 | 4 |
| CLARK | 2450 | 5 |

FORD and SCOTT both earn `3000`, so they share rank 2; all six rows have a rank `<= 5`
and are returned. Note there are six rows for five ranks, exactly because of the tie.

On the canonical 14-row EMP table the same six rows are returned, in order `KING (5000)`,
`FORD (3000)`, `SCOTT (3000)`, `JONES (2975)`, `BLAKE (2850)`, `CLARK (2450)`.
