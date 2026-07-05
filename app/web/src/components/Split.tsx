import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";

// Horizontal resizable split. Drag the divider; double-click to reset.
// The ratio persists per storage key so the workspace feels stable.
export function Split({
  left,
  right,
  storageKey,
  min = 0.22,
  max = 0.75,
  hidden = false,
}: {
  left: ReactNode;
  right: ReactNode;
  storageKey: string;
  min?: number;
  max?: number;
  hidden?: boolean; // focus mode: hide the left panel entirely
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [ratio, setRatio] = useState<number>(() => {
    const saved = parseFloat(localStorage.getItem(storageKey) ?? "");
    return Number.isFinite(saved) ? saved : 0.44;
  });
  const dragging = useRef(false);

  useEffect(() => {
    localStorage.setItem(storageKey, String(ratio));
  }, [ratio, storageKey]);

  const onPointerDown = useCallback((e: React.PointerEvent) => {
    dragging.current = true;
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
  }, []);

  const onPointerMove = useCallback(
    (e: React.PointerEvent) => {
      if (!dragging.current || !ref.current) return;
      const rect = ref.current.getBoundingClientRect();
      const r = (e.clientX - rect.left) / rect.width;
      setRatio(Math.min(max, Math.max(min, r)));
    },
    [min, max]
  );

  const onPointerUp = useCallback(() => {
    dragging.current = false;
    document.body.style.cursor = "";
    document.body.style.userSelect = "";
  }, []);

  return (
    <div ref={ref} className="flex h-full min-h-0 w-full">
      {!hidden && (
        <>
          <div style={{ width: `${ratio * 100}%` }} className="h-full min-h-0 overflow-auto">
            {left}
          </div>
          <div
            role="separator"
            aria-orientation="vertical"
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            onDoubleClick={() => setRatio(0.44)}
            className="group flex w-2 flex-none cursor-col-resize items-stretch justify-center"
            title="Drag to resize · double-click to reset"
          >
            <div className="w-px bg-stone-200 transition-colors group-hover:w-0.5 group-hover:bg-accent dark:bg-stone-800" />
          </div>
        </>
      )}
      <div className="h-full min-h-0 flex-1 overflow-hidden">{right}</div>
    </div>
  );
}
