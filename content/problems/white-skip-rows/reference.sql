-- Number the rows deterministically with ROW_NUMBER in name order, then keep the
-- odd positions. The % modulo operator is portable across all five engines.
SELECT ename
FROM (
  SELECT ename, ROW_NUMBER() OVER (ORDER BY ename) AS rn
  FROM emp
) x
WHERE rn % 2 = 1
ORDER BY ename;
