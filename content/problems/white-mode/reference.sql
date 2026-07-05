-- Count each salary, rank the counts descending with DENSE_RANK, keep rank 1.
-- DENSE_RANK returns every salary tied for the top frequency, so multi-modal
-- data is handled correctly.
SELECT sal
FROM (
  SELECT sal, DENSE_RANK() OVER (ORDER BY cnt DESC) AS rnk
  FROM (
    SELECT sal, COUNT(*) AS cnt
    FROM emp
    WHERE deptno = 20
    GROUP BY sal
  ) x
) y
WHERE rnk = 1;
