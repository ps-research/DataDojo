# Counting a Character Inside a String

To count how many times a character occurs in a string, compare the string's length before and
after stripping that character out with `REPLACE`. The difference is how many characters were
removed; dividing by the length of the search string generalizes the trick to multi-character
needles (dividing by 1 for a single character).

## Task

Count how many **commas** appear in the string `'10,CLARK,MANAGER'`.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `cnt` | number of commas in the string |

Order does not matter (a single row).

## Worked example

`'10,CLARK,MANAGER'` is 16 characters long. `REPLACE(..., ',', '')` deletes the commas, leaving
`'10CLARKMANAGER'` at 14 characters. `16 - 14 = 2`, and dividing by `LENGTH(',') = 1` gives `2`.

Expected rows:

| cnt |
|---|
| 2 |
