"use client";

import { useSyncExternalStore } from "react";

export type Theme = "dark" | "light";

/**
 * Theme lives on <html data-theme> so the first paint is already correct
 * (see the init script in layout.tsx). This store mirrors it into React.
 */
const listeners = new Set<() => void>();

function subscribe(listener: () => void) {
  listeners.add(listener);

  const observer = new MutationObserver(() => {
    listeners.forEach((l) => l());
  });
  observer.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ["data-theme"],
  });

  return () => {
    listeners.delete(listener);
    observer.disconnect();
  };
}

function snapshot(): Theme {
  return (document.documentElement.dataset.theme as Theme) ?? "dark";
}

export function useTheme(): [Theme, (t: Theme) => void] {
  const theme = useSyncExternalStore(subscribe, snapshot, () => "dark" as Theme);

  const apply = (t: Theme) => {
    document.documentElement.dataset.theme = t;
    try {
      localStorage.setItem("sight-theme", t);
    } catch {
      /* private mode */
    }
  };

  return [theme, apply];
}

export function ThemeToggle({ compact = false }: { compact?: boolean }) {
  const [theme, apply] = useTheme();
  return (
    <div
      className="flex gap-0.5 rounded-full bg-hover p-0.5"
      style={{ boxShadow: "0 0 0 2.5px var(--paper)" }}
      role="radiogroup"
      aria-label="Theme"
    >
      {(["dark", "light"] as const).map((mode) => (
        <button
          key={mode}
          role="radio"
          aria-checked={theme === mode}
          onClick={() => apply(mode)}
          className={`micro rounded-full px-2.5 py-1 transition-colors duration-150 ${
            theme === mode ? "bg-primary text-paper" : "text-tertiary hover:text-primary"
          }`}
        >
          {compact ? (mode === "dark" ? "D" : "L") : mode}
        </button>
      ))}
    </div>
  );
}
