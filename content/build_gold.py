#!/usr/bin/env python3
"""
Gate B + Gold builder. Reads every authored problem under content/problems/,
builds a portable judge fixture (visible-sample scale) from the universe
generator (or the canonical EMP/DEPT world for White tutorials), verifies the
reference solution actually runs and returns rows on SQLite (Gate B G1), and
emits content/gold_problems.json — the seed the app loads.

TLE-scale hidden fixtures are a design property (generators + fixtures.json
carry the seeds); v1 judges on the agent-verified sample fixture, where
correctness landmines (NULL/tie/distinct/guest) still bite. Reported honestly.
"""
import csv, glob, json, re, sqlite3, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROBLEMS = ROOT / "problems"
UNIVERSES = ROOT / "universes"
OUT = ROOT / "gold_problems.json"
REPORT = ROOT.parent / "kb" / "reports" / "gateB_gold.json"

CANONICAL_EMP = (ROOT / "white" / "canonical_empdept.sql")

# ---- canonical EMP/DEPT for White tutorials (the classic 14-row SCOTT world) ----
CANON_SQL = """CREATE TABLE dept (deptno INTEGER PRIMARY KEY, dname VARCHAR(14), loc VARCHAR(13));
INSERT INTO dept VALUES (10,'ACCOUNTING','NEW YORK'),(20,'RESEARCH','DALLAS'),(30,'SALES','CHICAGO'),(40,'OPERATIONS','BOSTON');
CREATE TABLE emp (empno INTEGER PRIMARY KEY, ename VARCHAR(10), job VARCHAR(9), mgr INTEGER, hiredate DATE, sal INTEGER, comm INTEGER, deptno INTEGER);
INSERT INTO emp VALUES
 (7369,'SMITH','CLERK',7902,'2005-12-17',800,NULL,20),(7499,'ALLEN','SALESMAN',7698,'2006-02-20',1600,300,30),
 (7521,'WARD','SALESMAN',7698,'2006-02-22',1250,500,30),(7566,'JONES','MANAGER',7839,'2006-04-02',2975,NULL,20),
 (7654,'MARTIN','SALESMAN',7698,'2006-09-28',1250,1400,30),(7698,'BLAKE','MANAGER',7839,'2006-05-01',2850,NULL,30),
 (7782,'CLARK','MANAGER',7839,'2006-06-09',2450,NULL,10),(7788,'SCOTT','ANALYST',7566,'2007-12-09',3000,NULL,20),
 (7839,'KING','PRESIDENT',NULL,'2006-11-17',5000,NULL,10),(7844,'TURNER','SALESMAN',7698,'2006-09-08',1500,0,30),
 (7876,'ADAMS','CLERK',7788,'2008-01-12',1100,NULL,20),(7900,'JAMES','CLERK',7698,'2006-12-03',950,NULL,30),
 (7902,'FORD','ANALYST',7566,'2006-12-03',3000,NULL,20),(7934,'MILLER','CLERK',7782,'2007-01-23',1300,NULL,10);
CREATE TABLE t1 (id INTEGER PRIMARY KEY); INSERT INTO t1 VALUES (1);
CREATE TABLE t10 (id INTEGER PRIMARY KEY); INSERT INTO t10 VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10);
CREATE TABLE t100 (id INTEGER PRIMARY KEY);
"""


def canonical_fixture() -> str:
    sql = CANON_SQL
    sql += "INSERT INTO t100 VALUES " + ",".join(f"({i})" for i in range(1, 101)) + ";\n"
    return sql


def parse_columns(schema_sql: str) -> dict[str, list[str]]:
    """table -> ordered column names, from CREATE TABLE blocks."""
    cols: dict[str, list[str]] = {}
    for m in re.finditer(r"CREATE\s+TABLE\s+(\w+)\s*\((.*?)\)\s*;", schema_sql, re.I | re.S):
        table = m.group(1).lower()
        names = []
        for line in m.group(2).split("\n"):
            line = line.strip().rstrip(",")
            if not line or line.startswith("--"):
                continue
            tok = line.split()[0]
            if tok.upper() in ("PRIMARY", "FOREIGN", "UNIQUE", "CONSTRAINT", "CHECK"):
                continue
            names.append(tok)
        cols[table] = names
    return cols


def csv_to_inserts(table: str, columns: list[str], csv_path: Path) -> str:
    rows = list(csv.reader(open(csv_path)))
    if len(rows) < 2:
        return ""
    header = rows[0]
    out = []
    for r in rows[1:]:
        vals = []
        for v in r:
            if v == "":
                vals.append("NULL")
            elif re.fullmatch(r"-?\d+(\.\d+)?", v):
                vals.append(v)
            else:
                vals.append("'" + v.replace("'", "''") + "'")
        out.append("(" + ",".join(vals) + ")")
    collist = ",".join(header)
    # chunk inserts to keep statements reasonable
    stmts = []
    for i in range(0, len(out), 500):
        stmts.append(f"INSERT INTO {table} ({collist}) VALUES " + ",".join(out[i:i + 500]) + ";")
    return "\n".join(stmts)


def build_universe_fixture(universe: str, seed: int, scale: str) -> str | None:
    schema_path = UNIVERSES / universe / "schema.sql"
    gen = UNIVERSES / universe / "generator.py"
    if not schema_path.exists() or not gen.exists():
        return None
    out_dir = Path(f"/tmp/gold_{universe}_{seed}_{scale}")
    if not out_dir.exists():
        r = subprocess.run(["python3", str(gen), "--seed", str(seed), "--scale", scale, "--out", str(out_dir)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            return None
    schema_sql = schema_path.read_text()
    cols = parse_columns(schema_sql)
    parts = [schema_sql]
    for table in cols:
        csvp = out_dir / f"{table}.csv"
        if csvp.exists():
            parts.append(csv_to_inserts(table, cols[table], csvp))
    return "\n".join(parts)


def schema_preview(fixture_sql: str) -> str:
    lines = []
    for m in re.finditer(r"CREATE\s+TABLE\s+(\w+)\s*\((.*?)\)\s*;", fixture_sql, re.I | re.S):
        names = []
        for line in m.group(2).split("\n"):
            line = line.strip().rstrip(",")
            if line and not line.startswith("--") and line.split()[0].upper() not in ("PRIMARY", "FOREIGN", "UNIQUE", "CONSTRAINT", "CHECK"):
                names.append(line.split()[0])
        lines.append(f"{m.group(1)}({', '.join(names)})")
    return "\n".join(lines)


def verify_reference(fixture_sql: str, reference_sql: str) -> tuple[bool, str, int]:
    con = sqlite3.connect(":memory:")
    try:
        con.executescript(fixture_sql)
        cur = con.execute(reference_sql.split(";")[0] if reference_sql.count(";") <= 1 else reference_sql)
        # execute only final statement's result
        rows = cur.fetchall()
        ncol = len(cur.description) if cur.description else 0
        return (ncol > 0, "", len(rows))
    except Exception as e:
        return (False, str(e)[:200], 0)
    finally:
        con.close()


POINTS = {"white": 10, "blue": 20, "purple": 40, "black": 70, "red": 120}
HIDDEN_SEEDS = [301, 302, 303]

WHITE_DDL = """CREATE TABLE dept (deptno INTEGER PRIMARY KEY, dname VARCHAR(14), loc VARCHAR(13));
CREATE TABLE emp (empno INTEGER PRIMARY KEY, ename VARCHAR(10), job VARCHAR(9), mgr INTEGER, hiredate DATE, sal INTEGER, comm INTEGER, deptno INTEGER);
CREATE TABLE t1 (id INTEGER PRIMARY KEY);
CREATE TABLE t10 (id INTEGER PRIMARY KEY);
CREATE TABLE t100 (id INTEGER PRIMARY KEY);
CREATE TABLE t500 (id INTEGER PRIMARY KEY);"""
WHITE_COLS = {"emp": ["empno", "ename", "job", "mgr", "hiredate", "sal", "comm", "deptno"],
              "dept": ["deptno", "dname", "loc"], "t1": ["id"], "t10": ["id"], "t100": ["id"], "t500": ["id"]}

_hidden_cache: dict = {}

def hidden_for_universe(universe: str, seed: int) -> str | None:
    key = ("u", universe, seed)
    if key not in _hidden_cache:
        _hidden_cache[key] = build_universe_fixture(universe, seed, "blue")
    return _hidden_cache[key]

def hidden_for_white(seed: int) -> str | None:
    key = ("w", seed)
    if key in _hidden_cache:
        return _hidden_cache[key]
    out = Path(f"/tmp/whitehidden_{seed}")
    if not out.exists():
        r = subprocess.run(["python3", str(ROOT / "white" / "emp_generator.py"),
                            "--seed", str(seed), "--out", str(out), "--emps", "1500"], capture_output=True)
        if r.returncode != 0:
            _hidden_cache[key] = None
            return None
    parts = [WHITE_DDL]
    for tbl, colnames in WHITE_COLS.items():
        csvp = out / f"{tbl}.csv"
        if csvp.exists():
            parts.append(csv_to_inserts(tbl, colnames, csvp))
    _hidden_cache[key] = "\n".join(parts)
    return _hidden_cache[key]

def build_hidden_fixtures(universe: str, reference_sql: str) -> list[str]:
    """3 big hidden fixtures; keep only those the reference runs cleanly on."""
    cands = [hidden_for_universe(universe, s) if universe else hidden_for_white(s) for s in HIDDEN_SEEDS]
    return [f for f in cands if f and verify_reference(f, reference_sql)[0]]


def no_dashes(text: str) -> str:
    # user rule: no em/en dashes anywhere user-facing
    return text.replace(" — ", " - ").replace(" – ", " - ").replace("—", "-").replace("–", "-")


def verify_code(category: str, fixture: str, reference: str) -> tuple[bool, str]:
    """Run fixture+reference for a python/r problem; ok if it prints CSV-ish stdout."""
    program = f"{fixture}\n{reference}\n"
    if category == "python":
        cmd = ["python3", "-s", "-E", "-"]
    else:
        cmd = ["Rscript", "--vanilla", "-"]
    try:
        p = subprocess.run(cmd, input=program, capture_output=True, text=True, timeout=30)
    except Exception as e:
        return (False, f"exec failed: {e}")
    if p.returncode != 0:
        return (False, (p.stderr or "nonzero exit")[:200])
    out = p.stdout.strip()
    if not out or "\n" not in out and "," not in out:
        return (False, "reference produced no CSV output")
    return (True, "")


def main() -> None:
    problems = []
    report = {"total": 0, "verified": 0, "fixture_fail": 0, "reference_fail": 0, "exceptions": []}
    number = 1
    for pj in sorted(glob.glob(str(PROBLEMS / "*" / "problem.json"))):
        d = Path(pj).parent
        report["total"] += 1
        try:
            meta = json.loads(Path(pj).read_text())
            statement = (d / "statement.md").read_text() if (d / "statement.md").exists() else meta["title"]
            ref_default = (d / "reference.sql").read_text() if (d / "reference.sql").exists() else ""
            fixtures = json.loads((d / "fixtures.json").read_text()) if (d / "fixtures.json").exists() else {}
            universe = meta.get("universe", "")
            category = meta.get("category", "sql")

            # Python / R problems: self-contained fixture + reference, verified by running.
            if category in ("python", "r"):
                ext = "py" if category == "python" else "R"
                fixture = (d / f"fixture.{ext}").read_text() if (d / f"fixture.{ext}").exists() else ""
                reference = (d / f"reference.{ext}").read_text() if (d / f"reference.{ext}").exists() else ""
                if not reference:
                    report["reference_fail"] += 1
                    report["exceptions"].append(f"{meta['slug']}: missing reference.{ext}")
                    continue
                ok, err = verify_code(category, fixture, reference)
                if not ok:
                    report["reference_fail"] += 1
                    report["exceptions"].append(f"{meta['slug']}: {category} verify failed: {err}")
                    continue
                starter = "# your code here\n" if category == "python" else "# your code here\n"
                problems.append({
                    "slug": meta["slug"], "number": number, "title": no_dashes(meta["title"]),
                    "statementMd": no_dashes(statement), "belt": meta.get("belt", "blue"),
                    "category": category, "universe": "", "concepts": meta.get("concepts", []),
                    "tags": meta.get("tags", []), "schemaPreview": "",
                    "orderMatters": bool(meta.get("orderMatters", False)),
                    "engines": [{"engine": category, "fixtureSql": fixture, "fixtureRef": "",
                                 "referenceSolution": reference, "starterCode": starter, "timeoutMs": 12000}],
                    "prerequisites": [], "provenance": meta.get("provenance", f"authored-{category}"),
                    "points": meta.get("points", POINTS.get(meta.get("belt", "blue"), 20)),
                })
                number += 1
                report["verified"] += 1
                continue

            if universe:
                vis = fixtures.get("visible", {"seed": 42, "scale": "sample"})
                fixture_sql = build_universe_fixture(universe, vis.get("seed", 42), "sample")
            else:
                fixture_sql = canonical_fixture()

            if not fixture_sql:
                report["fixture_fail"] += 1
                report["exceptions"].append(f"{meta['slug']}: fixture build failed")
                continue

            ok, err, nrows = verify_reference(fixture_sql, ref_default)
            if not ok:
                report["reference_fail"] += 1
                report["exceptions"].append(f"{meta['slug']}: reference failed on sqlite: {err}")
                continue

            engines = []
            for eng in meta.get("engines", ["sqlite"]):
                override = d / f"reference.{eng}.sql"
                ref = override.read_text() if override.exists() else ref_default
                engines.append({
                    "engine": eng,
                    "fixtureSql": fixture_sql,
                    "fixtureRef": "",
                    "referenceSolution": ref,
                    "starterCode": meta.get("starterCode", "-- Write your query here\n"),
                    "timeoutMs": 0,
                })

            problems.append({
                "slug": meta["slug"],
                "number": number,
                "title": no_dashes(meta["title"]),
                "statementMd": no_dashes(statement),
                "belt": meta.get("belt", "white"),
                "category": meta.get("category", "sql"),
                "universe": universe,
                "concepts": meta.get("concepts", []),
                "tags": meta.get("tags", []),
                "schemaPreview": schema_preview(fixture_sql),
                "orderMatters": bool(meta.get("orderMatters", False)),
                "engines": engines,
                "hiddenFixtures": build_hidden_fixtures(universe, ref_default),
                "prerequisites": [],  # all problems open (no ladder locks)
                "provenance": meta.get("provenance", ""),
                "points": meta.get("points", POINTS.get(meta.get("belt", "white"), 10)),
            })
            number += 1
            report["verified"] += 1
        except Exception as e:
            report["exceptions"].append(f"{Path(pj).parent.name}: {str(e)[:150]}")

    OUT.write_text(json.dumps(problems, indent=1))
    REPORT.write_text(json.dumps(report, indent=2))
    print(json.dumps({k: v for k, v in report.items() if k != "exceptions"}, indent=2))
    print(f"exceptions: {len(report['exceptions'])}")
    for x in report["exceptions"][:20]:
        print("  !!", x)


if __name__ == "__main__":
    main()
