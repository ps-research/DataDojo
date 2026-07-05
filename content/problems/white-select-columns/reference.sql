-- Recipe 1.4 tutorial: choose exactly the columns you need.
-- Instead of "*", list the columns you want in the select list; the result has
-- only those columns, in the order you name them.
SELECT ename, deptno, sal
FROM emp;
