"use client";

import React from "react";
import { FinderWindow } from "./finder-window";
import { Fingerprint } from "./fingerprint";
import { fingerprint } from "@/lib/corpus";
import { Reveal } from "./playground";
import { Magnet, Type, GraduationCap } from "lucide-react";

/**
 * HOW IT DECIDES — the three kinds of evidence, as three windows.
 * Copy echoes docs/architecture: type → content → taught examples.
 */
export function HowDecides() {
  return (
    <section id="how" className="dotgrid relative scroll-mt-20 overflow-hidden px-5 py-24 md:py-32" aria-labelledby="how-title">
      <div className="mx-auto max-w-6xl">
        <Reveal className="text-center">
          <p className="micro text-tertiary">Three kinds of evidence</p>
          <h2 id="how-title" className="mt-3 text-balance text-4xl font-semibold tracking-[-0.02em] sm:text-5xl md:text-6xl">
            How it decides
          </h2>
          <p className="mx-auto mt-4 max-w-[58ch] text-balance text-[15px] text-secondary md:text-base">
            Every file gets a calibrated probability per rule, built from three
            kinds of evidence. Nothing else touches your disk.
          </p>
        </Reveal>

        <div className="mt-14 grid gap-6 md:grid-cols-3">
          {/* evidence 1 */}
          <Reveal delay={0}>
            <FinderWindow title="what it is · instant" className="h-full">
              <span className="grid size-9 place-items-center rounded-lg bg-hover mb-4">
                <Magnet className="size-4 text-tertiary" aria-hidden />
              </span>
              <WindowList
                rows={[
                  ["IMG_4032.png", "1179×2556 · iPhone screen"],
                  ["Снимок экрана.png", "localized spinner name"],
                  ["footage.mp4", "video is never a document"],
                ]}
              />
            </FinderWindow>
          </Reveal>

          {/* evidence 2 */}
          <Reveal delay={0.12}>
            <FinderWindow title="what it says · embedded" className="h-full">
              <span className="grid size-9 place-items-center rounded-lg bg-hover mb-4">
                <Type className="size-4 text-tertiary" aria-hidden />
              </span>
              <Fingerprint values={fingerprint(71)} height={40} />
              <p className="micro mt-3 text-faint">
                vector 768d, matched against every idea in a rule
              </p>
              <p className="mt-3 text-[13px] text-secondary">
                &ldquo;design files, mockups, screenshots&rdquo; →{" "}
                <span className="text-primary font-medium">92% match</span>
              </p>
            </FinderWindow>
          </Reveal>

          {/* evidence 3 */}
          <Reveal delay={0.24}>
            <FinderWindow title="what you taught it" className="h-full">
              <span className="grid size-9 place-items-center rounded-lg bg-hover mb-4">
                <GraduationCap className="size-4 text-tertiary" aria-hidden />
              </span>
              <WindowList
                rows={[
                  ["you approved", "+1 Examples"],
                  ["you moved to Audio", "re-pulls similar files"],
                  ["one undo = whole sweep", "Journal records everything"],
                ]}
              />
            </FinderWindow>
          </Reveal>
        </div>

        {/* stat strip — small numbers, humans first */}
        <Reveal delay={0.1} className="mt-14">
          <dl className="flex flex-wrap items-baseline justify-center gap-x-10 gap-y-4 text-center">
            <Stat value="2" label="modes · Review or Auto" />
            <Stat value="1" label="sweep = one undo" />
            <Stat value="5 ms" label="per file, on the Neural Engine" />
            <Stat value="0" label="bytes leaving your Mac" />
          </dl>
        </Reveal>
      </div>
    </section>
  );
}

function Stat({ value, label }: { value: string; label: string }) {
  return (
    <div className="flex flex-col items-center">
      <dt className="order-2 text-[13px] text-tertiary">{label}</dt>
      <dd className="order-1 text-4xl font-semibold tracking-tight text-primary">{value}</dd>
    </div>
  );
}

function WindowList({ rows }: { rows: string[][] }) {
  return (
    <div className="space-y-2.5">
      {rows.map(([a, b]) => (
        <div key={a + b} className="flex items-baseline justify-between gap-3 border-b border-line pb-2.5 last:border-0 last:pb-0">
          <span className="truncate text-[13px] text-secondary">{a}</span>
          <span className="micro shrink-0 text-faint">{b}</span>
        </div>
      ))}
    </div>
  );
}
