-- Windowed SUM accumulates salary in (sal, empno) order. The ORDER BY inside
-- OVER defines the running-total order, and the outer ORDER BY presents the rows the
-- same way. empno breaks salary ties so the result is deterministic.
SELECT ename, sal,
       SUM(sal) OVER (ORDER BY sal, empno) AS running_total
FROM emp
ORDER BY sal, empno;
