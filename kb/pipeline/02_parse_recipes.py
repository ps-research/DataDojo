#!/usr/bin/env python3
"""
KB Stage 2 — parse bronze recipe spans into silver (recipes + solutions).

Deterministic invariants discovered by inspection of bronze text:
  * Section markers 'Problem' / 'Solution' / 'Discussion' are standalone
    column-0 lines.
  * Solution SQL is printed with line numbers:  '    1 select ...'
    (prose numbered lists use '1.' with a period — no collision).
    A line number restarting at 1 begins a NEW code block (position++).
  * Dialect headers are standalone lines composed ONLY of dialect names
    joined by commas/'and' (e.g. 'DB2, MySQL, Oracle, and PostgreSQL').
  * Running headers/footers look like '8 | Chapter 1: ...' or '... | 17'.
  * A recipe's span may include the tail of the previous recipe and the head
    of the next (shared pages) — cut own body between own heading and the
    next 'N.N Title' heading.

Nothing is rewritten: problem/discussion/solution text is stored verbatim
(minus page furniture). Exceptions are collected per recipe; parse_status
records 'ok'/'partial'. Exit non-zero if any recipe fails outright.
"""
import hashlib, json, re, sqlite3, sys
from pathlib import Path

KB_DIR = Path(__file__).resolve().parent.parent
DB     = KB_DIR / "datadojo_kb.sqlite"
REPORT = KB_DIR / "reports" / "stage2_parse_recipes.json"

sha = lambda b: hashlib.sha256(b).hexdigest()

HEADER_NOISE = re.compile(r"(^\s*\d{1,3}\s*\|\s+\S)|(\|\s+\d{1,3}\s*$)")
RECIPE_HEAD  = re.compile(r"^(\d{1,2})\.(\d{1,2}) \S")
CODE_LINE    = re.compile(r"^\s+(\d{1,3}) (.*)$|^\s+(\d{1,3})$")
SECTIONS     = ("Problem", "Solution", "Discussion")

DIALECTS = ["DB2", "MySQL", "Oracle", "PostgreSQL", "SQL Server"]
_d_alt   = "|".join(re.escape(d) for d in DIALECTS)
DIALECT_HEADER = re.compile(
    rf"^({_d_alt})((,\s*|\s+and\s+|,\s*and\s+)({_d_alt}))*$")

db = sqlite3.connect(DB)
db.execute("PRAGMA foreign_keys=ON")
run_id = db.execute(
    "INSERT INTO pipeline_runs(stage, script_sha256) VALUES('02_parse_recipes',?)",
    (sha(Path(__file__).read_bytes()),)).lastrowid

toc = json.loads((KB_DIR / "SQL_Cookbook_TOC.json").read_text())
recipes_toc = [e for e in toc if e["kind"] == "recipe"]

def clean_lines(raw):
    out = []
    for ln in raw.replace("\f", "\n").splitlines():
        if HEADER_NOISE.search(ln) and len(ln.strip()) < 90:
            continue
        out.append(ln.rstrip())
    return out

def cut_own_body(lines, num):
    """Slice from own heading to the next recipe heading."""
    start = end = None
    own = re.compile(rf"^{re.escape(num)} \S")
    for i, ln in enumerate(lines):
        if start is None and own.match(ln):
            start = i
            continue
        if start is not None and RECIPE_HEAD.match(ln) and not own.match(ln):
            end = i
            break
    return (lines[start:end] if start is not None else None)

def find_sections(body):
    """Indices of standalone Problem/Solution/Discussion lines (col 0)."""
    idx = {}
    for i, ln in enumerate(body):
        if ln in SECTIONS and ln not in idx:
            idx[ln] = i
    return idx

def parse_solution_blocks(sol_lines):
    """Split a Solution section by dialect headers; extract numbered code."""
    blocks = []                        # (dialect, [lines])
    cur_dialect, cur = "ALL", []
    for ln in sol_lines:
        if DIALECT_HEADER.match(ln.strip()) and ln.lstrip() == ln:
            blocks.append((cur_dialect, cur))
            cur_dialect, cur = ln.strip(), []
        else:
            cur.append(ln)
    blocks.append((cur_dialect, cur))

    out = []                           # (dialect, position, sql)
    for dialect, lines in blocks:
        code_blocks, buf, last_n = [], [], 0
        for ln in lines:
            m = CODE_LINE.match(ln)
            if m:
                n = int(m.group(1) or m.group(3))
                code = m.group(2) or ""
                if n == 1 and buf and last_n >= 1:
                    code_blocks.append("\n".join(buf)); buf = []
                buf.append(code); last_n = n
            else:
                # blank or prose inside a code run: only blank keeps the run
                if buf and ln.strip() == "":
                    continue
                if buf:
                    code_blocks.append("\n".join(buf)); buf = []
                last_n = 0
        if buf:
            code_blocks.append("\n".join(buf))
        if not code_blocks:
            code_blocks = unnumbered_code_blocks(lines)
        if dialect == "ALL" and not code_blocks and not out:
            continue                   # pure-prose intro before first dialect
        for pos, sql in enumerate(code_blocks, start=1):
            out.append((dialect, pos, sql))
    return out

SQL_KEYWORD = re.compile(
    r"^\s*(select|with|create|insert|update|delete|merge|values|set\s|explain|"
    r"show|describe|drop|alter|truncate|copy|call|declare|begin)\b", re.IGNORECASE)
DASH_RULE = re.compile(r"^\s*-{3,}[\s-]*$")

def unnumbered_code_blocks(lines):
    """Fallback for code the book prints without line numbers: a contiguous
    indented run whose first line starts with a SQL keyword. Result-set
    listings are excluded (their second line is a dashed column rule)."""
    blocks, i = [], 0
    while i < len(lines):
        ln = lines[i]
        if ln.startswith(" ") and SQL_KEYWORD.match(ln):
            j = i
            run = []
            while j < len(lines) and lines[j].startswith(" ") and lines[j].strip():
                run.append(lines[j])
                j += 1
            if len(run) >= 2 and DASH_RULE.match(run[1]):
                i = j                  # column-header + dashes = result set
                continue
            indent = min(len(l) - len(l.lstrip()) for l in run)
            blocks.append("\n".join(l[indent:] for l in run))
            i = j
        else:
            i += 1
    return blocks

report = {"stage": "02_parse_recipes", "recipes": 0, "ok": 0, "partial": 0,
          "failed": 0, "solutions": 0, "exceptions": []}

for e in recipes_toc:
    num, title, page = e["num"], e["title"], int(e["page"])
    chapter, number = (int(x) for x in num.split("."))
    row = db.execute("SELECT id, raw_text FROM raw_spans WHERE label=?",
                     (f"recipe:{num}",)).fetchone()
    if not row:
        report["exceptions"].append(f"{num}: no bronze span"); report["failed"] += 1
        continue
    span_id, raw = row

    if title == "Summing Up":          # chapter conclusion, not a recipe
        db.execute(
            "INSERT OR REPLACE INTO recipes(id,chapter,number,title,book_page,"
            "span_id,parse_status,parse_notes) VALUES(?,?,?,?,?,?,?,?)",
            (num, chapter, number, title, page, span_id, "skipped",
             "chapter conclusion (not a recipe)"))
        report["recipes"] += 1
        report["skipped"] = report.get("skipped", 0) + 1
        continue
    body = cut_own_body(clean_lines(raw), num)
    status, notes = "ok", []
    problem_text = discussion_text = None
    solutions = []

    if body is None:
        status, notes = "failed", [f"own heading '{num}' not found in span"]
    else:
        secs = find_sections(body)
        if "Problem" not in secs or "Solution" not in secs:
            status = "failed"
            notes.append(f"sections found: {sorted(secs)}")
        else:
            p0 = secs["Problem"]; s0 = secs["Solution"]
            d0 = secs.get("Discussion", len(body))
            problem_text = "\n".join(body[p0 + 1:s0]).strip()
            discussion_text = "\n".join(body[d0 + 1:]).strip() if d0 < len(body) else None
            solutions = parse_solution_blocks(body[s0 + 1:d0])
            if not solutions:
                status = "partial"; notes.append("no numbered code blocks in Solution")
            if not problem_text:
                status = "partial"; notes.append("empty Problem text")
            if "Discussion" not in secs:
                notes.append("no Discussion section")

    db.execute(
        "INSERT OR REPLACE INTO recipes(id,chapter,number,title,book_page,span_id,"
        "problem_text,discussion_text,parse_status,parse_notes) VALUES(?,?,?,?,?,?,?,?,?,?)",
        (num, chapter, number, title, page, span_id, problem_text,
         discussion_text, status, "; ".join(notes) or None))
    db.execute("DELETE FROM solutions WHERE recipe_id=?", (num,))
    for dialect, pos, sql in solutions:
        db.execute("INSERT INTO solutions(recipe_id,dialect,sql_code,position) "
                   "VALUES(?,?,?,?)", (num, dialect, sql, pos))

    report["recipes"] += 1
    report[status if status in ("ok", "partial") else "failed"] += 1
    report["solutions"] += len(solutions)
    if notes:
        report["exceptions"].append(f"{num} [{status}]: {'; '.join(notes)}")

db.execute("UPDATE pipeline_runs SET finished_at=datetime('now'),inputs=?,outputs=?,"
           "exceptions=? WHERE id=?",
           (len(recipes_toc), report["recipes"],
            json.dumps(report["exceptions"]), run_id))
db.commit()
REPORT.write_text(json.dumps(report, indent=2))
print(json.dumps({k: v for k, v in report.items() if k != "exceptions"}, indent=2))
print("exceptions:", len(report["exceptions"]))
for x in report["exceptions"]:
    print("  !!", x)
sys.exit(1 if report["failed"] else 0)
