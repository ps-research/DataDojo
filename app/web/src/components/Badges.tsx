import type { ReactNode } from "react";

// Belts follow the dojo: white through black, then red (which, as in judo,
// outranks black). Each carries its dan-style kanji reading.
export const BELT_META: Record<string, { label: string; dot: string; text: string }> = {
  white: { label: "White", dot: "bg-washi-300 ring-1 ring-sumi/20", text: "text-sumi/60 dark:text-washi-100/60" },
  blue: { label: "Blue", dot: "bg-ai", text: "text-ai dark:text-ai-light" },
  purple: { label: "Purple", dot: "bg-violet-500", text: "text-violet-600 dark:text-violet-400" },
  black: { label: "Black", dot: "bg-sumi dark:bg-washi-100", text: "text-sumi dark:text-washi-100" },
  red: { label: "Red", dot: "bg-shu", text: "text-shu dark:text-shu-light" },
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
  WA: "bg-shu/10 text-shu dark:bg-shu/15 dark:text-shu-light",
  TLE: "bg-amber-50 text-amber-700 dark:bg-amber-950 dark:text-amber-400",
  RE: "bg-orange-50 text-orange-700 dark:bg-orange-950 dark:text-orange-400",
  CE: "bg-washi-200 text-sumi/70 dark:bg-sumi-900 dark:text-washi-100/70",
};

export function VerdictBadge({ verdict }: { verdict: string | null }) {
  if (!verdict) return <span className="text-xs text-sumi/40">—</span>;
  return (
    <span className={`inline-block rounded px-1.5 py-0.5 font-mono text-xs font-semibold ${VERDICT_STYLE[verdict] ?? ""}`}>
      {verdict}
    </span>
  );
}

export function Pill({ children }: { children: ReactNode }) {
  return (
    <span className="inline-block rounded-full bg-washi-200 px-2 py-0.5 text-xs text-sumi/55 dark:bg-sumi-700 dark:text-washi-100/55">
      {children}
    </span>
  );
}
