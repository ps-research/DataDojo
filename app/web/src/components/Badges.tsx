import type { ReactNode } from "react";

export const BELT_META: Record<string, { label: string; dot: string; text: string }> = {
  white: { label: "White", dot: "bg-stone-300", text: "text-stone-500 dark:text-stone-400" },
  blue: { label: "Blue", dot: "bg-sky-500", text: "text-sky-600 dark:text-sky-400" },
  purple: { label: "Purple", dot: "bg-violet-500", text: "text-violet-600 dark:text-violet-400" },
  black: { label: "Black", dot: "bg-stone-900 dark:bg-stone-100", text: "text-stone-900 dark:text-stone-100" },
  red: { label: "Red", dot: "bg-red-600", text: "text-red-600 dark:text-red-400" },
};

export function BeltBadge({ belt }: { belt: string }) {
  const m = BELT_META[belt] ?? BELT_META.white;
  return (
    <span className={`inline-flex items-center gap-1.5 text-xs font-medium ${m.text}`}>
      <span className={`h-2 w-2 rounded-full ${m.dot}`} />
      {m.label}
    </span>
  );
}

const VERDICT_STYLE: Record<string, string> = {
  AC: "bg-emerald-50 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-400",
  WA: "bg-red-50 text-red-700 dark:bg-red-950 dark:text-red-400",
  TLE: "bg-amber-50 text-amber-700 dark:bg-amber-950 dark:text-amber-400",
  RE: "bg-orange-50 text-orange-700 dark:bg-orange-950 dark:text-orange-400",
  CE: "bg-stone-100 text-stone-600 dark:bg-stone-800 dark:text-stone-300",
};

export function VerdictBadge({ verdict }: { verdict: string | null }) {
  if (!verdict) return <span className="text-xs text-stone-400">—</span>;
  return (
    <span className={`inline-block rounded px-1.5 py-0.5 font-mono text-xs font-semibold ${VERDICT_STYLE[verdict] ?? ""}`}>
      {verdict}
    </span>
  );
}

export function Pill({ children }: { children: ReactNode }) {
  return (
    <span className="inline-block rounded-full bg-stone-100 px-2 py-0.5 text-xs text-stone-500 dark:bg-stone-800 dark:text-stone-400">
      {children}
    </span>
  );
}
