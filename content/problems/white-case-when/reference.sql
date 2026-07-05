-- Recipe 1.8 tutorial: in-query IF/ELSE with CASE.
-- CASE walks its WHEN branches top to bottom and returns the value of the first
-- one that is true; ELSE covers everything else. Here salary is bucketed into a
-- readable status label without leaving the SELECT list.
SELECT ename, sal,
       CASE WHEN sal <= 2000 THEN 'UNDERPAID'
            WHEN sal >= 4000 THEN 'OVERPAID'
            ELSE 'OK'
       END AS status
FROM emp;
