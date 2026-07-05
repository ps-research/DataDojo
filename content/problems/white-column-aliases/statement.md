# Rename Columns with AS

Raw column names are not always self-explanatory. `SAL` and `COMM` are terse; a
reader may not know they mean salary and commission. The `AS` keyword attaches an
*alias* to a column in the select list, so the result set is labelled with the name
you choose. The stored data is untouched; only the output header changes.

## Task

Return two columns for every employee: the salary aliased as `salary` and the
commission aliased as `commission`.

## Output columns

| # | Column | Source |
|---|--------|--------|
| 1 | `salary` | `sal` |
| 2 | `commission` | `comm` |

Order of rows does not matter. A `NULL` commission stays `NULL` in the output.

## Worked example

For `ALLEN` (`sal = 1600`, `comm = 300`) the query returns
`(salary = 1600, commission = 300)`. For `SMITH` (`sal = 800`, `comm = NULL`) it
returns `(salary = 800, commission = NULL)`. The values are identical to the
underlying columns; only the headers now read `salary` and `commission`. On the
visible fixture all fourteen employees are returned.
