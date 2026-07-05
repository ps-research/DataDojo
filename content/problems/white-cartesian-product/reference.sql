select e.ename, d.loc
  from emp e, dept d
 where e.deptno = 10
   and d.deptno = e.deptno
