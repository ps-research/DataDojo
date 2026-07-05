# Label Rows with CASE

`CASE` is SQL's inline IF/ELSE. It checks each `WHEN` condition from top to bottom
and returns the value of the first one that is true; the optional `ELSE` supplies a
fallback when none match. Because the branches are tried in order, put the more
specific conditions first. Here we turn a numeric salary into a human-readable
status label right inside the select list.

## Task

For every employee, return their name, their salary, and a computed `status` label:

- `'UNDERPAID'` when `sal <= 2000`,
- `'OVERPAID'` when `sal >= 4000`,
- `'OK'` otherwise.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `ename` | employee name |
| 2 | `sal` | salary |
| 3 | `status` | one of `UNDERPAID`, `OK`, `OVERPAID` |

Order of rows does not matter.

## Worked example

| ename | sal | status |
|---|---|---|
| SMITH | 800 | UNDERPAID |
| CLARK | 2450 | OK |
| KING | 5000 | OVERPAID |

`SMITH` earns `800` (`<= 2000`), `CLARK` earns `2450` (between the thresholds), and
`KING` earns `5000` (`>= 4000`). On the visible fixture, `KING` is the only employee
labelled `OVERPAID`.
