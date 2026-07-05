# Embedding Quotes in String Literals

A single quote (`'`) both opens and closes a string literal, so to put a literal quote
*inside* the string you double it: `''`. Each doubled pair produces one quote character in the
output. The last literal, `''''`, is the tricky case — the outer pair delimits the string and
the inner pair collapses to a single `'`.

## Task

Produce three rows, each a one-column string literal, containing (in any order):

- `g'day mate`
- `beavers' teeth`
- a single quote character `'`

Selecting from `t1` (a one-row pivot table) yields exactly one row per literal.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `qmarks` | a string literal that itself contains a quote |

Order does not matter.

## Worked example

Writing `'g''day mate'` inside the SQL yields the text `g'day mate`; `'beavers'' teeth'` yields
`beavers' teeth`; and `''''` yields a lone `'`.

Expected rows:

| qmarks |
|---|
| g'day mate |
| beavers' teeth |
| ' |
