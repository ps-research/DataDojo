-- Trimmed mean: exclude every row at the lowest or highest salary, then average
-- what remains. NOT IN is safe here because sal is non-nullable, so MIN(sal) and
-- MAX(sal) are always real values.
SELECT AVG(sal) AS avg_sal
FROM emp
WHERE sal NOT IN (
  (SELECT MIN(sal) FROM emp),
  (SELECT MAX(sal) FROM emp)
);
