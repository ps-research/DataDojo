import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../lib/api";
import { BeltBadge, BELT_META, CollectionBadge } from "../components/Badges";
import { CheckIcon, LockIcon } from "../components/icons";
import { collectionKey, collectionLabel } from "../lib/collections";

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
const BELT_RANK: Record<string, number> = { white: 0, blue: 1, purple: 2, black: 3, red: 4 };

type SortKey = "number" | "difficulty" | "points-desc" | "points-asc" | "title" | "solved";
const SORTS: { key: SortKey; label: string }[] = [
  { key: "number", label: "Default" },
  { key: "difficulty", label: "Difficulty" },
  { key: "points-desc", label: "Points: high to low" },
  { key: "points-asc", label: "Points: low to high" },
  { key: "title", label: "Title A-Z" },
  { key: "solved", label: "Unsolved first" },
];

export function ProblemsPage() {
  const [problems, setProblems] = useState<ProblemItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [belt, setBelt] = useState("");
  const [collection, setCollection] = useState("");
  const [query, setQuery] = useState("");
  const [sort, setSort] = useState<SortKey>("number");

  useEffect(() => {
    void api<{ problems: ProblemItem[] }>("/api/problems")
      .then((d) => setProblems(d.problems))
      .finally(() => setLoading(false));
  }, []);

  // collections present, ordered: universes, then Tutorial/Python/R
  const collections = useMemo(() => {
    const keys = new Set(problems.map((p) => collectionKey(p)));
    const order = ["pulsestream", "carthive", "rideloop", "medicore", "metricforge", "tickforge", "__tutorial", "__python", "__r"];
    return order.filter((k) => keys.has(k));
  }, [problems]);

  const filtered = useMemo(() => {
    const out = problems.filter(
      (p) =>
        (!belt || p.belt === belt) &&
        (!collection || collectionKey(p) === collection) &&
        (!query || p.title.toLowerCase().includes(query.toLowerCase()))
    );
    const cmp: Record<SortKey, (a: ProblemItem, b: ProblemItem) => number> = {
      number: (a, b) => a.number - b.number,
      difficulty: (a, b) => BELT_RANK[a.belt] - BELT_RANK[b.belt] || a.number - b.number,
      "points-desc": (a, b) => b.points - a.points || a.number - b.number,
      "points-asc": (a, b) => a.points - b.points || a.number - b.number,
      title: (a, b) => a.title.localeCompare(b.title),
      solved: (a, b) => Number(a.solved) - Number(b.solved) || a.number - b.number,
    };
    return [...out].sort(cmp[sort]);
  }, [problems, belt, collection, query, sort]);

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
          <span className="text-sm text-zinc-500 dark:text-zinc-400">{solvedCount} / {problems.length} solved</span>
        </div>
      </div>

      <div className="mb-3 flex flex-wrap items-center gap-2">
        <button onClick={() => setBelt("")} className={chip(!belt)}>All belts</button>
        {BELT_ORDER.map((b) => (
          <button key={b} onClick={() => setBelt(belt === b ? "" : b)} className={chip(belt === b)}>
            {BELT_META[b].label}
          </button>
        ))}
      </div>

      <div className="mb-5 flex flex-wrap items-center gap-2">
        <button onClick={() => setCollection("")} className={chip(!collection)}>All collections</button>
        {collections.map((k) => (
          <button key={k} onClick={() => setCollection(collection === k ? "" : k)} className={chip(collection === k)}>
            {collectionLabel(k)}
          </button>
        ))}
        <div className="ml-auto flex items-center gap-2">
          <select className="input w-auto py-2" value={sort} onChange={(e) => setSort(e.target.value as SortKey)}>
            {SORTS.map((s) => (
              <option key={s.key} value={s.key}>Sort: {s.label}</option>
            ))}
          </select>
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
                  <span className="text-zinc-400"><LockIcon /></span>
                ) : (
                  <span className="font-mono text-xs text-zinc-300 dark:text-zinc-600">{p.number}</span>
                )}
              </span>
              <span className="min-w-0 flex-1 truncate text-sm">{p.title}</span>
              <CollectionBadge collectionKey={collectionKey(p)} />
              <span className="hidden w-16 text-right font-mono text-xs text-zinc-400 sm:inline">{p.points} pts</span>
              <span className="w-14 text-right"><BeltBadge belt={p.belt} /></span>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
