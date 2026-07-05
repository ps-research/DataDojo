import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../lib/api";
import { BeltBadge, BELT_META, Pill } from "../components/Badges";
import { CheckIcon, LockIcon } from "../components/icons";

interface ProblemItem {
  slug: string;
  number: number;
  title: string;
  belt: string;
  category: string;
  universe: string;
  engines: string[];
  points: number;
  solved: boolean;
  locked: boolean;
}

const BELT_ORDER = ["white", "blue", "purple", "black", "red"];

export function ProblemsPage() {
  const [problems, setProblems] = useState<ProblemItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [belt, setBelt] = useState<string>("");
  const [universe, setUniverse] = useState<string>("");
  const [query, setQuery] = useState("");

  useEffect(() => {
    void api<{ problems: ProblemItem[] }>("/api/problems")
      .then((d) => setProblems(d.problems))
      .finally(() => setLoading(false));
  }, []);

  const universes = useMemo(
    () => [...new Set(problems.map((p) => p.universe).filter(Boolean))].sort(),
    [problems]
  );
  const filtered = useMemo(
    () =>
      problems.filter(
        (p) =>
          (!belt || p.belt === belt) &&
          (!universe || p.universe === universe) &&
          (!query || p.title.toLowerCase().includes(query.toLowerCase()))
      ),
    [problems, belt, universe, query]
  );
  const solvedCount = problems.filter((p) => p.solved).length;
  const pct = problems.length ? Math.round((solvedCount / problems.length) * 100) : 0;

  const chip = (active: boolean) =>
    `rounded-lg px-3 py-1.5 text-[13px] transition-colors ${
      active
        ? "bg-zinc-900 text-white dark:bg-zinc-100 dark:text-zinc-900"
        : "text-zinc-500 hover:bg-zinc-100 dark:text-zinc-400 dark:hover:bg-zinc-800"
    }`;

  return (
    <div className="mx-auto max-w-5xl px-4 py-8">
      <div className="mb-6">
        <h1 className="text-2xl font-semibold tracking-tight">Problems</h1>
        <div className="mt-3 flex items-center gap-3">
          <div className="h-1.5 w-40 overflow-hidden rounded-full bg-zinc-200 dark:bg-zinc-800">
            <div className="h-full rounded-full bg-brand transition-all" style={{ width: `${pct}%` }} />
          </div>
          <span className="text-sm text-zinc-500 dark:text-zinc-400">
            {solvedCount} / {problems.length} solved
          </span>
        </div>
      </div>

      <div className="mb-5 flex flex-wrap items-center gap-2">
        <button onClick={() => setBelt("")} className={chip(!belt)}>All</button>
        {BELT_ORDER.map((b) => (
          <button key={b} onClick={() => setBelt(belt === b ? "" : b)} className={chip(belt === b)}>
            {BELT_META[b].label}
          </button>
        ))}
        <div className="ml-auto flex items-center gap-2">
          {universes.length > 0 && (
            <select className="input w-auto py-2" value={universe} onChange={(e) => setUniverse(e.target.value)}>
              <option value="">All universes</option>
              {universes.map((u) => (
                <option key={u} value={u}>{u}</option>
              ))}
            </select>
          )}
          <input className="input w-40 py-2" placeholder="Search" value={query} onChange={(e) => setQuery(e.target.value)} />
        </div>
      </div>

      <div className="card overflow-hidden">
        <div className="divide-y divide-zinc-100 dark:divide-zinc-800">
          {loading && <div className="p-8 text-center text-sm text-zinc-400">Loading...</div>}
          {!loading && filtered.length === 0 && (
            <div className="p-8 text-center text-sm text-zinc-400">No problems match those filters.</div>
          )}
          {filtered.map((p) => (
            <Link
              key={p.slug}
              to={p.locked ? "#" : `/problems/${p.slug}`}
              onClick={(e) => p.locked && e.preventDefault()}
              className={`flex items-center gap-4 px-4 py-3 transition-colors ${
                p.locked ? "cursor-not-allowed opacity-50" : "hover:bg-zinc-50 dark:hover:bg-zinc-800/50"
              }`}
            >
              <span className="flex w-5 flex-none justify-center">
                {p.solved ? (
                  <span className="text-emerald-500" title="Solved"><CheckIcon /></span>
                ) : p.locked ? (
                  <span className="text-zinc-400" title="Locked - solve its prerequisite first"><LockIcon /></span>
                ) : (
                  <span className="font-mono text-xs text-zinc-300 dark:text-zinc-600">{p.number}</span>
                )}
              </span>
              <span className="min-w-0 flex-1 truncate text-sm">{p.title}</span>
              {p.universe && <Pill>{p.universe}</Pill>}
              <span className="hidden font-mono text-xs text-zinc-400 sm:inline">{p.points} pts</span>
              <span className="w-14 text-right"><BeltBadge belt={p.belt} /></span>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
