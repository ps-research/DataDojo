-- Rank salaries from the top with DENSE_RANK (no gaps), then keep the five highest
-- distinct salaries. Ties share a rank, so every employee at a qualifying salary is
-- returned -- unlike LIMIT 5, which would arbitrarily drop a tied employee.
SELECT ename, sal
FROM (
  SELECT ename, sal, DENSE_RANK() OVER (ORDER BY sal DESC) AS dr
  FROM emp
) x
WHERE dr <= 5
ORDER BY sal DESC, ename;
