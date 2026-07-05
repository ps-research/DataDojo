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
      <div className="mb-1 flex items-baseline gap-3">
        <h1 className="font-serif text-2xl tracking-tight">Ranking</h1>
        <span className="kanji text-xl">番付</span>
      </div>
      <p className="mb-6 text-sm text-sumi/55 dark:text-washi-100/55">
        The banzuke. Points from first clears — belts are earned, never given.
      </p>
      <div className="card divide-y divide-washi-200 dark:divide-sumi-700">
        {loading && <div className="p-6 text-sm text-sumi/40">Reading the board...</div>}
        {!loading && entries.length === 0 && (
          <div className="p-6 text-sm text-sumi/40">No clears yet. Be first on the mat.</div>
        )}
        {entries.map((e) => (
          <div key={e.rank} className="flex items-center gap-4 px-4 py-3">
            <span className={`w-8 text-center font-serif text-lg ${e.rank <= 3 ? "font-bold text-shu" : "text-sumi/40"}`}>
              {e.rank}
            </span>
            <span className="flex-1 text-sm font-medium">{e.name}</span>
            <span className="text-xs text-sumi/45">{e.solvedCount} cleared</span>
            <span className="w-16 text-right font-mono text-sm">{e.score}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
