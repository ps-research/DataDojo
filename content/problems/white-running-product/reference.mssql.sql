-- SQL Server has no LN() function. LOG() with a single argument is the natural log.
SELECT empno, ename, sal,
       ROUND(EXP(SUM(LOG(sal)) OVER (ORDER BY sal, empno)), 2) AS running_prod
FROM emp
WHERE deptno = 10
ORDER BY sal, empno;
