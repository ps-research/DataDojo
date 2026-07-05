import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../lib/api";
import { BELT_META, VerdictBadge } from "../components/Badges";
import { engineLabel } from "../lib/engines";

interface Stats {
  user: { name: string; email: string; score: number };
  solvedByBelt: Record<string, number>;
  totalByBelt: Record<string, number>;
  totalSolved: number;
  totalSubmissions: number;
  acSubmissions: number;
  acRate: number;
  verdictCounts: Record<string, number>;
  languages: { engine: string; count: number }[];
  recent: { problemSlug: string; engine: string; verdict: string | null; runtimeMs: number; createdAt: string }[];
}

const BELTS = ["white", "blue", "purple", "black", "red"];

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="card p-4">
      <div className="text-2xl font-semibold tracking-tight">{value}</div>
      <div className="mt-0.5 text-xs text-zinc-500 dark:text-zinc-400">{label}</div>
    </div>
  );
}

export function ProfilePage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    void api<Stats>("/api/users/me/stats")
      .then(setStats)
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <div className="p-10 text-center text-sm text-zinc-400">Loading...</div>;
  if (!stats) return <div className="p-10 text-center text-sm text-zinc-400">Could not load your stats.</div>;

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <div className="mb-6 flex items-end justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">{stats.user.name}</h1>
          <p className="mt-0.5 text-sm text-zinc-500 dark:text-zinc-400">{stats.user.email}</p>
        </div>
        <Link to="/settings" className="btn-ghost border border-zinc-300 text-sm dark:border-zinc-700">
          Settings
        </Link>
      </div>

      <div className="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Stat label="Problems solved" value={stats.totalSolved} />
        <Stat label="Total points" value={stats.user.score} />
        <Stat label="Submissions" value={stats.totalSubmissions} />
        <Stat label="Acceptance rate" value={`${stats.acRate}%`} />
      </div>

      <div className="mb-6 grid gap-4 md:grid-cols-2">
        <div className="card p-5">
          <h2 className="mb-3 text-sm font-semibold">Progress by belt</h2>
          <div className="space-y-2.5">
            {BELTS.map((b) => {
              const solved = stats.solvedByBelt[b] ?? 0;
              const total = stats.totalByBelt[b] ?? 0;
              const pct = total ? Math.round((solved / total) * 100) : 0;
              return (
                <div key={b}>
                  <div className="mb-1 flex justify-between text-xs">
                    <span className={BELT_META[b].text}>{BELT_META[b].label}</span>
                    <span className="text-zinc-400">{solved} / {total}</span>
                  </div>
                  <div className="h-1.5 overflow-hidden rounded-full bg-zinc-200 dark:bg-zinc-800">
                    <div className="h-full rounded-full bg-brand" style={{ width: `${pct}%` }} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <div className="card p-5">
          <h2 className="mb-3 text-sm font-semibold">Languages used</h2>
          {stats.languages.length === 0 ? (
            <p className="text-sm text-zinc-400">No submissions yet.</p>
          ) : (
            <div className="space-y-2">
              {stats.languages.map((l) => {
                const max = stats.languages[0].count || 1;
                return (
                  <div key={l.engine} className="flex items-center gap-3">
                    <span className="w-28 flex-none text-xs text-zinc-500 dark:text-zinc-400">{engineLabel(l.engine)}</span>
                    <div className="h-2 flex-1 overflow-hidden rounded-full bg-zinc-100 dark:bg-zinc-800">
                      <div className="h-full rounded-full bg-brand/70" style={{ width: `${(l.count / max) * 100}%` }} />
                    </div>
                    <span className="w-8 flex-none text-right font-mono text-xs text-zinc-400">{l.count}</span>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      <div className="card p-5">
        <h2 className="mb-3 text-sm font-semibold">Recent activity</h2>
        {stats.recent.length === 0 ? (
          <p className="text-sm text-zinc-400">Nothing yet. Go solve something.</p>
        ) : (
          <div className="divide-y divide-zinc-100 dark:divide-zinc-800">
            {stats.recent.map((s, i) => (
              <div key={i} className="flex items-center gap-3 py-2 text-sm">
                <VerdictBadge verdict={s.verdict} />
                <Link to={`/problems/${s.problemSlug}`} className="min-w-0 flex-1 truncate text-zinc-700 hover:text-brand dark:text-zinc-300">
                  {s.problemSlug}
                </Link>
                <span className="text-xs text-zinc-400">{engineLabel(s.engine)}</span>
                <span className="text-xs text-zinc-400">{new Date(s.createdAt).toLocaleString()}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
