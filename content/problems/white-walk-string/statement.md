# Walking a String Character by Character

SQL has no loop, but you can *walk* a string by cross-joining it to a table of integers — a
"numbers" or pivot table — and pulling one character per position with `SUBSTR`. The pivot
table `t10` supplies the positions `1..10`; the filter `pos <= length(name)` keeps only the
positions that actually exist in the string, and `SUBSTR(name, pos, 1)` returns the single
character sitting at each position.

## Task

Return the letters of the employee name **KING**, one character per row.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `c` | one character of the name, at position 1, 2, 3, ... |

Order does not matter (each row is one character of the name).

## Worked example

`KING` has length 4, so positions `1..4` survive the `pos <= length` filter and positions
`5..10` are discarded. `SUBSTR('KING', 1, 1)` is `K`, position 2 is `I`, and so on.

Expected rows:

| c |
|---|
| K |
| I |
| N |
| G |
