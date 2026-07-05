select ename, sal, job, comm
  from emp
 order by case when (case when job = 'SALESMAN' then comm else sal end) is null then 1 else 0 end,
          case when job = 'SALESMAN' then comm else sal end,
          empno
