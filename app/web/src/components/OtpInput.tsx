import { useEffect, useRef, useState } from "react";

// Six-box code entry: auto-advance, backspace-to-previous, full-code paste.
export function OtpInput({
  value,
  onChange,
  onComplete,
  disabled,
}: {
  value: string;
  onChange: (v: string) => void;
  onComplete?: (v: string) => void;
  disabled?: boolean;
}) {
  const refs = useRef<(HTMLInputElement | null)[]>([]);
  const [focused, setFocused] = useState(-1);

  useEffect(() => {
    refs.current[0]?.focus();
  }, []);

  const setDigit = (i: number, d: string) => {
    const digits = value.split("");
    digits[i] = d;
    const next = digits.join("").slice(0, 6);
    onChange(next);
    if (d && i < 5) refs.current[i + 1]?.focus();
    if (next.length === 6 && !next.includes("") && onComplete) onComplete(next);
  };

  return (
    <div className="flex justify-center gap-2" onPaste={(e) => {
      const txt = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, 6);
      if (txt) {
        e.preventDefault();
        onChange(txt);
        if (txt.length === 6 && onComplete) onComplete(txt);
        refs.current[Math.min(txt.length, 5)]?.focus();
      }
    }}>
      {Array.from({ length: 6 }).map((_, i) => (
        <input
          key={i}
          ref={(el) => (refs.current[i] = el)}
          inputMode="numeric"
          maxLength={1}
          disabled={disabled}
          value={value[i] ?? ""}
          onFocus={() => setFocused(i)}
          onBlur={() => setFocused(-1)}
          onChange={(e) => {
            const d = e.target.value.replace(/\D/g, "").slice(-1);
            setDigit(i, d);
          }}
          onKeyDown={(e) => {
            if (e.key === "Backspace" && !value[i] && i > 0) refs.current[i - 1]?.focus();
          }}
          className={`h-12 w-11 rounded-lg border text-center text-lg font-semibold outline-none transition-colors
            ${focused === i ? "border-brand ring-2 ring-brand/15" : "border-zinc-300 dark:border-zinc-700"}
            bg-white text-zinc-900 dark:bg-zinc-900 dark:text-zinc-100`}
        />
      ))}
    </div>
  );
}
