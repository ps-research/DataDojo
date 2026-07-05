-- No PRODUCT window aggregate exists, so build the product from a running SUM of
-- logarithms: EXP(SUM(LN(sal))) equals the product of the sal values. ROUND to 2
-- decimals to shed the tiny floating error EXP/LN introduce.
SELECT empno, ename, sal,
       ROUND(EXP(SUM(LN(sal)) OVER (ORDER BY sal, empno)), 2) AS running_prod
FROM emp
WHERE deptno = 10
ORDER BY sal, empno;
