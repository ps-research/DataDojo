select ename as ename_and_dname, deptno
  from emp
 where deptno = 10
union all
select '----------', null
  from t1
union all
select dname, deptno
  from dept
