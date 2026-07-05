#!/usr/bin/env python3
"""
KB Stage 4 — extract the book's canonical datasets into silver `datasets`.

The book prints EMP and DEPT as fixed-format result listings (the classic
SCOTT schema) rather than DDL. We PARSE the printed rows verbatim from the
preface span (anchoring EMP rows on the dd-MON-yyyy hiredate) and generate
portable ANSI DDL (INTEGER / VARCHAR / DATE) that runs identically on SQLite,
DuckDB, PostgreSQL and MySQL. Pivot tables T1/T10/T100/T500 are id-series as
the book describes. Nothing is authored from memory: EMP/DEPT values come from
the printed table; row counts are asserted (EMP=14, DEPT=4).
"""
import hashlib, json, re, sqlite3, sys
from pathlib import Path

KB_DIR = Path(__file__).resolve().parent.parent
DB     = KB_DIR / "datadojo_kb.sqlite"
REPORT = KB_DIR / "reports" / "stage4_datasets.json"
sha = lambda b: hashlib.sha256(b).hexdigest()

MONTHS = dict(zip("JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC".split(),
                  range(1, 13)))
HIRE = re.compile(r"(\d{2})-([A-Z]{3})-(\d{4})")

def sql_str(v):
    return "NULL" if v is None else "'" + str(v).replace("'", "''") + "'"

db = sqlite3.connect(DB)
db.execute("PRAGMA foreign_keys=ON")
run_id = db.execute("INSERT INTO pipeline_runs(stage,script_sha256) VALUES('04_extract_datasets',?)",
                    (sha(Path(__file__).read_bytes()),)).lastrowid
pref = db.execute("SELECT id, raw_text FROM raw_spans WHERE label='preface'").fetchone()
span_id, text = pref
report = {"stage": "04_extract_datasets", "datasets": [], "exceptions": []}

# ---- EMP ---------------------------------------------------------------
emp_block = text[text.find("select * from emp"):text.find("select * from dept")]
emp_rows = []
for ln in emp_block.splitlines():
    m = HIRE.search(ln)
    if not m:
        continue
    left = ln[:m.start()].split()
    right = ln[m.end():].split()
    if len(left) < 3 or not left[0].isdigit():
        continue
    empno = int(left[0]); ename = left[1]; job = left[2]
    mgr = int(left[3]) if len(left) >= 4 and left[3].isdigit() else None
    d, mon, y = m.groups()
    hiredate = f"{y}-{MONTHS[mon]:02d}-{int(d):02d}"
    nums = [int(x) for x in right if x.lstrip("-").isdigit()]
    if len(nums) == 3:
        sal, comm, deptno = nums
    elif len(nums) == 2:
        sal, comm, deptno = nums[0], None, nums[1]
    else:
        report["exceptions"].append(f"EMP row unparsed: {ln!r}"); continue
    emp_rows.append((empno, ename, job, mgr, hiredate, sal, comm, deptno))

if len(emp_rows) != 14:
    report["exceptions"].append(f"EMP expected 14 rows, parsed {len(emp_rows)}")

emp_ddl = ("CREATE TABLE emp (\n"
           "  empno INTEGER PRIMARY KEY,\n  ename VARCHAR(10),\n  job VARCHAR(9),\n"
           "  mgr INTEGER,\n  hiredate DATE,\n  sal INTEGER,\n  comm INTEGER,\n"
           "  deptno INTEGER\n);")
emp_seed = "\n".join(
    "INSERT INTO emp (empno,ename,job,mgr,hiredate,sal,comm,deptno) VALUES "
    f"({e[0]},{sql_str(e[1])},{sql_str(e[2])},{e[3] if e[3] is not None else 'NULL'},"
    f"{sql_str(e[4])},{e[5]},{e[6] if e[6] is not None else 'NULL'},{e[7]});"
    for e in emp_rows)

# ---- DEPT --------------------------------------------------------------
dept_block = text[text.find("select * from dept"):text.find("four pivot tables")]
dept_rows = []
for ln in dept_block.splitlines():
    toks = ln.split()
    if len(toks) >= 3 and toks[0].isdigit() and toks[1].isalpha():
        deptno = int(toks[0]); dname = toks[1]; loc = " ".join(toks[2:])
        dept_rows.append((deptno, dname, loc))
if len(dept_rows) != 4:
    report["exceptions"].append(f"DEPT expected 4 rows, parsed {len(dept_rows)}")

dept_ddl = ("CREATE TABLE dept (\n  deptno INTEGER PRIMARY KEY,\n"
            "  dname VARCHAR(14),\n  loc VARCHAR(13)\n);")
dept_seed = "\n".join(
    f"INSERT INTO dept (deptno,dname,loc) VALUES ({d[0]},{sql_str(d[1])},{sql_str(d[2])});"
    for d in dept_rows)

# ---- pivot tables T1/T10/T100/T500 -------------------------------------
def pivot(n):
    ddl = f"CREATE TABLE t{n} (id INTEGER PRIMARY KEY);"
    seed = "\n".join(f"INSERT INTO t{n} (id) VALUES ({i});" for i in range(1, n + 1))
    return ddl, seed

datasets = [("EMP", emp_ddl, emp_seed, len(emp_rows)),
            ("DEPT", dept_ddl, dept_seed, len(dept_rows))]
for n in (1, 10, 100, 500):
    ddl, seed = pivot(n)
    datasets.append((f"T{n}", ddl, seed, n))

for name, ddl, seed, nrows in datasets:
    db.execute("INSERT INTO datasets(name,create_sql,seed_sql,span_id) VALUES(?,?,?,?) "
               "ON CONFLICT(name) DO UPDATE SET create_sql=excluded.create_sql, "
               "seed_sql=excluded.seed_sql, span_id=excluded.span_id",
               (name, ddl, seed, span_id))
    report["datasets"].append({"name": name, "rows": nrows})

db.execute("UPDATE pipeline_runs SET finished_at=datetime('now'),inputs=1,outputs=?,exceptions=? WHERE id=?",
           (len(datasets), json.dumps(report["exceptions"]), run_id))
db.commit()
REPORT.write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
sys.exit(1 if report["exceptions"] else 0)
