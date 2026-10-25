"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { AnimatePresence, motion } from "motion/react";
import { Sparkles, Moon, Sun, FolderOpen, Crosshair, CornerDownLeft } from "lucide-react";

type Item = {
  id: string;
  label: string;
  hint?: string;
  icon: React.ComponentType<{ className?: string }>;
  run: () => void;
};

const scrollTo = (id: string) =>
  document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "start" });

const ITEMS: Item[] = [
  { id: "try", label: "Try it — live sorting playground", hint: "⌘1", icon: Sparkles, run: () => scrollTo("playground") },
  { id: "how", label: "How it decides", hint: "⌘2", icon: Crosshair, run: () => scrollTo("how") },
  { id: "privacy", label: "Why local — no cloud, no telemetry", hint: "⌘3", icon: FolderOpen, run: () => scrollTo("privacy") },
  { id: "download", label: "Download for macOS", hint: "⌘4", icon: CornerDownLeft, run: () => scrollTo("download") },
  { id: "dark", label: "Theme: Dark", icon: Moon, run: () => (document.documentElement.dataset.theme = "dark") },
  { id: "light", label: "Theme: Light", icon: Sun, run: () => (document.documentElement.dataset.theme = "light") },
  { id: "scatter", label: "Collapse the playground files into the folder", hint: "⌘R", icon: FolderOpen, run: () => window.dispatchEvent(new Event("sight:sweep")) },
  { id: "top", label: "Back to the desktop", icon: CornerDownLeft, run: () => scrollTo("top") },
];

/** the panel itself; unmounting resets query + selection (no setState effects) */
function Panel({ onClose }: { onClose: () => void }) {
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState(0);

  const filtered = useMemo(
    () => ITEMS.filter((i) => i.label.toLowerCase().includes(query.toLowerCase())),
    [query]
  );
  const pick = Math.min(selected, Math.max(0, filtered.length - 1));

  const run = (item?: Item) => {
    if (!item) return;
    item.run();
    onClose();
  };

  return (
    <motion.div
      className="fixed inset-0 z-50 flex items-start justify-center pt-[16vh]"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.12 }}
      onClick={onClose}
      role="dialog"
      aria-modal="true"
      aria-label="Command palette"
    >
      <div className="absolute inset-0 bg-paper/70 backdrop-blur-[2px]" />
      <motion.div
        initial={{ opacity: 0, scale: 0.97, y: 8 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.98, y: 4 }}
        transition={{ duration: 0.16, ease: [0.25, 1, 0.3, 1] }}
        onClick={(e) => e.stopPropagation()}
        className="relative w-[min(92vw,560px)] overflow-hidden rounded-xl border border-line bg-surface-raised"
      >
        <input
          autoFocus
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setSelected(0);
          }}
          onKeyDown={(e) => {
            if (e.key === "ArrowDown") {
              e.preventDefault();
              setSelected((s) => Math.min(s + 1, filtered.length - 1));
            } else if (e.key === "ArrowUp") {
              e.preventDefault();
              setSelected((s) => Math.max(s - 1, 0));
            } else if (e.key === "Enter") {
              run(filtered[pick]);
            } else if (e.key === "Escape") {
              onClose();
            }
          }}
          placeholder="Type a command…"
          className="w-full border-b border-line bg-transparent px-5 py-4 text-[15px] outline-none placeholder:text-faint"
        />
        <ul className="max-h-72 overflow-y-auto p-1.5">
          {filtered.map((item, i) => (
            <li key={item.id}>
              <button
                onClick={() => run(item)}
                onMouseEnter={() => setSelected(i)}
                className={`flex w-full items-center gap-3 rounded-lg px-3.5 py-2.5 text-left text-[14px] transition-colors ${
                  i === pick ? "bg-active text-primary" : "text-secondary"
                }`}
              >
                <item.icon className="size-4 text-tertiary" aria-hidden />
                {item.label}
                {item.hint && <span className="micro ml-auto text-faint">{item.hint}</span>}
              </button>
            </li>
          ))}
        </ul>
      </motion.div>
    </motion.div>
  );
}

export function Palette({ open, setOpen }: { open: boolean; setOpen: (v: boolean) => void }) {
  // global ⌘K, exactly like the app shell
  const openRef = useRef(open);
  useEffect(() => {
    openRef.current = open;
  }, [open]);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen(!openRef.current);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [setOpen]);

  return <AnimatePresence>{open && <Panel onClose={() => setOpen(false)} />}</AnimatePresence>;
}
