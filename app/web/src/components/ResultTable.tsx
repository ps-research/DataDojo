export interface ResultSet {
  columns: string[];
  rows: unknown[][];
  truncated?: boolean;
  rowCount?: number;
}

export function ResultTable({ result }: { result: ResultSet }) {
  if (result.columns.length === 0) {
    return <p className="px-4 py-3 text-sm text-zinc-500 dark:text-zinc-400">Statement ran. No rows returned.</p>;
  }
  return (
    <div className="overflow-auto">
      <table className="w-full border-collapse text-sm">
        <thead className="sticky top-0 bg-zinc-50 dark:bg-zinc-900">
          <tr>
            {result.columns.map((c, i) => (
              <th key={i} className="border-b border-zinc-200 px-3 py-2 text-left font-medium text-zinc-600 dark:border-zinc-800 dark:text-zinc-300">
                {c}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {result.rows.map((row, ri) => (
            <tr key={ri} className="odd:bg-zinc-50/50 dark:odd:bg-zinc-800/30">
              {row.map((v, ci) => (
                <td key={ci} className="whitespace-nowrap border-b border-zinc-100 px-3 py-1.5 font-mono text-xs text-zinc-700 dark:border-zinc-800/60 dark:text-zinc-300">
                  {v === null || v === undefined ? <span className="text-zinc-400 italic">null</span> : String(v)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
      {result.truncated && (
        <p className="px-3 py-2 text-xs text-zinc-400">
          Showing first 200 of {result.rowCount} rows.
        </p>
      )}
    </div>
  );
}
