-- Count every row in the table. COUNT(*) includes rows with NULL columns,
-- unlike COUNT(comm), which would count only non-NULL commissions.
SELECT COUNT(*) AS total_employees
FROM emp;
