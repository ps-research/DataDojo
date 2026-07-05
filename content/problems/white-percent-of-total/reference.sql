-- CASE inside SUM totals only department 10's salaries, then divides by the grand total
-- for its share. The 100.0 (decimal, not integer 100) forces real division so the
-- ratio is not truncated to 0 by integer division on SQLite/PostgreSQL. Round to 2.
SELECT ROUND(SUM(CASE WHEN deptno = 10 THEN sal END) * 100.0 / SUM(sal), 2) AS pct
FROM emp;
