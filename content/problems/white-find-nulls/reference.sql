-- Recipe 1.11 tutorial: find rows whose column is NULL.
-- NULL means "unknown," so it never satisfies "= " (not even "comm = NULL").
-- The only correct test for absence of a value is the IS NULL predicate.
SELECT *
FROM emp
WHERE comm IS NULL;
