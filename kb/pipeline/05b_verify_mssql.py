#!/usr/bin/env python3
"""KB Stage 5b — append MS SQL Server verification to the farm results."""
import json, sqlite3, sys
from pathlib import Path
import engines as E

KB_DIR = Path(__file__).resolve().parent.parent
DB = KB_DIR / "datadojo_kb.sqlite"
db = sqlite3.connect(DB); db.execute("PRAGMA foreign_keys=ON")

print("connecting SQL Server...", flush=True)
ss = E.SqlServer()
print("version:", ss.version)

db.execute("DELETE FROM verifications WHERE engine='mssql'")
sols = db.execute("select id, sql_code from solutions order by id").fetchall()
counts = {"pass": 0, "error": 0}
for i, (sid, sql) in enumerate(sols, 1):
    r = ss.run(sql)
    counts[r.status] += 1
    db.execute("INSERT INTO verifications(solution_id,engine,engine_version,status,"
               "captured_output,error_message) VALUES(?,?,?,?,?,?)",
               (sid, "mssql", ss.version, r.status, r.csv, r.error))
    if i % 80 == 0 or i == len(sols):
        print(f"  {i}/{len(sols)}"); db.commit()
db.commit()

alleng = ("sqlite", "duckdb", "postgres", "mysql", "mssql")
q = ",".join("?" * len(alleng))
runnable = db.execute(f"""SELECT COUNT(DISTINCT s.recipe_id) FROM solutions s
    JOIN verifications v ON v.solution_id=s.id
    WHERE v.engine IN ({q}) AND v.status='pass'""", alleng).fetchone()[0]
report = {"stage": "05b_verify_mssql", "mssql": counts,
          "recipes_runnable_all5_engines": runnable}
(KB_DIR / "reports" / "stage5b_verify_mssql.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
