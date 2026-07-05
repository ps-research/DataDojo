# Filter Names and Jobs by Pattern

`LIKE` matches a string against a pattern. The wildcard `%` stands for *any run of
characters* (including none), so `'%I%'` matches any value containing the letter `I`
anywhere, and `'%ER'` matches any value that *ends* with `ER`. When you combine
several conditions, remember that `AND` binds more tightly than `OR`: wrap an `OR`
group in parentheses so it is evaluated as one unit alongside the other conditions.

## Task

Among employees in department `10` or `20`, return the name and job of those whose
**name contains the letter `I`** or whose **job ends in `ER`**.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename` | employee name |
| 2 | `job` | employee job title |

Row order does not matter.

## Worked example

From the department 10 and 20 employees:

| ename | job |
|-------|-----|
| SMITH | CLERK |
| JONES | MANAGER |
| SCOTT | ANALYST |
| KING | PRESIDENT |

the query keeps:

| ename | job |
|-------|-----|
| SMITH | CLERK |
| JONES | MANAGER |
| KING | PRESIDENT |

`SMITH` and `KING` qualify because their names contain `I`; `JONES` qualifies because
`MANAGER` ends in `ER`. `SCOTT` is dropped: no `I` in the name and `ANALYST` does not
end in `ER`.
