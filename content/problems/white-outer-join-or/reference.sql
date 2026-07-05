-- Keep every department with a LEFT JOIN. The OR predicate lives in the ON clause,
-- so it only limits which employees match, and departments 30 and 40 survive with a NULL
-- ename. Moving the OR to WHERE would drop them and collapse this to an inner join.
SELECT e.ename, d.deptno, d.dname, d.loc
FROM dept d
LEFT JOIN emp e
  ON d.deptno = e.deptno
 AND (e.deptno = 10 OR e.deptno = 20)
ORDER BY d.deptno, e.ename;
