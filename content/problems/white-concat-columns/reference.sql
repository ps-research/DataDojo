-- Recipe 1.7 tutorial: stitch several columns into one string.
-- CONCAT(a, b, c, ...) joins its arguments into a single text value; it is the
-- portable spelling of string concatenation (the SQL-standard || operator works
-- on some engines but not all). Here name, a fixed phrase, and job become one
-- readable sentence per department-10 employee.
SELECT CONCAT(ename, ' WORKS AS A ', job) AS msg
FROM emp
WHERE deptno = 10;
