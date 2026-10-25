"use client";

import { motion } from "motion/react";
import type { ReactNode } from "react";

/**
 * macOS window chrome in monochrome: hairline frame, three calm circles,
 * a micro-caps title. Children get a padded body.
 */
export function FinderWindow({
  title,
  children,
  className = "",
  bodyClassName = "",
}: {
  title: string;
  children: ReactNode;
  className?: string;
  bodyClassName?: string;
}) {
  return (
    <motion.div
      className={`rounded-xl border border-line bg-surface-raised overflow-hidden shadow-2xl shadow-black/40 ${className}`}
      style={{ boxShadow: "0 18px 50px -22px rgba(0,0,0,0.35)" }}
    >
      <div className="flex items-center gap-1.5 border-b border-line px-3.5 py-2.5">
        <span className="flex shrink-0 gap-1.5" aria-hidden>
          <span className="size-2 rounded-full bg-tertiary" />
          <span className="size-2 rounded-full bg-faint" />
          <span className="size-2 rounded-full border border-faint opacity-40" />
        </span>
        <span className="micro flex-1 truncate text-center whitespace-nowrap text-faint">
          {title}
        </span>
        <span className="shrink-0 px-[27px]" aria-hidden />
      </div>
      <div className={`p-4 ${bodyClassName}`}>{children}</div>
    </motion.div>
  );
}
