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

  return (
    <div className="mx-auto max-w-5xl px-4 py-10">
      {/* header */}
      <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-[26px] font-semibold tracking-tight">Problems</h1>
          <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
            Sharpen your SQL, pandas, and R against a real judge.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className="text-right">
            <div className="text-lg font-semibold tabular-nums">{solvedCount}<span className="text-zinc-400"> / {problems.length}</span></div>
            <div className="text-xs text-zinc-400">solved</div>
          </div>
          <div className="relative h-11 w-11">
            <svg viewBox="0 0 36 36" className="h-11 w-11 -rotate-90">
              <circle cx="18" cy="18" r="15" fill="none" strokeWidth="3" className="stroke-zinc-200 dark:stroke-zinc-800" />
              <circle
                cx="18" cy="18" r="15" fill="none" strokeWidth="3" strokeLinecap="round"
                className="stroke-brand"
                strokeDasharray={`${(pct / 100) * 94.25} 94.25`}
              />
            </svg>
            <span className="absolute inset-0 flex items-center justify-center text-[11px] font-medium tabular-nums">{pct}%</span>
          </div>
        </div>
      </div>

      {/* filters */}
      <div className="mb-6 space-y-3">
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="mr-1 text-xs font-medium uppercase tracking-wide text-zinc-400">Belt</span>
          <FilterChip active={!belt} onClick={() => setBelt("")}>All</FilterChip>
          {BELT_ORDER.map((b) => (
            <FilterChip key={b} active={belt === b} onClick={() => setBelt(belt === b ? "" : b)}>
              {BELT_META[b].label}
            </FilterChip>
          ))}
        </div>
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="mr-1 text-xs font-medium uppercase tracking-wide text-zinc-400">Track</span>
          <FilterChip active={!collection} onClick={() => setCollection("")}>All</FilterChip>
          {collections.map((k) => (
            <FilterChip key={k} active={collection === k} onClick={() => setCollection(collection === k ? "" : k)}>
              {collectionLabel(k)}
            </FilterChip>
          ))}
          <div className="ml-auto flex items-center gap-2">
            <select className="input w-auto py-1.5 text-[13px]" value={sort} onChange={(e) => setSort(e.target.value as SortKey)}>
              {SORTS.map((s) => (
                <option key={s.key} value={s.key}>Sort: {s.label}</option>
              ))}
            </select>
            <input className="input w-36 py-1.5 text-[13px]" placeholder="Search" value={query} onChange={(e) => setQuery(e.target.value)} />
          </div>
        </div>
      </div>

      {/* list */}
      <div className="card overflow-hidden">
        <div className="divide-y divide-zinc-100 dark:divide-zinc-800/70">
          {loading && <div className="p-10 text-center text-sm text-zinc-400">Loading...</div>}
          {!loading && filtered.length === 0 && (
            <div className="p-10 text-center text-sm text-zinc-400">No problems match those filters.</div>
          )}
          {filtered.map((p) => (
            <Link
              key={p.slug}
              to={p.locked ? "#" : `/problems/${p.slug}`}
              onClick={(e) => p.locked && e.preventDefault()}
              className={`group flex items-center gap-4 px-5 py-3.5 transition-colors ${
                p.locked ? "cursor-not-allowed opacity-50" : "hover:bg-zinc-50 dark:hover:bg-zinc-800/40"
              }`}
            >
              <span className="flex w-5 flex-none justify-center">
                {p.solved ? (
                  <span className="text-emerald-500" title="Solved"><CheckIcon /></span>
                ) : p.locked ? (
                  <span className="text-zinc-400"><LockIcon /></span>
                ) : (
                  <span className="font-mono text-xs text-zinc-300 tabular-nums dark:text-zinc-600">{p.number}</span>
                )}
              </span>
              <span className={`min-w-0 flex-1 truncate text-[15px] ${p.solved ? "text-zinc-500 dark:text-zinc-400" : "text-zinc-800 dark:text-zinc-100"} group-hover:text-zinc-900 dark:group-hover:text-white`}>
                {p.title}
              </span>
              <span className="hidden w-32 flex-none sm:block"><CollectionBadge collectionKey={collectionKey(p)} /></span>
              <span className="hidden w-16 flex-none text-right font-mono text-xs text-zinc-400 tabular-nums md:block">{p.points} pts</span>
              <span className="w-14 flex-none text-right"><BeltBadge belt={p.belt} /></span>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}

function FilterChip({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      onClick={onClick}
      className={`rounded-full px-3 py-1 text-[13px] transition-colors ${
        active
          ? "bg-zinc-900 text-white dark:bg-zinc-100 dark:text-zinc-900"
          : "bg-zinc-100 text-zinc-500 hover:bg-zinc-200 hover:text-zinc-700 dark:bg-zinc-800/70 dark:text-zinc-400 dark:hover:bg-zinc-800"
      }`}
    >
      {children}
    </button>
  );
}
