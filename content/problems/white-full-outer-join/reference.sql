select d.deptno, d.dname, e.ename
  from emp e left outer join dept d
    on (d.deptno = e.deptno)
union
select d.deptno, d.dname, e.ename
  from dept d left outer join emp e
    on (d.deptno = e.deptno)
