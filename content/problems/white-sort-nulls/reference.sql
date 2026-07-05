select ename, sal, comm
  from emp
 order by case when comm is null then 1 else 0 end asc,
          comm asc,
          ename asc
