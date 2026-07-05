select ename, job
  from emp
 where deptno in (10, 20)
   and (ename like '%I%' or job like '%ER')
