select e.ename, d.loc
  from emp e, dept d
 where e.deptno = d.deptno
   and e.deptno = 10
