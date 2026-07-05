# Build a Sentence by Concatenating Columns

Sometimes you want several columns presented as one piece of text. String
concatenation joins values end to end, and you can splice in fixed text between
them. The portable way to do this across engines is the `CONCAT(...)` function,
which takes any number of arguments and returns them joined into a single string.
(The SQL-standard `||` operator does the same thing but is not supported
everywhere, so we use `CONCAT` here.)

## Task

For each employee in department 10 (`deptno = 10`), produce a single column named
`msg` that reads `<ENAME> WORKS AS A <JOB>` — the employee name, then the literal
phrase ` WORKS AS A `, then the job title.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `msg` | the sentence `<ename> WORKS AS A <job>` |

Order of rows does not matter. Mind the exact spacing and capitalization of the
phrase ` WORKS AS A ` (a leading and trailing space, all uppercase).

## Worked example

Department 10 contains `CLARK` (MANAGER), `KING` (PRESIDENT), and `MILLER` (CLERK).
Concatenating each name with the phrase and job yields:

| msg |
|---|
| CLARK WORKS AS A MANAGER |
| KING WORKS AS A PRESIDENT |
| MILLER WORKS AS A CLERK |
