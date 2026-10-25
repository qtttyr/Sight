"use client";

import React from "react";
import { motion, useReducedMotion } from "motion/react";
import { HalftoneWordmark } from "./halftone-wordmark";
import { Apple } from "lucide-react";

/**
 * THE HERO — three moves, zero captions.
 * 1. The name, printed in breathing halftone dots along the top edge.
 * 2. One kinetic headline + its single pill, hugging the same left edge.
 * 3. The signature: a giant rule-fingerprint — a field of calm bars
 *    breathing at different depths and phases. This is what "reading a
 *    file" looks like, in motion. No names, no labels, no captions.
 */

/* deterministic bar field — same shape on server and client */
const BAR_COUNT = 140;

const frac = (x: number) => x - Math.floor(x);
const rnd = (i: number, s: number) => frac(Math.sin(i * 12.9898 + s * 78.233) * 43758.5453);

const REACH = ["reach-a", "reach-b", "reach-c", "reach-d", "reach-e"];

const round = (x: number, d = 3) => Number(x.toFixed(d));

const BARS = Array.from({ length: BAR_COUNT }, (_, i) => {
  const middle = Math.exp(-((i - BAR_COUNT / 2) ** 2) / 1200);
  const rhythm = 0.5 + 0.5 * (0.5 + 0.5 * Math.sin(i * 0.24 + 0.9));
  const h = Math.min(1, Math.max(0.1, middle * rhythm + rnd(i, 3) * 0.2));
  return {
    left: round(0.5 + (i / (BAR_COUNT - 1)) * 99),
    height: round(h),
    alpha: round(0.55 + rnd(i, 5) * 0.45),
    animation: `${REACH[i % REACH.length]} ${round(3.2 + rnd(i, 1) * 2.8, 2)}s ease-in-out ${round(rnd(i, 2) * -4, 2)}s infinite`,
  };
});

export function DesktopHero() {
  const reduce = useReducedMotion();

  return (
    <section id="top" className="relative min-h-[100svh] overflow-hidden">
      {/* the print — dots part around the pointer, ring on click, breath always on */}
      <div className="absolute inset-0" aria-hidden>
        <HalftoneWordmark
          wordmark="SIGHT"
          height="100%"
          align="top-crop"
          crop={0.38}
          dissolve="up"
          dotGap={6}
          radius={95}
          grain={0.4}
          wave={0.14}
          fontWeight={800}
          letterSpacing="-0.04em"
        />
        {/* soft paper scrim — menu chrome stays legible over the print */}
        <div
          className="absolute inset-x-0 top-0 h-24"
          style={{
            background:
              "linear-gradient(to bottom, color-mix(in oklab, var(--paper) 92%, transparent), color-mix(in oklab, var(--paper) 0%, transparent))",
          }}
        />
      </div>

      {/* one grid with the menu: headline high, the fingerprint anchored low */}
      <div
        className="relative z-10 mx-auto flex min-h-[100svh] w-full max-w-[1100px] flex-col px-5 pt-[24vh] pb-[21vh] md:pt-[32vh] md:pb-[24vh]"
        style={{ textShadow: "0 1px 22px var(--paper), 0 0 8px var(--paper)" }}
      >
        {/* kinetic headline — line-masked rise */}
        <h1 className="max-w-[14ch] text-[clamp(2.9rem,7.4vw,7rem)] font-semibold leading-[0.98] tracking-[-0.035em]">
          <MaskLine delay={0.12} reduce={!!reduce}>
            Your files,
          </MaskLine>
          <MaskLine delay={0.26} reduce={!!reduce}>
            <span className="text-tertiary">sorted by meaning.</span>
          </MaskLine>
        </h1>

        {/* pills: try it + download */}
        <motion.div
          initial={reduce ? false : { opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.55, duration: 0.5 }}
          className="mt-9 flex flex-col items-start gap-3 sm:flex-row"
        >
          <a
            href="#playground"
            className="group flex h-13 w-fit items-center gap-2.5 rounded-full bg-primary px-7 py-3.5 text-[15px] font-medium text-paper transition-transform duration-150 hover:scale-[1.03] active:scale-[0.97]"
            style={{ textShadow: "none" }}
          >
            <Sparkle />
            Sort it yourself
          </a>
          <button
            type="button"
            onClick={() => window.dispatchEvent(new Event("sight:download"))}
            className="flex h-13 w-fit items-center gap-2.5 rounded-full border border-line-strong px-7 py-3.5 text-[15px] font-medium text-secondary transition-colors hover:border-primary hover:text-primary"
          >
            <Apple className="size-4" aria-hidden />
            Download
          </button>
        </motion.div>
      </div>

      {/* the rule-fingerprint — a giant, calm, breathing bar field */}
      <motion.div
        initial={reduce ? false : { opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.85, duration: 0.9 }}
        className="pointer-events-none absolute inset-x-0 bottom-0 h-[22vh] md:h-[30vh]"
        aria-hidden
        style={{
          maskImage: "linear-gradient(to right, transparent, black 10%, black 90%, transparent)",
          WebkitMaskImage: "linear-gradient(to right, transparent, black 10%, black 90%, transparent)",
        }}
      >
        <div
          className="h-full w-full"
          style={{
            maskImage: "linear-gradient(to top, black 78%, transparent)",
            WebkitMaskImage: "linear-gradient(to top, black 78%, transparent)",
          }}
        >
          {BARS.map((b, i) => (
            <span
              key={i}
              className="wavebar"
              style={{
                left: `${b.left}%`,
                height: `${b.height * 100}%`,
                opacity: b.alpha,
                background: "var(--primary)",
                animation: reduce ? undefined : b.animation,
              }}
            />
          ))}
        </div>
      </motion.div>
    </section>
  );
}

/** one line, revealed from behind its own mask */
function MaskLine({
  delay,
  reduce,
  children,
}: {
  delay: number;
  reduce: boolean;
  children: React.ReactNode;
}) {
  return (
    <span className="block overflow-hidden pb-[0.08em] -mb-[0.08em]">
      <motion.span
        className="block"
        initial={reduce ? false : { y: "112%" }}
        animate={{ y: "0%" }}
        transition={{ delay, duration: 0.9, ease: [0.16, 1, 0.3, 1] }}
      >
        {children}
      </motion.span>
    </span>
  );
}

function Sparkle() {
  return (
    <svg
      width="14"
      height="14"
      viewBox="0 0 14 14"
      aria-hidden
      className="transition-transform duration-200 group-hover:rotate-90"
    >
      <path
        d="M7 0.8 L8.4 5.6 L13.2 7 L8.4 8.4 L7 13.2 L5.6 8.4 L0.8 7 L5.6 5.6 Z"
        fill="currentColor"
      />
    </svg>
  );
}
