-- AVG ignores NULLs, so COALESCE the NULL commissions to 0 first. That counts the
-- no-commission employees in the denominator and gives the true group average.
SELECT AVG(COALESCE(comm, 0)) AS avg_comm
FROM emp
WHERE deptno = 30;
