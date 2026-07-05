# Filter on a Column Alias

You might expect to define an alias in the `SELECT` list and then reuse it in the
`WHERE` clause of the same query. It does not work, because SQL logically evaluates
`WHERE` *before* the select list, so the alias does not exist yet at filter time.
The standard fix is to wrap the aliased query in a *derived table* (an inline view):
the alias becomes a genuine column of that subquery, and an outer `WHERE` can filter
on it.

## Task

Starting from the salaries and commissions aliased as `salary` and `commission`,
return the rows where `salary` is less than `5000`. You must filter using the alias
`salary`, which means wrapping the aliased projection in a derived table.

## Output columns

| # | Column | Source |
|---|--------|--------|
| 1 | `salary` | `sal` |
| 2 | `commission` | `comm` |

Order of rows does not matter.

## Worked example

The inner query aliases every employee's `sal` as `salary` and `comm` as
`commission`. The outer `WHERE salary < 5000` then drops only the president `KING`,
whose salary is exactly `5000`:

| ename (context) | salary | commission | kept? |
|---|---|---|---|
| SMITH | 800 | (NULL) | yes |
| ALLEN | 1600 | 300 | yes |
| KING | 5000 | (NULL) | no — 5000 is not < 5000 |

On the visible fixture, thirteen of the fourteen employees remain (everyone except
`KING`).
