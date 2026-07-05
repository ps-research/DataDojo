// A quiet dot marker per collection. Colors are chosen OUTSIDE the belt families
// (belts own blue/purple/red/gray) so the two systems never compete: belts
// carry difficulty, collections are just a subtle identity cue.
export const COLLECTIONS: Record<string, { label: string; dot: string }> = {
  pulsestream: { label: "PulseStream", dot: "bg-cyan-500" },
  carthive: { label: "CartHive", dot: "bg-amber-500" },
  rideloop: { label: "RideLoop", dot: "bg-emerald-500" },
  medicore: { label: "MediCore", dot: "bg-teal-500" },
  metricforge: { label: "MetricForge", dot: "bg-orange-500" },
  tickforge: { label: "TickForge", dot: "bg-lime-500" },
  __tutorial: { label: "Tutorial", dot: "bg-zinc-300 dark:bg-zinc-600" },
  __python: { label: "Python", dot: "bg-zinc-400 dark:bg-zinc-500" },
  __r: { label: "R", dot: "bg-zinc-400 dark:bg-zinc-500" },
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
