import type { ResultSet } from "../types.js";

// Canonical comparison: NULL sentinel, int/float unification (6dp), trimmed
// strings, dates to YYYY-MM-DD. When order does not matter rows are sorted
// post-normalization; column order always follows the query.

function normValue(v: unknown): string {
  if (v === null || v === undefined) return "∅";
  if (typeof v === "number") {
    if (Number.isInteger(v)) return String(v);
    return String(parseFloat(v.toFixed(6)));
  }
  if (typeof v === "bigint") return v.toString();
  if (v instanceof Date) return v.toISOString().slice(0, 10);
  if (Buffer.isBuffer(v)) return v.toString("hex");
  const s = String(v).trim();
  if (/^-?\d+$/.test(s)) return s;
  if (/^-?\d+\.\d+(e[+-]?\d+)?$/i.test(s)) return String(parseFloat(s));
  // ISO timestamps with midnight time collapse to date (engines disagree here)
  const dm = s.match(/^(\d{4}-\d{2}-\d{2})[T ]00:00:00(\.0+)?(Z|[+-]00:?00)?$/);
  if (dm) return dm[1];
  return s;
}

export function canonicalize(rs: ResultSet, orderMatters: boolean): string {
  const body = rs.rows.map((r) => r.map(normValue).join(""));
  if (!orderMatters) body.sort();
  return `${rs.rows.length}${body.join("")}`;
}

export function resultsEqual(expected: ResultSet, actual: ResultSet, orderMatters: boolean): boolean {
  if (expected.columns.length !== actual.columns.length) return false;
  return canonicalize(expected, orderMatters) === canonicalize(actual, orderMatters);
}
