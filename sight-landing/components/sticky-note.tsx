"use client";

import React from "react";
import {
  motion,
  useReducedMotion,
  useScroll,
  useSpring,
  useTransform,
  useVelocity,
} from "motion/react";

/**
 * THE IDEA — a single paper note, hung from a thread.
 * The note is a real object now, not a captioned prop. It swings with the
 * page's scroll velocity like a pendulum, floats at rest, and lifts when
 * you reach for it. The manifesto lives in the type beside it — one line,
 * no eyebrows, no captions.
 */
export function StickyNote() {
  const reduce = useReducedMotion();

  // pendulum physics: the note swings with scroll velocity, then settles
  const { scrollY } = useScroll();
  const vel = useVelocity(scrollY);
  const smoothVel = useSpring(vel, { stiffness: 100, damping: 22, mass: 0.6 });
  const swing = useTransform(smoothVel, [-1400, 0, 1400], [-8, 0, 8], { clamp: true });

  return (
    <section
      className="relative overflow-hidden px-5 py-28 md:py-40"
      aria-labelledby="idea-title"
    >
      {/* the thread drops from the top of the page, into the note */}
      <div className="hairline pointer-events-none absolute left-1/2 top-0 hidden h-24 w-px -translate-x-1/2 md:block" aria-hidden />

      <div className="mx-auto grid max-w-6xl items-center gap-14 md:grid-cols-[1.2fr_0.8fr]">
        {/* manifesto */}
        <motion.div
          initial={reduce ? false : { opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.6, ease: [0.25, 1, 0.3, 1] }}
        >
          <h2
            id="idea-title"
            className="text-balance text-[clamp(2.6rem,5.6vw,4.6rem)] font-semibold leading-[1.02] tracking-[-0.03em]"
          >
            Your Mac is already
            <br />
            <span className="text-tertiary">smart enough.</span>
          </h2>
          <p className="mt-6 max-w-[40ch] text-lg leading-relaxed text-secondary md:text-xl">
            The model lives in your home folder. It reads the files — and sorts
            by meaning.
          </p>
        </motion.div>

        {/* the hung note */}
        <div className="relative mx-auto w-full max-w-[380px] pt-8">
          <span
            className="absolute left-1/2 top-0 z-10 size-2.5 -translate-x-1/2 rounded-full bg-primary"
            aria-hidden
          />
          <motion.div
            style={reduce ? undefined : { rotate: swing, transformOrigin: "50% 0px" }}
            initial={reduce ? false : { opacity: 0, y: -50, rotate: -6 }}
            whileInView={{ opacity: 1, y: 0, rotate: 0 }}
            viewport={{ once: true, margin: "-80px" }}
            transition={{ duration: 0.8, ease: [0.25, 1, 0.3, 1] }}
          >
            <div className="mx-auto h-24 w-px bg-line" aria-hidden />
            <motion.div
              whileHover={reduce ? undefined : { rotate: -3, y: -10, scale: 1.04 }}
              transition={{ type: "spring", stiffness: 180, damping: 14 }}
              className="relative mx-auto w-full max-w-[340px] cursor-pointer"
            >
              <div className="animate-floaty" style={{ ["--tilt" as string]: "-1deg" }}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src="/icons/sticky.png" alt="A blank sticky note" draggable={false} className="icon-dark w-full select-none drop-shadow-[0_28px_44px_rgba(0,0,0,0.35)]" />
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src="/icons/sticky-inv.png" alt="A blank sticky note" draggable={false} className="icon-light w-full select-none drop-shadow-[0_28px_44px_rgba(0,0,0,0.35)]" />
              </div>
            </motion.div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
