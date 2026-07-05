import { useMemo } from "react";

// Deliberately small markdown renderer (headings, bold/italic/code, fenced
// blocks, tables, lists) — enough for problem statements, zero dependencies,
// and output is escaped before markup is applied.

function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function inline(s: string): string {
  return s
    .replace(/`([^`]+)`/g, (_m, c: string) => `<code>${c}</code>`)
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/(^|[^*])\*([^*\n]+)\*/g, "$1<em>$2</em>");
}

function render(md: string): string {
  const lines = escapeHtml(md.replace(/\r\n/g, "\n")).split("\n");
  const out: string[] = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (line.startsWith("```")) {
      const buf: string[] = [];
      i++;
      while (i < lines.length && !lines[i].startsWith("```")) buf.push(lines[i++]);
      i++;
      out.push(`<pre><code>${buf.join("\n")}</code></pre>`);
      continue;
    }
    if (/^#{1,3} /.test(line)) {
      const level = line.match(/^#+/)![0].length;
      out.push(`<h${level}>${inline(line.replace(/^#+ /, ""))}</h${level}>`);
      i++;
      continue;
    }
    if (line.includes("|") && i + 1 < lines.length && /^\s*\|?[\s:|-]+\|?\s*$/.test(lines[i + 1]) && lines[i + 1].includes("-")) {
      const parseRow = (l: string) => l.replace(/^\||\|$/g, "").split("|").map((c) => inline(c.trim()));
      const header = parseRow(line);
      i += 2;
      const rows: string[][] = [];
      while (i < lines.length && lines[i].includes("|")) rows.push(parseRow(lines[i++]));
      out.push(
        `<table><thead><tr>${header.map((h) => `<th>${h}</th>`).join("")}</tr></thead><tbody>${rows
          .map((r) => `<tr>${r.map((c) => `<td>${c}</td>`).join("")}</tr>`)
          .join("")}</tbody></table>`
      );
      continue;
    }
    if (/^[-*] /.test(line)) {
      const items: string[] = [];
      while (i < lines.length && /^[-*] /.test(lines[i])) items.push(`<li>${inline(lines[i++].slice(2))}</li>`);
      out.push(`<ul>${items.join("")}</ul>`);
      continue;
    }
    if (/^\d+\. /.test(line)) {
      const items: string[] = [];
      while (i < lines.length && /^\d+\. /.test(lines[i])) items.push(`<li>${inline(lines[i++].replace(/^\d+\. /, ""))}</li>`);
      out.push(`<ol>${items.join("")}</ol>`);
      continue;
    }
    if (line.trim() === "") {
      i++;
      continue;
    }
    const buf: string[] = [line];
    i++;
    while (i < lines.length && lines[i].trim() !== "" && !/^(#|```|[-*] |\d+\. )/.test(lines[i]) && !lines[i].includes("|")) {
      buf.push(lines[i++]);
    }
    out.push(`<p>${inline(buf.join(" "))}</p>`);
  }
  return out.join("\n");
}

export function Markdown({ source }: { source: string }) {
  const html = useMemo(() => render(source), [source]);
  return <div className="statement text-sm" dangerouslySetInnerHTML={{ __html: html }} />;
}
