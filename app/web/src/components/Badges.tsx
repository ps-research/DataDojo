import type { ReactNode } from "react";

// Belts as clean colored labels — white through red, red the highest.
export const BELT_META: Record<string, { label: string; text: string }> = {
  white: { label: "White", text: "text-zinc-500 dark:text-zinc-400" },
  blue: { label: "Blue", text: "text-sky-600 dark:text-sky-400" },
  purple: { label: "Purple", text: "text-violet-600 dark:text-violet-400" },
  black: { label: "Black", text: "text-zinc-800 dark:text-zinc-200" },
  red: { label: "Red", text: "text-rose-600 dark:text-rose-400" },
};

export function BeltBadge({ belt }: { belt: string }) {
  const m = BELT_META[belt] ?? BELT_META.white;
  return <span className={`text-[13px] font-medium ${m.text}`}>{m.label}</span>;
}

const VERDICT_STYLE: Record<string, string> = {
  AC: "bg-emerald-50 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400",
  WA: "bg-rose-50 text-rose-700 dark:bg-rose-500/10 dark:text-rose-400",
  TLE: "bg-amber-50 text-amber-700 dark:bg-amber-500/10 dark:text-amber-400",
  RE: "bg-orange-50 text-orange-700 dark:bg-orange-500/10 dark:text-orange-400",
  CE: "bg-zinc-100 text-zinc-600 dark:bg-zinc-800 dark:text-zinc-300",
};

export function VerdictBadge({ verdict }: { verdict: string | null }) {
  if (!verdict) return <span className="text-xs text-zinc-400">—</span>;
  return (
    <span className={`inline-block rounded-md px-1.5 py-0.5 font-mono text-xs font-semibold ${VERDICT_STYLE[verdict] ?? ""}`}>
      {verdict}
    </span>
  );
}

export function Pill({ children }: { children: ReactNode }) {
  return (
    <span className="inline-block rounded-md bg-zinc-100 px-2 py-0.5 text-xs text-zinc-500 dark:bg-zinc-800 dark:text-zinc-400">
      {children}
    </span>
  );
}
