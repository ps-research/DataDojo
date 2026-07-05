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

  return (
    <div className="mx-auto max-w-6xl px-4 py-8">
      <div className="mb-6 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Problems</h1>
          <p className="mt-0.5 text-sm text-stone-500 dark:text-stone-400">
            {problems.length} problems · {solvedCount} solved
          </p>
        </div>
        <input
          className="input max-w-56"
          placeholder="Search titles"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </div>

      <div className="mb-4 flex flex-wrap items-center gap-2">
        <button
          onClick={() => setBelt("")}
          className={`rounded-full px-3 py-1 text-xs transition-colors ${!belt ? "bg-stone-800 text-white dark:bg-stone-200 dark:text-stone-900" : "bg-stone-100 text-stone-500 hover:text-stone-800 dark:bg-stone-800 dark:text-stone-400"}`}
        >
          All belts
        </button>
        {BELT_ORDER.map((b) => (
          <button
            key={b}
            onClick={() => setBelt(belt === b ? "" : b)}
            className={`rounded-full px-3 py-1 text-xs transition-colors ${belt === b ? "bg-stone-800 text-white dark:bg-stone-200 dark:text-stone-900" : "bg-stone-100 text-stone-500 hover:text-stone-800 dark:bg-stone-800 dark:text-stone-400"}`}
          >
            {BELT_META[b].label}
          </button>
        ))}
        {universes.length > 0 && (
          <select className="input ml-auto w-auto" value={universe} onChange={(e) => setUniverse(e.target.value)}>
            <option value="">All universes</option>
            {universes.map((u) => (
              <option key={u} value={u}>
                {u}
              </option>
            ))}
          </select>
        )}
      </div>

      <div className="card divide-y divide-stone-100 dark:divide-stone-800">
        {loading && <div className="p-6 text-sm text-stone-400">Loading problems...</div>}
        {!loading && filtered.length === 0 && (
          <div className="p-6 text-sm text-stone-400">Nothing matches those filters.</div>
        )}
        {filtered.map((p) => (
          <Link
            key={p.slug}
            to={p.locked ? "#" : `/problems/${p.slug}`}
            aria-disabled={p.locked}
            onClick={(e) => p.locked && e.preventDefault()}
            className={`flex items-center gap-4 px-4 py-3 transition-colors ${
              p.locked ? "cursor-not-allowed opacity-55" : "hover:bg-stone-50 dark:hover:bg-stone-800/60"
            }`}
          >
            <span className="w-6 flex-none text-center">
              {p.solved ? (
                <span className="text-emerald-500" title="Solved">
                  <CheckIcon />
                </span>
              ) : p.locked ? (
                <span className="text-stone-400" title="Locked — solve the prerequisite first">
                  <LockIcon />
                </span>
              ) : (
                <span className="text-xs text-stone-300 dark:text-stone-600">{p.number}</span>
              )}
            </span>
            <span className="min-w-0 flex-1 truncate text-sm font-medium">{p.title}</span>
            {p.universe && <Pill>{p.universe}</Pill>}
            <span className="hidden text-xs text-stone-400 sm:inline">{p.engines.length} engines</span>
            <span className="w-14 text-right text-xs text-stone-400">{p.points} pts</span>
            <span className="w-16 text-right">
              <BeltBadge belt={p.belt} />
            </span>
          </Link>
        ))}
      </div>
    </div>
  );
}
