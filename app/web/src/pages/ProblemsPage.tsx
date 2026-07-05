import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../lib/api";
import { BeltBadge, BELT_META, Pill } from "../components/Badges";
import { LockIcon } from "../components/icons";

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

  const chip = (active: boolean) =>
    `rounded-full px-3 py-1 text-xs transition-colors ${
      active
        ? "bg-sumi text-washi-50 dark:bg-washi-100 dark:text-sumi"
        : "bg-washi-200 text-sumi/55 hover:text-sumi dark:bg-sumi-700 dark:text-washi-100/55"
    }`;

  return (
    <div className="mx-auto max-w-6xl px-4 py-8">
      <div className="mb-6 flex flex-wrap items-end justify-between gap-3">
        <div className="flex items-baseline gap-3">
          <h1 className="font-serif text-2xl tracking-tight">Problems</h1>
          <span className="kanji text-xl">型</span>
          <p className="text-sm text-sumi/55 dark:text-washi-100/55">
            {solvedCount} of {problems.length} cleared
          </p>
        </div>
        <input className="input max-w-56" placeholder="Search" value={query} onChange={(e) => setQuery(e.target.value)} />
      </div>

      <div className="mb-4 flex flex-wrap items-center gap-2">
        <button onClick={() => setBelt("")} className={chip(!belt)}>All</button>
        {BELT_ORDER.map((b) => (
          <button key={b} onClick={() => setBelt(belt === b ? "" : b)} className={chip(belt === b)}>
            {BELT_META[b].label}
          </button>
        ))}
        {universes.length > 0 && (
          <select className="input ml-auto w-auto" value={universe} onChange={(e) => setUniverse(e.target.value)}>
            <option value="">All universes</option>
            {universes.map((u) => (
              <option key={u} value={u}>{u}</option>
            ))}
          </select>
        )}
      </div>

      <div className="card divide-y divide-washi-200 dark:divide-sumi-700">
        {loading && <div className="p-6 text-sm text-sumi/40">Unrolling the scrolls...</div>}
        {!loading && filtered.length === 0 && <div className="p-6 text-sm text-sumi/40">Nothing matches.</div>}
        {filtered.map((p) => (
          <Link
            key={p.slug}
            to={p.locked ? "#" : `/problems/${p.slug}`}
            onClick={(e) => p.locked && e.preventDefault()}
            className={`flex items-center gap-4 px-4 py-3 transition-colors ${
              p.locked ? "cursor-not-allowed opacity-55" : "hover:bg-washi-100 dark:hover:bg-sumi-700/50"
            }`}
          >
            <span className="flex w-7 flex-none justify-center">
              {p.solved ? (
                <span className="seal" title="Cleared">済</span>
              ) : p.locked ? (
                <span className="text-sumi/40" title="Locked — clear the prerequisite">
                  <LockIcon />
                </span>
              ) : (
                <span className="font-mono text-xs text-sumi/30 dark:text-washi-100/25">{p.number}</span>
              )}
            </span>
            <span className="min-w-0 flex-1 truncate text-sm font-medium">{p.title}</span>
            {p.universe && <Pill>{p.universe}</Pill>}
            <span className="hidden font-mono text-xs text-sumi/40 sm:inline">{p.engines.length} eng</span>
            <span className="w-12 text-right font-mono text-xs text-sumi/45">{p.points}</span>
            <span className="w-16 text-right"><BeltBadge belt={p.belt} /></span>
          </Link>
        ))}
      </div>
    </div>
  );
}
