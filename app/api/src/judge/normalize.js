// Canonicalize a result set { columns, rows } into a comparable string form.
// If orderMatters is false, rows are sorted so row order doesn't affect the
// verdict; column order is always preserved (the query defines it). Values are
// stringified with light numeric normalization so 1 vs 1.0 compare equal.

function normValue(v) {
  if (v === null || v === undefined) return "∅"; // explicit NULL marker
  if (typeof v === "number") {
    return Number.isInteger(v) ? String(v) : String(parseFloat(v.toFixed(6)));
  }
  if (typeof v === "bigint") return v.toString();
  if (v instanceof Date) return v.toISOString().slice(0, 10);
  if (Buffer.isBuffer(v)) return v.toString("hex");
  const s = String(v).trim();
  // numeric-looking strings normalized too (engines vary int vs string)
  if (/^-?\d+$/.test(s)) return s;
  if (/^-?\d+\.\d+$/.test(s)) return String(parseFloat(s));
  return s;
}

export function canonicalize({ columns, rows }, orderMatters) {
  const body = rows.map((r) =>
    (Array.isArray(r) ? r : columns.map((c) => r[c])).map(normValue).join("")
  );
  if (!orderMatters) body.sort();
  return JSON.stringify({ n: rows.length, body });
}

export function compare(expected, actual, orderMatters) {
  return canonicalize(expected, orderMatters) === canonicalize(actual, orderMatters);
}
