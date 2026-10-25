"use client";

import React from "react";
import { AnimatePresence, motion, useInView, useReducedMotion } from "motion/react";
import {
  Archive,
  AudioLines,
  FileText,
  Image as ImageIcon,
} from "lucide-react";
import {
  CORPUS,
  FOLDERS,
  categoryLabel,
  fingerprint,
  type PlayFile,
} from "@/lib/corpus";
import { IconImg } from "./icon-img";

type Stage = "mess" | "absorb" | "sorted";

/** hand-tuned scatter — dense at the edges, calm in the middle (the folder lives there) */
const POS: { x: number; y: number; r: number }[] = [
  { x: 10, y: 24, r: -7 }, { x: 22, y: 18, r: 4 }, { x: 35, y: 23, r: -3 },
  { x: 50, y: 18, r: 6 }, { x: 65, y: 23, r: -5 }, { x: 79, y: 18, r: 8 },
  { x: 91, y: 26, r: -9 }, { x: 90, y: 46, r: 5 }, { x: 93, y: 70, r: -4 },
  { x: 78, y: 85, r: 7 }, { x: 57, y: 81, r: -6 }, { x: 34, y: 88, r: 3 },
  { x: 15, y: 79, r: -8 }, { x: 8, y: 52, r: 6 },
];
const UNKNOWN = { x: 24, y: 47, r: -3 };

const EASE: [number, number, number, number] = [0.32, 0.86, 0.4, 1];

/**
 * THE PLAYGROUND — one gesture, zero manuals.
 * 14 real files hang like debris; a tap (or one button) collapses them
 * into the folder; the folder then unfolds counts — one honest file
 * refuses and stays. Less text, more gravity.
 */
export function Playground() {
  const reduce = useReducedMotion();
  const stageRef = React.useRef<HTMLDivElement>(null);
  const inView = useInView(stageRef, { once: true, margin: "-15% 0px" });

  const [state, setState] = React.useState<Stage>("mess");
  const [gone, setGone] = React.useState<number[]>([]);
  const [refused, setRefused] = React.useState<number | null>(null);

  const chipEls = React.useRef(new Map<number, HTMLElement>()).current;
  const folderRef = React.useRef<HTMLDivElement>(null);
  const [flight, setFlight] = React.useState(() => new Map<number, { dx: number; dy: number }>());
  const finish = React.useRef<ReturnType<typeof setTimeout> | null>(null);

  const sortables = CORPUS.filter((f) => f.category);
  const unknownFiles = CORPUS.filter((f) => !f.category);
  const dest = (f: PlayFile) =>
    f.category ? `${categoryLabel(f.category)} · ${Math.round(f.confidence * 100)}%` : "no category close enough";

  const clearFinish = () => {
    if (finish.current) clearTimeout(finish.current);
    finish.current = null;
  };

  const measure = (file: PlayFile) => {
    const stageRect = stageRef.current?.getBoundingClientRect();
    const folderRect = folderRef.current?.getBoundingClientRect();
    const chip = chipEls.get(file.id)?.getBoundingClientRect();
    if (!stageRect || !folderRect || !chip) return null;
    return {
      dx: folderRect.left + folderRect.width / 2 - (chip.left + chip.width / 2),
      dy: folderRect.top + folderRect.height / 2 - (chip.top + chip.height / 2),
    };
  };

  /* one tap on the button: everything collapses at once */
  const startSort = () => {
    if (state !== "mess") return;
    clearFinish();
    const order = [...sortables, ...unknownFiles];
    order.forEach((file) => {
      const m = measure(file);
      if (m) setFlight((prev) => new Map(prev).set(file.id, m));
    });
    setState("absorb");
    finish.current = setTimeout(
      () => setState("sorted"),
      reduce ? 400 : order.length * 90 + 950,
    );
  };

  /* tap a file yourself: only that one collapses. the unknown one refuses. */
  const sendOne = (file: PlayFile) => {
    if (state !== "mess") return;
    if (!file.category) {
      setRefused(file.id);
      setTimeout(() => setRefused(null), 500);
      return;
    }
    const m = measure(file);
    if (m) {
      setFlight((prev) => new Map(prev).set(file.id, m));
      setGone((g) => [...g, file.id]);
    }
  };

  const scatterAgain = () => {
    clearFinish();
    setFlight(new Map());
    setGone([]);
    setState("mess");
  };

  React.useEffect(() => {
    if (state === "mess" && gone.length === sortables.length) {
      finish.current = setTimeout(() => setState("sorted"), 750);
      return () => {
        if (finish.current) clearTimeout(finish.current);
      };
    }
  }, [state, gone, sortables.length]);

  React.useEffect(() => {
    const onSweep = () => startSort();
    const onScatter = () => scatterAgain();
    window.addEventListener("sight:sweep", onSweep);
    window.addEventListener("sight:scatter", onScatter);
    return () => {
      window.removeEventListener("sight:sweep", onSweep);
      window.removeEventListener("sight:scatter", onScatter);
      clearFinish();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const surfaces = FOLDERS.map((fld, i) => ({
    ...fld,
    n: CORPUS.filter((f) => f.category === fld.id).length,
    bars: fingerprint(i * 17 + 3),
  }));

  const headline =
    state === "mess"
      ? `~/Downloads — ${CORPUS.length} files, no structure`
      : state === "absorb"
        ? "reading · deciding · filing"
        : "sorted — nothing left behind";

  return (
    <section id="playground" className="relative scroll-mt-20 px-5 py-24 md:py-32">
      <div className="mx-auto max-w-6xl">
        <Reveal className="text-center">
          <p className="micro text-tertiary">The Playground</p>
          <h2 className="mx-auto mt-3 max-w-[18ch] text-balance text-4xl font-semibold tracking-[-0.02em] sm:text-5xl md:text-6xl">
            Watch the mess collapse.
          </h2>
          <p className="mx-auto mt-4 max-w-[44ch] text-[15px] text-secondary md:text-base">
            {CORPUS.length} files from the real eval corpus. Tap one — or let
            Sight take everything.
          </p>
        </Reveal>

        {/* stage */}
        <Reveal delay={0.06}>
          <div
            ref={stageRef}
            className={`dotgrid relative mt-10 overflow-hidden rounded-xl border border-line bg-surface ${
              state === "sorted" ? "min-h-[540px] px-5 py-14" : "h-[540px] sm:h-[600px]"
            }`}
            aria-label="live sorting stage"
          >
            <p
              aria-live="polite"
              className={`micro absolute left-1/2 top-4 -translate-x-1/2 whitespace-nowrap text-faint transition-opacity ${
                state === "sorted" ? "opacity-0" : "opacity-100"
              }`}
            >
              {headline}
            </p>

            {(state === "mess" || state === "absorb") && inView && (
              <>
                {/* debris */}
                <AnimatePresence>
                  {CORPUS.map((file, idx) => {
                    const isUnknown = !file.category;
                    const p = isUnknown ? UNKNOWN : POS[idx % POS.length];
                    const fl = flight.get(file.id);
                    const participated =
                      state === "absorb" || (isUnknown === false && gone.includes(file.id));
                    return (
                      <div
                        key={file.id}
                        className="absolute z-20"
                        style={{
                          left: `${p.x}%`,
                          top: `${p.y}%`,
                          transform: "translate(-50%, -50%)",
                        }}
                      >
                        <div
                          className="animate-floaty"
                          style={{
                            ["--tilt" as string]: `${p.r}deg`,
                            animationDelay: `${(idx % 5) * 0.7}s`,
                            animationDuration: `${4.5 + (idx % 3) * 0.8}s`,
                          }}
                        >
                          <motion.div
                            ref={(el: HTMLDivElement | null) => {
                              if (el) chipEls.set(file.id, el);
                              else chipEls.delete(file.id);
                            }}
                            onClick={() => sendOne(file)}
                            whileHover={
                              state === "mess" && !participated
                                ? { scale: 1.08 }
                                : undefined
                            }
                            whileTap={state === "mess" ? { scale: 0.94 } : undefined}
                            initial={reduce ? false : { opacity: 0, y: -10, scale: 0.7 }}
                            animate={
                              refused === file.id
                                ? { opacity: 1, scale: 1, x: [0, -8, 8, -5, 0] }
                                : fl && participated
                                  ? { x: fl.dx, y: fl.dy, scale: 0.1, opacity: 0, rotate: 0 }
                                  : { opacity: 1, scale: 1 }
                            }
                            exit={{ opacity: 0, scale: 0.8 }}
                            transition={
                              refused === file.id
                                ? { duration: 0.4 }
                                : fl && participated
                                  ? { delay: reduce ? 0 : idx * 0.09, duration: 0.55, ease: EASE }
                                  : { duration: 0.45, ease: EASE }
                            }
                            className={`flex w-[5.5rem] cursor-pointer flex-col items-center gap-1.5 rounded-lg border bg-surface-raised/95 p-2 backdrop-blur-sm sm:w-28 sm:gap-2 sm:p-2.5 ${
                              isUnknown
                                ? "border-dashed border-faint"
                                : "border-line hover:border-line-strong"
                            }`}
                            title={`${file.name} — ${dest(file)}`}
                          >
                            <span className="grid size-7 shrink-0 place-items-center rounded-md border border-line bg-paper sm:size-9">
                              <ChipIcon kind={file.kind} />
                            </span>
                            <span className="hidden w-full truncate text-center text-[10px] leading-tight text-secondary sm:block">
                              {file.name}
                            </span>
                            <span
                              className={`w-full truncate text-center text-[8px] tracking-[0.06em] sm:text-[9px] ${
                                isUnknown ? "text-tertiary" : "text-faint uppercase"
                              }`}
                            >
                              {isUnknown ? "? · needs you" : dest(file)}
                            </span>
                          </motion.div>
                        </div>
                      </div>
                    );
                  })}
                </AnimatePresence>

                {/* the folder — the point of gravity */}
                <div
                  ref={folderRef}
                  className="pointer-events-none absolute left-1/2 top-1/2 z-10 -translate-x-1/2 -translate-y-1/2"
                >
                  <motion.div
                    animate={
                      state === "absorb"
                        ? { scale: [1, 1.16, 1] }
                        : { scale: [1, 1.045, 1] }
                    }
                    transition={
                      state === "absorb"
                        ? { duration: 0.5, repeat: sortables.length - 1, repeatDelay: 0.09, ease: "easeInOut" }
                        : { duration: 2.6, repeat: Infinity, ease: "easeInOut" }
                    }
                    className="flex flex-col items-center"
                  >
                    <IconImg
                      name="folder"
                      alt=""
                      className="w-24 drop-shadow-xl sm:w-32"
                    />
                    <span className="micro mt-3 text-tertiary">~/Downloads</span>
                  </motion.div>
                </div>
              </>
            )}

            {/* unfolded, accounted for */}
            {state === "sorted" && (
              <div className="flex h-full flex-col items-center justify-center">
                <p className="micro mb-8 text-tertiary">{headline}</p>
                <div className="flex flex-wrap items-stretch justify-center gap-3">
                  {/* the folder, now accounted */}
                  <motion.div
                    initial={reduce ? false : { opacity: 0, scale: 0.7 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{ duration: 0.45, ease: EASE }}
                    className="flex w-36 flex-col items-center justify-center gap-3 rounded-xl border border-line bg-surface-raised p-4"
                  >
                    <IconImg name="folder" alt="" className="w-12" />
                    <span className="text-3xl font-semibold tracking-tight text-primary">
                      {sortables.length}
                    </span>
                    <span className="micro text-faint">filed, in order</span>
                  </motion.div>

                  {surfaces.map((f, i) => (
                    <motion.div
                      key={f.id}
                      initial={reduce ? false : { opacity: 0, y: 18, scale: 0.92 }}
                      animate={{ opacity: 1, y: 0, scale: 1 }}
                      transition={{ delay: 0.08 + i * 0.07, duration: 0.45, ease: EASE }}
                      className="flex w-36 flex-col gap-2.5 rounded-xl border border-line bg-surface-raised p-4"
                    >
                      <span className="grid h-10 w-10 shrink-0 place-items-center rounded-md border border-line bg-paper">
                        <ChipIcon
                          kind={f.id === "screenshots" ? "photo" : f.id === "audio" ? "audio" : f.id === "archives" ? "archive" : "doc"}
                        />
                      </span>
                      <span>
                        <span className="block truncate text-[13px] text-primary">{f.name}</span>
                        <span className="micro text-faint">{f.n} filed</span>
                      </span>
                      <FingerprintMini values={f.bars} />
                    </motion.div>
                  ))}

                  {/* the honest leftover */}
                  {unknownFiles.map((f) => (
                    <motion.div
                      key={f.id}
                      initial={reduce ? false : { opacity: 0, y: 12, scale: 0.9, rotate: 3 }}
                      animate={{ opacity: 1, y: 0, scale: 1, rotate: 2 }}
                      transition={{ delay: 0.2 + surfaces.length * 0.07, duration: 0.4, ease: EASE }}
                      className="flex w-36 flex-col gap-2 rounded-xl border border-dashed border-faint p-4"
                    >
                      <span className="micro text-tertiary">left alone</span>
                      <span className="block truncate text-[13px] text-secondary">{f.name}</span>
                      <span className="text-[11px] leading-snug text-faint">
                        {categoryLabel(null)} — fix the rule or file it yourself
                      </span>
                      <span className="micro mt-auto text-faint">{f.tag}</span>
                    </motion.div>
                  ))}
                </div>

                <motion.button
                  onClick={scatterAgain}
                  initial={reduce ? false : { opacity: 0 }}
                  animate={{ opacity: 1 }}
                  transition={{ delay: 0.7 }}
                  className="micro mt-10 flex items-center gap-2 rounded-full border border-line-strong px-5 py-2.5 text-tertiary transition-colors hover:border-primary hover:text-primary"
                >
                  <RotateIcon /> scatter it again
                </motion.button>
              </div>
            )}
          </div>
        </Reveal>

        {/* one gesture */}
        <Reveal delay={0.1}>
          <div className="mt-8 flex flex-col items-center gap-3">
            {state === "mess" && (
              <>
                <motion.button
                  onClick={startSort}
                  whileHover={{ scale: 1.03 }}
                  whileTap={{ scale: 0.97 }}
                  className="flex h-13 items-center gap-2.5 rounded-full bg-primary px-8 py-3.5 text-[15px] font-medium text-paper transition-all"
                >
                  <FolderGlyph /> Let Sight do it
                </motion.button>
              </>
            )}
            {state === "absorb" && (
              <p className="micro animate-breathe text-tertiary">collapsing…</p>
            )}
          </div>
        </Reveal>
      </div>
    </section>
  );
}

function ChipIcon({ kind }: { kind: PlayFile["kind"] }) {
  const Cmp =
    kind === "audio"
      ? AudioLines
      : kind === "archive"
        ? Archive
        : kind === "photo"
          ? ImageIcon
          : FileText;
  return <Cmp className="size-3.5 sm:size-4 text-primary" aria-hidden strokeWidth={1.5} />;
}

function FolderGlyph() {
  return (
    <svg width="15" height="15" viewBox="0 0 15 15" fill="none" aria-hidden>
      <path
        d="M1.5 4.2c0-1 .8-1.7 1.7-1.7h3l1.6 1.7h4c1 0 1.7.8 1.7 1.7v5c0 1-.8 1.7-1.7 1.7h-8.6c-1 0-1.7-.8-1.7-1.7v-6.7Z"
        fill="currentColor"
      />
    </svg>
  );
}

function RotateIcon() {
  return (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden>
      <path
        d="M2 6a4 4 0 1 1 1.2 2.9M2 9.5V6h3.5"
        stroke="currentColor"
        strokeWidth="1.3"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

/** tiny fingerprint strip for the result cards */
function FingerprintMini({ values }: { values: number[] }) {
  return (
    <div className="mt-auto flex items-end gap-[2px]" style={{ height: 18 }} aria-hidden>
      {values.slice(0, 22).map((v, i) => (
        <span
          key={i}
          className="h-full w-[3px] flex-1 origin-bottom rounded-full"
          style={{
            background: `color-mix(in oklab, var(--primary) ${Math.round(14 + 74 * v)}%, transparent)`,
            transform: `scaleY(${Math.max(0.1, v)})`,
          }}
        />
      ))}
    </div>
  );
}

/** shared scroll reveal */
export function Reveal({
  children,
  delay = 0,
  className = "",
}: {
  children: React.ReactNode;
  delay?: number;
  className?: string;
}) {
  const reduce = useReducedMotion();
  return (
    <motion.div
      initial={reduce ? false : { opacity: 0, y: 28 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-60px" }}
      transition={{ delay, duration: 0.55, ease: [0.25, 1, 0.3, 1] }}
      className={className}
    >
      {children}
    </motion.div>
  );
}
