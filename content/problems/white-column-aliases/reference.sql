-- Recipe 1.5 tutorial: give columns readable names.
-- The AS keyword assigns an alias to a select-list expression, so the result set
-- carries meaningful headers (salary, commission) instead of the raw column names.
SELECT sal AS salary, comm AS commission
FROM emp;
