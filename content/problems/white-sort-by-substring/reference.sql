select ename, job
  from emp
 order by substr(job, length(job) - 1), ename
