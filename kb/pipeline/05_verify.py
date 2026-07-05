#!/usr/bin/env python3
"""
KB Stage 5 — verification farm.

Executes every silver solution on every target engine (sqlite, duckdb,
postgres, mysql), recording pass/error + captured CSV output in `verifications`.
This is the ground-truth layer: a solution is only trustworthy if a real engine
runs it. Per-recipe "runnable on >=1 target engine" is the gate for gold.

Report summarizes pass rates per engine and per dialect, and — the number that
matters for content — how many recipes have at least one passing solution on
our primary engines.
"""
import hashlib, json, sqlite3, sys
from pathlib import Path
import engines as E

KB_DIR = Path(__file__).resolve().parent.parent
DB     = KB_DIR / "datadojo_kb.sqlite"
REPORT = KB_DIR / "reports" / "stage5_verify.json"
sha = lambda b: hashlib.sha256(b).hexdigest()

db = sqlite3.connect(DB)
db.execute("PRAGMA foreign_keys=ON")
run_id = db.execute("INSERT INTO pipeline_runs(stage,script_sha256) VALUES('05_verify',?)",
                    (sha(Path(__file__).read_bytes()),)).lastrowid

datasets = [dict(name=n, create_sql=c, seed_sql=s)
            for n, c, s in db.execute("select name,create_sql,seed_sql from datasets")]
solutions = db.execute("select id, recipe_id, dialect, sql_code from solutions order by id").fetchall()

print(f"connecting engines... ", end="", flush=True)
pg = E.Postgres()
my = E.MySQL()
runners = {
    "sqlite":   (E.run_sqlite, E.ENGINE_VERSIONS["sqlite"]),
    "duckdb":   (E.run_duckdb, E.ENGINE_VERSIONS["duckdb"]),
    "postgres": (pg.run,       pg.version),
    "mysql":    (my.run,       my.version),
}
print("ok:", ", ".join(f"{k}={v}" for k, (_, v) in runners.items()))

db.execute("DELETE FROM verifications")
counts = {e: {"pass": 0, "error": 0} for e in runners}
n = len(solutions)
for i, (sol_id, recipe_id, dialect, sql) in enumerate(solutions, 1):
    for engine, (run, ver) in runners.items():
        res = run(sql, datasets)
        counts[engine][res.status] += 1
        db.execute(
            "INSERT INTO verifications(solution_id,engine,engine_version,status,"
            "captured_output,error_message) VALUES(?,?,?,?,?,?)",
            (sol_id, engine, ver, res.status, res.csv, res.error))
    if i % 50 == 0 or i == n:
        print(f"  {i}/{n} solutions verified")
        db.commit()
db.commit()

# ---- per-recipe runnability on primary engines (sqlite/duckdb/postgres) ----
primary = ("sqlite", "duckdb", "postgres")
q = ",".join("?" * len(primary))
recipe_ok = db.execute(f"""
    SELECT COUNT(DISTINCT s.recipe_id) FROM solutions s
    JOIN verifications v ON v.solution_id=s.id
    WHERE v.engine IN ({q}) AND v.status='pass'
""", primary).fetchone()[0]
total_recipes = db.execute("SELECT COUNT(*) FROM recipes WHERE parse_status='ok'").fetchone()[0]

# any-engine (incl mysql)
recipe_ok_any = db.execute("""
    SELECT COUNT(DISTINCT s.recipe_id) FROM solutions s
    JOIN verifications v ON v.solution_id=s.id WHERE v.status='pass'
""").fetchone()[0]

report = {
    "stage": "05_verify",
    "solutions_total": n,
    "engine_versions": {k: v for k, (_, v) in runners.items()},
    "per_engine": counts,
    "recipes_ok_parse": total_recipes,
    "recipes_runnable_primary": recipe_ok,       # >=1 pass on sqlite/duckdb/postgres
    "recipes_runnable_any": recipe_ok_any,
}
db.execute("UPDATE pipeline_runs SET finished_at=datetime('now'),inputs=?,outputs=?,exceptions='[]' WHERE id=?",
           (n, n * len(runners), run_id))
db.commit()
REPORT.write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
