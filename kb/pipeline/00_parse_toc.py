#!/usr/bin/env python3
"""
Deterministically transform the SQL Cookbook TOC (PDF pages 7-12) into
structured markdown + JSON. NO text is authored by hand: every title and page
number is lifted verbatim from pdftotext output. Any line that cannot be
classified is reported as UNPARSED so nothing is silently dropped or invented.
"""
import re, json, subprocess, sys, html

PDF = "/workspace/webdev/RESOURCE/SQL Cookbook - 2nd Edition - Anthony Molinaro, Robert de Graaf - O'Reilly Media (2020).pdf"

# 1. Pull the raw TOC text straight from the PDF (layout preserved).
raw = subprocess.run(
    ["pdftotext", "-layout", "-f", "7", "-l", "12", PDF, "-"],
    capture_output=True, text=True, check=True
).stdout
lines = raw.split("\n")

# 2. Noise: running headers/footers. Match exactly, don't touch real entries.
def is_noise(s):
    t = s.strip()
    if t == "" or t == "Table of Contents":
        return True
    if re.fullmatch(r"[ivxlc]+", t, re.IGNORECASE):        # bare roman page footer
        return True
    if "Table of Contents" in t and "|" in t:              # "vi | Table of Contents"
        return True
    return False

def collapse_leaders(s):
    # Dotted or long space leaders -> single space. Requires >=3 chars so real
    # single spaces inside titles are untouched. Leaves "1." and "1.1" intact.
    return re.sub(r"[ .]{3,}", " ", s).strip()

LABEL_CHAP = re.compile(r"^(\d+)\.$")       # "1."  chapter
LABEL_RCP  = re.compile(r"^(\d+\.\d+)$")    # "1.1" recipe
LABEL_APDX = re.compile(r"^([A-Z])\.$")     # "A."  appendix

def split_page(s):
    """Return (title, page) pulling a trailing arabic or roman number, else None."""
    m = re.search(r"^(.*?)\s+(\d+)$", s)
    if m:
        return m.group(1).strip(), m.group(2)
    m = re.search(r"^(.*?)\s+([ivxlc]+)$", s, re.IGNORECASE)
    if m:
        return m.group(1).strip(), m.group(2)
    return s, None

entries = []       # {kind, num, title, page}
unparsed = []
pending = None     # buffered wrapped entry awaiting its continuation line

for ln in lines:
    if is_noise(ln):
        continue
    s = collapse_leaders(ln)
    if not s:
        continue
    tok0 = s.split(" ", 1)[0]
    rest = s.split(" ", 1)[1] if " " in s else ""

    kind = None
    num = None
    if LABEL_CHAP.match(tok0):
        kind, num = "chapter", LABEL_CHAP.match(tok0).group(1)
    elif LABEL_RCP.match(tok0):
        kind, num = "recipe", LABEL_RCP.match(tok0).group(1)
    elif LABEL_APDX.match(tok0):
        kind, num = "appendix", LABEL_APDX.match(tok0).group(1)
    elif tok0 in ("Preface", "Index"):
        kind, num, rest = "front", tok0, s  # whole line; title=tok0

    if kind is None:
        # No label: either a continuation of a wrapped title, or noise.
        if pending is not None:
            title_part, page = split_page(s)
            pending["title"] = (pending["title"] + " " + title_part).strip()
            pending["page"] = page
            entries.append(pending)
            pending = None
        else:
            unparsed.append(ln.rstrip())
        continue

    # We have a labelled entry. Flush any dangling buffer first (shouldn't happen).
    if pending is not None:
        entries.append(pending)
        pending = None

    if kind == "front":
        title, page = split_page(rest if rest != s else num)
        # For Preface/Index the label IS the title.
        title2, page = split_page(s)
        title = num
        entries.append({"kind": kind, "num": num, "title": title, "page": page})
        continue

    title, page = split_page(rest)
    node = {"kind": kind, "num": num, "title": title, "page": page}
    if page is None:
        pending = node          # wrapped title; wait for continuation
    else:
        entries.append(node)

if pending is not None:
    entries.append(pending)

# 3. Emit markdown, grouped by chapter — purely from parsed data.
out = []
out.append("# SQL Cookbook, 2nd Edition (Molinaro & de Graaf) — Table of Contents")
out.append("")
out.append("_Extracted programmatically from the source PDF (pages 7–12) with "
           "`pdftotext -layout`, then parsed by `parse_toc.py`. No title or page "
           "number was transcribed by hand._")
out.append("")

recipe_count = 0
chapter_count = 0
for e in entries:
    t = e["title"]
    p = e["page"]
    if e["kind"] == "front":
        out.append(f"- **{t}** — p. {p}")
    elif e["kind"] == "chapter":
        chapter_count += 1
        out.append("")
        out.append(f"## {e['num']}. {t} — p. {p}")
    elif e["kind"] == "appendix":
        out.append("")
        out.append(f"## Appendix {e['num']}. {t} — p. {p}")
    elif e["kind"] == "recipe":
        recipe_count += 1
        out.append(f"- {e['num']} {t} — p. {p}")

md = "\n".join(out) + "\n"
with open("/workspace/webdev/RESOURCE/SQL_Cookbook_TOC.md", "w") as f:
    f.write(md)

with open("/workspace/webdev/RESOURCE/SQL_Cookbook_TOC.json", "w") as f:
    json.dump(entries, f, indent=2, ensure_ascii=False)

# 4. Integrity report.
print(f"chapters parsed : {chapter_count}")
print(f"recipes parsed  : {recipe_count}")
print(f"total entries   : {len(entries)}")
print(f"UNPARSED lines  : {len(unparsed)}")
for u in unparsed:
    print("   !! " + repr(u))
