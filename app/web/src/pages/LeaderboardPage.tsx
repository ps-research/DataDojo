import { useEffect, useState } from "react";
import { api } from "../lib/api";

interface Entry {
  rank: number;
  name: string;
  solvedCount: number;
  score: number;
}

export function LeaderboardPage() {
  const [entries, setEntries] = useState<Entry[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    void api<{ entries: Entry[] }>("/api/leaderboard")
      .then((d) => setEntries(d.entries))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="mx-auto max-w-2xl px-4 py-8">
      <h1 className="text-2xl font-semibold tracking-tight">Leaderboard</h1>
      <p className="mb-6 mt-1 text-sm text-zinc-500 dark:text-zinc-400">
        Points from first-time solves.
      </p>
      <div className="card overflow-hidden">
        <div className="divide-y divide-zinc-100 dark:divide-zinc-800">
          {loading && <div className="p-8 text-center text-sm text-zinc-400">Loading...</div>}
          {!loading && entries.length === 0 && (
            <div className="p-8 text-center text-sm text-zinc-400">No solves yet.</div>
          )}
          {entries.map((e) => (
            <div key={e.rank} className="flex items-center gap-4 px-4 py-3">
              <span className={`w-7 text-center font-mono text-sm ${e.rank <= 3 ? "font-semibold text-brand" : "text-zinc-400"}`}>
                {e.rank}
              </span>
              <span className="flex-1 text-sm">{e.name}</span>
              <span className="text-xs text-zinc-400">{e.solvedCount} solved</span>
              <span className="w-14 text-right font-mono text-sm text-zinc-700 dark:text-zinc-300">{e.score}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
