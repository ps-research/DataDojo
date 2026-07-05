select ename, comm
  from emp
 where coalesce(comm, 0) < (select max(comm)
                              from emp
                             where ename = 'WARD')
