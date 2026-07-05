# See Every Row and Column

The quickest way to inspect a table you have never seen is to ask for all of it.
In SQL, the star (`*`) in the select list is shorthand for "every column," and a
query with no `WHERE` clause returns every row. Put together, `SELECT * FROM emp`
hands back the entire table.

## Task

Return every row and every column of the `emp` table, unchanged.

## Output columns

The eight columns of `emp`, in their natural order:

| # | Column |
|---|--------|
| 1 | `empno` |
| 2 | `ename` |
| 3 | `job` |
| 4 | `mgr` |
| 5 | `hiredate` |
| 6 | `sal` |
| 7 | `comm` |
| 8 | `deptno` |

Order does not matter.

## Worked example

Given a tiny two-row version of `emp`:

| empno | ename | job | mgr | hiredate | sal | comm | deptno |
|---|---|---|---|---|---|---|---|
| 7782 | CLARK | MANAGER | 7839 | 2006-06-09 | 2450 | (NULL) | 10 |
| 7839 | KING | PRESIDENT | (NULL) | 2006-11-17 | 5000 | (NULL) | 10 |

The query returns both rows exactly as stored, including the `NULL` commissions
and `KING`'s `NULL` manager. On the visible fixture the full canonical table of 14
employees is returned.
