#!/usr/bin/env python3
"""
KB Stage 3 — ingest curated PostgreSQL documentation into bronze + silver.

Curated to mirror the book's skill tree (retrieving/sorting/joins/strings/
numbers/dates/windows/CTEs/recursive). Verbatim HTML is fetched with urllib
(NOT an LLM), sha256'd, stored as bronze spans; doc_sections rows are parsed
deterministically from the page <title> ("PostgreSQL: Documentation: 18:
7.8. WITH Queries ...") — version, section number, and title all lifted, none
authored. Any fetch failure or unparsable title is reported; exit non-zero if so.
"""
import hashlib, html, json, re, sqlite3, sys, time, urllib.request
from pathlib import Path

KB_DIR = Path(__file__).resolve().parent.parent
DB     = KB_DIR / "datadojo_kb.sqlite"
REPORT = KB_DIR / "reports" / "stage3_ingest_docs.json"
BASE   = "https://www.postgresql.org/docs/current/"

sha = lambda b: hashlib.sha256(b).hexdigest()

# (slug, part) — chapter/section/title are parsed from the page itself.
PAGES = [
    ("tutorial-sql.html",              "Tutorial"),
    ("tutorial-select.html",           "Tutorial"),
    ("tutorial-join.html",             "Tutorial"),
    ("tutorial-agg.html",              "Tutorial"),
    ("tutorial-window.html",           "Tutorial"),
    ("tutorial-advanced.html",         "Tutorial"),
    ("tutorial-views.html",            "Tutorial"),
    ("queries.html",                   "The SQL Language"),
    ("queries-table-expressions.html", "The SQL Language"),
    ("queries-select-lists.html",      "The SQL Language"),
    ("queries-union.html",             "The SQL Language"),
    ("queries-order.html",             "The SQL Language"),
    ("queries-limit.html",             "The SQL Language"),
    ("queries-with.html",              "The SQL Language"),
    ("functions-aggregate.html",       "The SQL Language"),
    ("functions-window.html",          "The SQL Language"),
    ("functions-string.html",          "The SQL Language"),
    ("functions-datetime.html",        "The SQL Language"),
    ("functions-conditional.html",     "The SQL Language"),
    ("functions-matching.html",        "The SQL Language"),
    ("functions-subquery.html",        "The SQL Language"),
]

TITLE_RE = re.compile(r"<title>(.*?)</title>", re.S)

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "DataDojo-KB/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()

def parse_title(raw_html):
    m = TITLE_RE.search(raw_html)
    if not m:
        return None, None, None
    full = html.unescape(m.group(1)).strip()
    parts = [p.strip() for p in full.split(":")]
    version = parts[2] if len(parts) >= 3 and parts[2].isdigit() else None
    tail = parts[-1]
    tail = re.sub(r"^Chapter\s+", "", tail)
    sm = re.match(r"^([\d]+(?:\.[\d]+)*)\.\s+(.*)$", tail)
    if sm:
        return version, sm.group(1), sm.group(2)
    return version, None, tail

db = sqlite3.connect(DB)
db.execute("PRAGMA foreign_keys=ON")
run_id = db.execute(
    "INSERT INTO pipeline_runs(stage, script_sha256) VALUES('03_ingest_docs',?)",
    (sha(Path(__file__).read_bytes()),)).lastrowid

report = {"stage": "03_ingest_docs", "requested": len(PAGES), "fetched": 0,
          "sections": 0, "version": None, "exceptions": []}
src_id = None

for slug, part in PAGES:
    url = BASE + slug
    try:
        raw = fetch(url)
    except Exception as ex:
        report["exceptions"].append(f"{slug}: fetch failed: {ex}")
        continue
    text = raw.decode("utf-8", "replace")
    version, section, title = parse_title(text)
    if title is None:
        report["exceptions"].append(f"{slug}: could not parse <title>")
        continue
    report["version"] = report["version"] or version

    if src_id is None:
        src_id = db.execute(
            "INSERT INTO sources(kind,title,locator,version,sha256) "
            "VALUES('docs',?,?,?,?) ON CONFLICT(kind,locator) DO UPDATE SET "
            "version=excluded.version, sha256=excluded.sha256 RETURNING id",
            ("PostgreSQL Documentation", BASE, f"PostgreSQL {version}",
             sha(version.encode() if version else b""))).fetchone()[0]

    span_id = db.execute(
        "INSERT INTO raw_spans(source_id,label,locator,raw_text,sha256) "
        "VALUES(?,?,?,?,?) ON CONFLICT(source_id,label) DO UPDATE SET "
        "raw_text=excluded.raw_text, sha256=excluded.sha256 RETURNING id",
        (src_id, f"docs:{slug}", url, text, sha(raw))).fetchone()[0]

    chapter = section.split(".")[0] if section else None
    db.execute(
        "INSERT INTO doc_sections(span_id,part,chapter,section,title,url) "
        "VALUES(?,?,?,?,?,?) ON CONFLICT(url) DO UPDATE SET "
        "span_id=excluded.span_id, title=excluded.title, section=excluded.section",
        (span_id, part, chapter or (section or title), section, title, url))
    report["fetched"] += 1
    report["sections"] += 1
    time.sleep(0.3)

db.execute("UPDATE pipeline_runs SET finished_at=datetime('now'),inputs=?,outputs=?,"
           "exceptions=? WHERE id=?",
           (len(PAGES), report["fetched"], json.dumps(report["exceptions"]), run_id))
db.commit()
REPORT.write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
sys.exit(0 if not report["exceptions"] and report["fetched"] == len(PAGES) else 1)
