// A flat, geometric mark — a rounded tile with three data rows. No brushwork,
// no theming. Reads as "data" and stays out of the way.
export function Logo({ className = "h-7 w-7" }: { className?: string }) {
  return (
    <svg viewBox="0 0 32 32" className={className} aria-hidden>
      <rect x="1" y="1" width="30" height="30" rx="8" className="fill-brand" />
      <rect x="8" y="10" width="16" height="2.6" rx="1.3" fill="white" opacity="0.95" />
      <rect x="8" y="14.7" width="16" height="2.6" rx="1.3" fill="white" opacity="0.7" />
      <rect x="8" y="19.4" width="10" height="2.6" rx="1.3" fill="white" opacity="0.5" />
    </svg>
  );
}

// Small spinner for loading states.
export function Spinner({ className = "h-5 w-5" }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={`${className} animate-spin`} fill="none" aria-hidden>
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2.5" opacity="0.2" />
      <path d="M21 12a9 9 0 0 0-9-9" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" />
    </svg>
  );
}
