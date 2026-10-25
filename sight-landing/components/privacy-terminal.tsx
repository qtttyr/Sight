"use client";

import React from "react";
import { useInView, useReducedMotion, motion } from "motion/react";
import { FinderWindow } from "./finder-window";

type Line = { who: string; text: string };

const SCRIPT: Line[] = [
  { who: "$", text: "sight --check" },
  { who: "network", text: "no sockets · no accounts · no cloud" },
  { who: "engine", text: "632 MB · resident in your home folder" },
  { who: "$", text: "sight --sort ~/Downloads --report" },
  { who: "→", text: "invoice_2026_0032.xlsx → Invoices · 90% · 4 ms" },
  { who: "→", text: "IMG_4032.HEIC → Screenshots · 98% · 3 ms" },
  { who: "→", text: "backup_2026.zip → Archives · 96% · 4 ms" },
  { who: "✓", text: "13 filed · 1 needs you · 0 bytes left the Mac" },
];

const TOTAL = SCRIPT.reduce((a, l) => a + l.who.length + 1 + l.text.length + 1, 0);

const WHO_COLOR: Record<string, string> = {
  $: "text-primary",
  network: "text-tertiary",
  engine: "text-tertiary",
  "→": "text-faint",
  "✓": "text-primary",
};

function visibleChars(n: number) {
  const out = SCRIPT.map(() => ({ who: "", text: "" }));
  let left = n;
  for (let i = 0; i < SCRIPT.length; i++) {
    const l = SCRIPT[i];
    if (left <= 0) break;
    const whoShown = Math.min(l.who.length, left);
    out[i].who = l.who.slice(0, whoShown);
    left -= whoShown;
    if (left <= 0) break;
    left -= 1; // space
    if (left <= 0) break;
    const textShown = Math.min(l.text.length, left);
    out[i].text = l.text.slice(0, textShown);
    left -= textShown;
    if (left <= 0) break;
    left -= 1; // newline
  }
  return out;
}

/**
 * WHY LOCAL — the terminal types itself.
 * No eyebrows, no captions: the log proves the claim. Click the window to
 * replay. Every line is typed in (no whole-line pops), so the reveal reads
 * as a live shell, not a slide.
 */
export function PrivacyTerminal() {
  const reduce = useReducedMotion();
  const ref = React.useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { once: true, margin: "-30% 0px" });
  const [n, setN] = React.useState(0);
  const [replay, setReplay] = React.useState(0);

  React.useEffect(() => {
    if (!inView) return;
    let cancelled = false;
    let i = 0;
    const tick = () => {
      if (cancelled) return;
      i += 1;
      setN(i);
      if (i < TOTAL) {
        window.setTimeout(tick, 12 + (Math.random() > 0.92 ? 110 : 0));
      }
    };
    const id = window.setTimeout(() => {
      setN(0);
      tick();
    }, 320);
    return () => {
      cancelled = true;
      window.clearTimeout(id);
    };
  }, [inView, replay]);

  const lines = visibleChars(n);
  const done = n >= TOTAL;
  const lastActive = lines.reduce(
    (acc, l, i) => (l.who || l.text ? i : acc),
    -1,
  );

  if (reduce) {
    return (
      <section
        id="privacy"
        className="scroll-mt-20 px-5 py-24 md:py-32"
        aria-labelledby="privacy-title"
      >
        <div className="mx-auto grid max-w-6xl items-center gap-12 md:grid-cols-[1fr_1.15fr]">
          <div>
            <h2
              id="privacy-title"
              className="text-balance text-4xl font-semibold tracking-[-0.02em] sm:text-5xl"
            >
              If it&apos;s not on your Mac, it doesn&apos;t exist.
            </h2>
            <p className="mt-5 max-w-[50ch] leading-relaxed text-secondary md:text-lg">
              A 632-MB engine, resident in your home folder. Zero sockets, zero cloud.
            </p>
          </div>
          <div className="w-full max-w-xl justify-self-end">
            <FinderWindow title="terminal — ssh logged out" bodyClassName="!p-0">
              <div className="min-h-[290px] bg-paper p-5 font-mono text-[13px] leading-[1.9]">
                {SCRIPT.map((l, i) => (
                  <p key={i} className="flex gap-3">
                    <span className="shrink-0 w-14 text-faint">{l.who}</span>
                    <span className={WHO_COLOR[l.who] ?? "text-secondary"}>{l.text}</span>
                  </p>
                ))}
                <p className="flex gap-3">
                  <span className="shrink-0 w-14 text-faint">$</span>
                  <span className="inline-block h-[1.1em] w-[7px] bg-primary animate-blink" aria-hidden />
                </p>
              </div>
            </FinderWindow>
          </div>
        </div>
      </section>
    );
  }

  return (
    <section
      id="privacy"
      className="scroll-mt-20 px-5 py-24 md:py-32"
      aria-labelledby="privacy-title"
    >
      <div className="mx-auto grid max-w-6xl items-center gap-12 md:grid-cols-[1fr_1.15fr]">
        <motion.div
          initial={reduce ? false : { opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.6, ease: [0.25, 1, 0.3, 1] }}
        >
          <h2
            id="privacy-title"
            className="text-balance text-4xl font-semibold tracking-[-0.02em] sm:text-5xl"
          >
            If it&apos;s not on your Mac, it doesn&apos;t exist.
          </h2>
          <p className="mt-5 max-w-[50ch] leading-relaxed text-secondary md:text-lg">
            A 632-MB engine, resident in your home folder. Zero sockets, zero cloud.
          </p>
        </motion.div>

        <motion.div
          initial={reduce ? false : { opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ delay: 0.08, duration: 0.6, ease: [0.25, 1, 0.3, 1] }}
          className="w-full max-w-xl justify-self-end"
        >
          <div
            ref={ref}
            onClick={() => setReplay((r) => r + 1)}
            className="cursor-pointer"
            title="click to replay"
          >
            <FinderWindow title="terminal — ssh logged out" bodyClassName="!p-0">
              <div
                className="min-h-[290px] bg-paper p-5 font-mono text-[13px] leading-[1.9]"
                aria-live="polite"
              >
                {lines.map((l, i) => {
                  const active = i === lastActive && !done;
                  return (
                    <p key={i} className="flex gap-3">
                      <span className="shrink-0 w-14 text-faint">{l.who}</span>
                      <span className={WHO_COLOR[SCRIPT[i].who] ?? "text-secondary"}>
                        {l.text}
                        {active && (
                          <span
                            className="ml-0.5 inline-block h-[1.1em] w-[7px] bg-primary animate-blink"
                            aria-hidden
                          />
                        )}
                      </span>
                    </p>
                  );
                })}
                {done && (
                  <p className="flex gap-3">
                    <span className="shrink-0 w-14 text-faint">$</span>
                    <span className="inline-block h-[1.1em] w-[7px] bg-primary animate-blink" aria-hidden />
                  </p>
                )}
              </div>
            </FinderWindow>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
