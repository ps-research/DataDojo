// Ensō — the zen brush circle, drawn as a single tapering stroke with a small
// opening. The brand mark and the loading indicator.
export function Enso({ className = "h-8 w-8", spin = false }: { className?: string; spin?: boolean }) {
  return (
    <svg viewBox="0 0 100 100" className={`${className} ${spin ? "animate-spin" : ""}`} aria-hidden>
      <defs>
        <linearGradient id="ensoStroke" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="currentColor" stopOpacity="0.35" />
          <stop offset="55%" stopColor="currentColor" stopOpacity="1" />
          <stop offset="100%" stopColor="currentColor" stopOpacity="0.55" />
        </linearGradient>
      </defs>
      {/* nearly-closed circle with an intentional gap at the top-right */}
      <path
        d="M62 12 A42 42 0 1 0 82 44"
        fill="none"
        stroke="url(#ensoStroke)"
        strokeWidth="7"
        strokeLinecap="round"
      />
    </svg>
  );
}
