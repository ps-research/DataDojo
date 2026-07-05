#!/usr/bin/env python3
"""
KB Stage 1 — ingest SQL Cookbook into the bronze layer.

Deterministic steps, no hand-authored content:
 1. Register the PDF in `sources` with its sha256.
 2. Extract all pages in ONE pdftotext pass (pages split on form-feed \\f).
 3. Build the pdf_page -> printed(book) page map by reading the running
    headers ("18 | Chapter 2: ..." / "... | 17"). The offset must be modal &
    consistent; every outlier page is listed in the report.
 4. For every recipe in the verified TOC JSON, compute its pdf page range
    (start = its book page, end = next TOC entry's start page, inclusive) and
    store the VERBATIM page text as a raw_span labeled 'recipe:<id>'.
    Also spans for: preface (dataset definitions), the two appendices.
 5. Write pipeline_runs row + JSON report. Exceptions list must be [] to pass.
"""
import hashlib, json, re, sqlite3, subprocess, sys
from collections import Counter
from pathlib import Path

KB_DIR   = Path(__file__).resolve().parent.parent
PDF      = KB_DIR.parent / "Resources" / "SQL Cookbook - 2nd Edition - Anthony Molinaro, Robert de Graaf - O'Reilly Media (2020).pdf"
DB       = KB_DIR / "datadojo_kb.sqlite"
TOC_JSON = KB_DIR / "SQL_Cookbook_TOC.json"
REPORT   = KB_DIR / "reports" / "stage1_ingest_book.json"

sha = lambda b: hashlib.sha256(b).hexdigest()

# ---- 1. register source -------------------------------------------------
pdf_bytes = PDF.read_bytes()
db = sqlite3.connect(DB)
db.execute("PRAGMA foreign_keys=ON")
run_id = db.execute(
    "INSERT INTO pipeline_runs(stage, script_sha256) VALUES('01_ingest_book',?)",
    (sha(Path(__file__).read_bytes()),)).lastrowid
src_id = db.execute(
    "INSERT INTO sources(kind,title,locator,version,sha256) VALUES('book',?,?,?,?) "
    "ON CONFLICT(kind,locator) DO UPDATE SET sha256=excluded.sha256 RETURNING id",
    ("SQL Cookbook", str(PDF), "2nd Edition (2020)", sha(pdf_bytes))).fetchone()[0]

# ---- 2. one-pass page extraction ----------------------------------------
txt = subprocess.run(["pdftotext", "-layout", str(PDF), "-"],
                     capture_output=True, text=True, check=True).stdout
pages = txt.split("\f")                       # pages[i] = pdf page i+1
N = len(pages)

# ---- 3. pdf->book page map from running headers --------------------------
# Header shapes (with -layout):  "18   |   Chapter 2: ..."   (verso)
#                                "Chapter 2: ...   |   17"   (recto)
head_l = re.compile(r"^\s*(\d{1,3})\s*\|\s+\S")
head_r = re.compile(r"\|\s+(\d{1,3})\s*$")
printed = {}                                   # pdf_page -> printed page
for i, ptext in enumerate(pages, start=1):
    lines = [l for l in ptext.splitlines() if l.strip()]
    if not lines:
        continue
    for l in (lines[0], lines[-1]):            # header or footer line
        m = head_l.match(l) or head_r.search(l)
        if m:
            printed[i] = int(m.group(1))
            break

offsets = Counter(i - p for i, p in printed.items())
offset, votes = offsets.most_common(1)[0]
outliers = {i: p for i, p in printed.items() if i - p != offset}

# ---- 4. spans ------------------------------------------------------------
toc = json.loads(TOC_JSON.read_text())
entries = [e for e in toc if e["kind"] in ("recipe", "chapter", "appendix")]
# order by book page (TOC order is already correct; keep arabic pages only)
def bp(e):
    return int(e["page"]) if e["page"] and e["page"].isdigit() else None

seq = [e for e in entries if bp(e) is not None]
exceptions = []
spans_written = 0

def write_span(label, pdf_a, pdf_b, book_a, book_b):
    global spans_written
    body = "\f".join(pages[pdf_a - 1:pdf_b])   # verbatim, form-feeds preserved
    if not body.strip():
        exceptions.append(f"{label}: empty text for pdf pages {pdf_a}-{pdf_b}")
        return
    db.execute(
        "INSERT INTO raw_spans(source_id,label,locator,raw_text,sha256) VALUES(?,?,?,?,?) "
        "ON CONFLICT(source_id,label) DO UPDATE SET locator=excluded.locator, "
        "raw_text=excluded.raw_text, sha256=excluded.sha256",
        (src_id, label, f"pdf_pages:{pdf_a}-{pdf_b} book_pages:{book_a}-{book_b}",
         body, sha(body.encode())))
    spans_written += 1

recipes_spanned = 0
for k, e in enumerate(seq):
    if e["kind"] != "recipe":
        continue
    start_bp = bp(e)
    nxt = next((bp(x) for x in seq[k + 1:] if bp(x) is not None), None)
    end_bp = nxt if nxt and nxt >= start_bp else start_bp
    pdf_a, pdf_b = start_bp + offset, min(end_bp + offset, N)
    if pdf_a < 1 or pdf_a > N:
        exceptions.append(f"recipe {e['num']}: book page {start_bp} out of range")
        continue
    write_span(f"recipe:{e['num']}", pdf_a, pdf_b, start_bp, end_bp)
    recipes_spanned += 1

# preface (dataset definitions live here): roman-numbered front matter runs
# from pdf page 13 up to the page before arabic book page 1 (= pdf 1+offset)
write_span("preface", 13, offset, 0, 0)
for e in toc:
    if e["kind"] == "appendix":
        a = bp(e)
        if e["num"] == "A":
            write_span("appendix:A", a + offset, 534 + offset, a, 534)
        elif e["num"] == "B":
            write_span("appendix:B", a + offset, 538 + offset, a, 538)

db.execute("UPDATE pipeline_runs SET finished_at=datetime('now'),inputs=?,outputs=?,exceptions=? WHERE id=?",
           (len(seq), spans_written, json.dumps(exceptions), run_id))
db.commit()

report = {
    "stage": "01_ingest_book",
    "pdf_pages": N,
    "pages_with_printed_number": len(printed),
    "page_offset": offset, "offset_votes": votes,
    "offset_outlier_pages": outliers,
    "toc_recipe_count": sum(1 for e in toc if e["kind"] == "recipe"),
    "recipes_spanned": recipes_spanned,
    "total_spans": spans_written,
    "exceptions": exceptions,
}
REPORT.write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
sys.exit(0 if not exceptions and recipes_spanned == report["toc_recipe_count"] else 1)
