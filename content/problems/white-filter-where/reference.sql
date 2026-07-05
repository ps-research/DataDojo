-- Recipe 1.2 tutorial: keep only the rows that match a condition.
-- The WHERE clause is evaluated once per row; a row is returned only when the
-- predicate is true. Here we keep employees in department 10.
SELECT *
FROM emp
WHERE deptno = 10;
