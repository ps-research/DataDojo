select (len('10,CLARK,MANAGER') -
        len(replace('10,CLARK,MANAGER', ',', ''))) / len(',') as cnt
  from t1
