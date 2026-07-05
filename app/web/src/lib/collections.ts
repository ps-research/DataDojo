// Display metadata for the "collection" a problem belongs to: a themed universe,
// or the Tutorial / Python / R tracks. Full class strings so Tailwind keeps them.
export const COLLECTIONS: Record<string, { label: string; cls: string }> = {
  pulsestream: { label: "PulseStream", cls: "bg-sky-50 text-sky-700 dark:bg-sky-500/10 dark:text-sky-400" },
  carthive: { label: "CartHive", cls: "bg-amber-50 text-amber-700 dark:bg-amber-500/10 dark:text-amber-400" },
  rideloop: { label: "RideLoop", cls: "bg-emerald-50 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400" },
  medicore: { label: "MediCore", cls: "bg-rose-50 text-rose-700 dark:bg-rose-500/10 dark:text-rose-400" },
  metricforge: { label: "MetricForge", cls: "bg-violet-50 text-violet-700 dark:bg-violet-500/10 dark:text-violet-400" },
  tickforge: { label: "TickForge", cls: "bg-indigo-50 text-indigo-700 dark:bg-indigo-500/10 dark:text-indigo-400" },
  __tutorial: { label: "Tutorial", cls: "bg-zinc-100 text-zinc-600 dark:bg-zinc-800 dark:text-zinc-400" },
  __python: { label: "Python", cls: "bg-blue-50 text-blue-700 dark:bg-blue-500/10 dark:text-blue-400" },
  __r: { label: "R", cls: "bg-teal-50 text-teal-700 dark:bg-teal-500/10 dark:text-teal-400" },
};

export interface Collectable {
  universe: string;
  category: string;
}

export function collectionKey(p: Collectable): string {
  if (p.universe) return p.universe;
  if (p.category === "python") return "__python";
  if (p.category === "r") return "__r";
  return "__tutorial";
}

export function collectionLabel(key: string): string {
  return COLLECTIONS[key]?.label ?? key;
}
