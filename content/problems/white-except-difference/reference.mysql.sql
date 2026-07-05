-- MySQL EXCEPT exists only in 8.0.31+; NOT EXISTS is the portable set-difference here.
select d.deptno
  from dept d
 where not exists (select 1 from emp e where e.deptno = d.deptno)
