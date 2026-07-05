select (length('10,CLARK,MANAGER') -
        length(replace('10,CLARK,MANAGER', ',', ''))) / length(',') as cnt
  from t1
