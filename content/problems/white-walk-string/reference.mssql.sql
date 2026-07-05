select substring(e.ename, iter.pos, 1) as c
  from (select ename from emp where ename = 'KING') e,
       (select id as pos from t10) iter
 where iter.pos <= len(e.ename)
