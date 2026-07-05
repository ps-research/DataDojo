-- Recipe 1.9 tutorial: cap the number of rows returned.
-- LIMIT n returns at most n rows. On its own, LIMIT gives no guarantee about
-- WHICH rows you get, so we ORDER BY empno first to make the result deterministic
-- and repeatable: the five employees with the smallest employee numbers.
SELECT *
FROM emp
ORDER BY empno
LIMIT 5;
