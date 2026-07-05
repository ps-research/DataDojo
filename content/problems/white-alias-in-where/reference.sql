-- Recipe 1.6 tutorial: filter on a column alias.
-- A WHERE clause is logically evaluated before the SELECT list, so an alias
-- defined in SELECT is not yet visible to WHERE. Wrapping the aliased query in a
-- derived table (inline view) makes the alias a real column of that subquery,
-- which the outer WHERE can then reference.
SELECT *
FROM (
    SELECT sal AS salary, comm AS commission
    FROM emp
) x
WHERE salary < 5000;
