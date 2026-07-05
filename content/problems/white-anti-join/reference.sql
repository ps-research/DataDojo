select d.*
  from dept d left outer join emp e
    on (d.deptno = e.deptno)
 where e.deptno is null
