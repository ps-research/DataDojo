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
      <h1 className="mb-1 text-xl font-semibold tracking-tight">Leaderboard</h1>
      <p className="mb-6 text-sm text-stone-500 dark:text-stone-400">Points from first-time solves. Belts are earned, not given.</p>
      <div className="card divide-y divide-stone-100 dark:divide-stone-800">
        {loading && <div className="p-6 text-sm text-stone-400">Loading...</div>}
        {!loading && entries.length === 0 && (
          <div className="p-6 text-sm text-stone-400">No solves yet. Be the first on the mat.</div>
        )}
        {entries.map((e) => (
          <div key={e.rank} className="flex items-center gap-4 px-4 py-3">
            <span
              className={`w-8 text-center font-mono text-sm ${
                e.rank <= 3 ? "font-bold text-accent" : "text-stone-400"
              }`}
            >
              {e.rank}
            </span>
            <span className="flex-1 text-sm font-medium">{e.name}</span>
            <span className="text-xs text-stone-400">{e.solvedCount} solved</span>
            <span className="w-16 text-right font-mono text-sm">{e.score}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
