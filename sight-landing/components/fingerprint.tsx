"use client";

import { motion, useReducedMotion } from "motion/react";

/** VectorFingerprint, ported from the app's DesignSystem component. */
export function Fingerprint({
  values,
  bars = 32,
  height = 34,
  stagger = 0.016,
  className = "",
}: {
  values: number[];
  bars?: number;
  height?: number;
  stagger?: number;
  className?: string;
}) {
  const reduce = useReducedMotion();
  return (
    <div className={`flex items-stretch gap-[2px] ${className}`} style={{ height }} aria-label="rule fingerprint">
      {values.slice(0, bars).map((v, i) => (
        <motion.span
          key={i}
          className="h-full w-[3px] flex-1 origin-bottom rounded-full"
          style={{ background: `color-mix(in oklab, var(--primary) ${Math.round(16 + 84 * v)}%, transparent)` }}
          initial={reduce ? false : { scaleY: 0.04 }}
          whileInView={{ scaleY: Math.max(0.08, v) }}
          viewport={{ once: true, margin: "-40px" }}
          transition={{ delay: i * stagger, duration: 0.5, ease: [0.25, 1, 0.3, 1] }}
        />
      ))}
    </div>
  );
}
