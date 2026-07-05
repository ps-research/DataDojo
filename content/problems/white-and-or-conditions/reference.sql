-- Recipe 1.3 tutorial: combine several conditions in one WHERE clause.
-- A row qualifies if it is in department 10, OR earns a commission, OR is a
-- low-paid (<= 2000) department-20 employee. AND binds more tightly than OR, so
-- "sal <= 2000 AND deptno = 20" is one grouped condition among the OR branches.
SELECT *
FROM emp
WHERE deptno = 10
   OR comm IS NOT NULL
   OR sal <= 2000 AND deptno = 20;
