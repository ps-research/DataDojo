#!/usr/bin/env python3
"""
Hidden-fixture generator for White tutorials: a scaled SCOTT-style world.
Same schema as the canonical EMP/DEPT (plus pivot tables T1/T10/T100/T500),
but ~1200 employees / 12 departments with planted landmines (NULL mgr/comm,
salary ties, duplicate names, boundary hire dates), deterministic from a seed.
Usage: python3 emp_generator.py --seed N --out DIR   (emits emp.csv, dept.csv, t*.csv)
"""
import argparse, csv, random
from pathlib import Path

FIRST = ["SMITH","ALLEN","WARD","JONES","MARTIN","BLAKE","CLARK","SCOTT","KING","TURNER",
         "ADAMS","JAMES","FORD","MILLER","REED","CRUZ","STONE","WOLF","HAYES","BROOKS",
         "LANE","PARKS","MEYER","BOND","SHAW","GRANT","CHASE","BLAIR","DEAN","VANCE"]
JOBS = ["CLERK","SALESMAN","ANALYST","MANAGER"]
DNAMES = ["ACCOUNTING","RESEARCH","SALES","OPERATIONS","MARKETING","LOGISTICS",
          "SUPPORT","ENGINEERING","LEGAL","FINANCE","QUALITY","PLANNING"]
LOCS = ["NEW YORK","DALLAS","CHICAGO","BOSTON","AUSTIN","DENVER",
        "SEATTLE","ATLANTA","MIAMI","PORTLAND","PHOENIX","DETROIT"]

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--out", required=True)
    ap.add_argument("--emps", type=int, default=1200)
    a = ap.parse_args()
    rng = random.Random(a.seed)
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)

    ndep = 12
    with open(out / "dept.csv", "w", newline="") as f:
        w = csv.writer(f); w.writerow(["deptno","dname","loc"])
        for i in range(ndep):
            w.writerow([(i + 1) * 10, DNAMES[i], LOCS[i]])

    deptnos = [(i + 1) * 10 for i in range(ndep)]
    # managers first so mgr references are valid
    emps = []
    empno = 7000
    managers_by_dept = {}
    for d in deptnos:
        for _ in range(rng.randint(1, 3)):
            empno += rng.randint(1, 7)
            sal = rng.choice([2450, 2850, 2975, 3000, 3100, 3300, 3600])  # deliberate ties
            hired = f"{rng.randint(2004, 2015)}-{rng.randint(1,12):02d}-{rng.choice([1, 15, 28, 30] if rng.random() < 0.7 else [29]):02d}"
            emps.append([empno, rng.choice(FIRST), "MANAGER", None, hired, sal, None, d])
            managers_by_dept.setdefault(d, []).append(empno)
    president = [6999, "KING", "PRESIDENT", None, "2004-11-17", 5000, None, deptnos[0]]
    emps.append(president)

    while len(emps) < a.emps:
        empno += rng.randint(1, 9)
        d = rng.choice(deptnos)
        job = rng.choice(JOBS[:3])
        sal = rng.choice([800, 950, 950, 1100, 1250, 1250, 1300, 1500, 1600, 2000, 2000, 2200, 3000])
        comm = None
        if job == "SALESMAN":
            comm = rng.choice([0, 0, 300, 500, 1400, None])  # zeros AND nulls: comm landmine
        mgr = rng.choice(managers_by_dept[d]) if rng.random() > 0.02 else None  # orphan landmine
        y, m = rng.randint(2004, 2016), rng.randint(1, 12)
        day = 29 if (m == 2 and y % 4 == 0 and rng.random() < 0.3) else rng.randint(1, 28)
        emps.append([empno, rng.choice(FIRST), job, mgr, f"{y}-{m:02d}-{day:02d}", sal, comm, d])

    with open(out / "emp.csv", "w", newline="") as f:
        w = csv.writer(f); w.writerow(["empno","ename","job","mgr","hiredate","sal","comm","deptno"])
        for e in emps:
            w.writerow(["" if v is None else v for v in e])

    for n in (1, 10, 100, 500):
        with open(out / f"t{n}.csv", "w", newline="") as f:
            w = csv.writer(f); w.writerow(["id"])
            for i in range(1, n + 1):
                w.writerow([i])

if __name__ == "__main__":
    main()
