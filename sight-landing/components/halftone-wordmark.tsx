"use client";

import * as React from "react";

/**
 * Halftone wordmark — a giant word printed as a field of dots on a canvas.
 * Dots part around the pointer on springs, click sends a shock ring through
 * the word, and the print can dissolve as you scroll past it. Monochrome:
 * color comes from the page tokens (--primary), displaced dots just fade.
 *
 * Adapted from example-files/footer.tsx (halftone footer, canvas + springs).
 */

export type HalftoneAlign = "top-crop" | "center" | "bottom-crop";
export type HalftoneDissolve = "none" | "up" | "down";

type RGB = [number, number, number];

function parseColor(css: string): RGB | null {
  const m = /rgba?\(([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)/.exec(css);
  if (!m) return null;
  return [Number(m[1]), Number(m[2]), Number(m[3])];
}

/** Dot radius for cell coverage: area-true, so tone stays even. */
function radiusFor(coverage: number, gap: number) {
  const c = Math.max(0, Math.min(1, coverage));
  return Math.sqrt(c) * gap * 0.56;
}

/** One spring step: push from the pointer, then head home. */
function spring(
  x: number, y: number, vx: number, vy: number,
  hx: number, hy: number, px: number, py: number, r: number,
): [number, number, number, number] {
  const dx = x - px;
  const dy = y - py;
  const d2 = dx * dx + dy * dy;
  if (r > 0 && d2 < r * r) {
    const d = Math.sqrt(d2) + 0.001;
    const f = (1 - d / r) * 2.6;
    vx += (dx / d) * f;
    vy += (dy / d) * f;
  }
  vx = (vx + (hx - x) * 0.05) * 0.84;
  vy = (vy + (hy - y) * 0.05) * 0.84;
  return [x + vx, y + vy, vx, vy];
}

const HTW_CSS = `
.htw-root { position: relative; overflow: hidden; isolation: isolate; -webkit-font-smoothing: antialiased; }
.htw-root canvas { position: absolute; inset: 0; width: 100%; height: 100%; display: block; max-width: none; }
.htw-grain {
  position: absolute; inset: 0; pointer-events: none; mix-blend-mode: overlay;
  background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/></filter><rect width='100%' height='100%' filter='url(%23n)' opacity='0.65'/></svg>");
}
.htw-sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap; }
@media (prefers-reduced-motion: reduce) { .htw-grain { display: none; } }
`;

export function HalftoneWordmark({
  wordmark = "sight",
  height = "100%",
  align = "bottom-crop",
  crop = 0.2,
  dotGap = 6,
  radius = 85,
  grain = 0.45,
  interactive = true,
  dissolve = "none",
  wave = 0,
  fontWeight = 800,
  letterSpacing = "-0.05em",
  fontFamily,
  className = "",
}: {
  wordmark: string;
  height?: string;
  align?: HalftoneAlign;
  /** fraction of the cap height hidden past the edge (top-crop / bottom-crop) */
  crop?: number;
  dotGap?: number;
  radius?: number;
  grain?: number;
  interactive?: boolean;
  dissolve?: HalftoneDissolve;
  /** traveling breath through the dot sizes: 0 = off, ~0.15 = gentle */
  wave?: number;
  fontWeight?: number;
  letterSpacing?: string;
  fontFamily?: string;
  className?: string;
}) {
  const rootRef = React.useRef<HTMLDivElement>(null);
  const canvasRef = React.useRef<HTMLCanvasElement>(null);
  const optsRef = React.useRef({ height, align, crop, dotGap, radius, interactive, dissolve, wave, fontWeight, letterSpacing, fontFamily, wordmark });
  React.useLayoutEffect(() => {
    optsRef.current = { height, align, crop, dotGap, radius, interactive, dissolve, wave, fontWeight, letterSpacing, fontFamily, wordmark };
  });

  const key = [wordmark, height, align, crop, dotGap, dissolve, fontWeight, letterSpacing, fontFamily].join("|");

  React.useEffect(() => {
    const root = rootRef.current;
    const canvas = canvasRef.current;
    if (!root || !canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    let w = 0;
    let h = 0;
    let dpr = 1;
    let px = -1e5;
    let py = -1e5;
    let raf = 0;
    let visible = true;
    let awake = true;
    let ring = { x: 0, y: 0, t: -1 };
    // flat arrays: x, y, vx, vy, hx, hy, radius per dot
    let dots = new Float32Array(0);
    let count = 0;

    const inkOf = (): RGB => parseColor(getComputedStyle(root).color) ?? [255, 255, 255];

    const layout = () => {
      const o = optsRef.current;
      const rect = root.getBoundingClientRect();
      w = Math.max(1, Math.round(rect.width));
      h = Math.max(1, Math.round(rect.height));
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);

      // The word once, at a size that fills the width, on a 1x mask.
      const mask = document.createElement("canvas");
      mask.width = w;
      mask.height = h;
      const m = mask.getContext("2d", { willReadFrequently: true });
      if (!m) return;
      const family = o.fontFamily || getComputedStyle(root).fontFamily;
      try { m.letterSpacing = o.letterSpacing; } catch { /* older engines */ }
      const word = o.wordmark || " ";
      m.font = `${o.fontWeight} 100px ${family}`;
      const measured = m.measureText(word).width;
      const fit = measured > 0 ? ((w * 1.08) / measured) * 100 : 0;
      m.font = `${o.fontWeight} ${fit}px ${family}`;
      const box = m.measureText(word);
      const cap = box.actualBoundingBoxAscent || fit * 0.72;
      m.fillStyle = "#000";
      m.textBaseline = "alphabetic";
      const c = Math.max(0, Math.min(0.6, o.crop));
      let baselineY: number;
      if (o.align === "bottom-crop") baselineY = h + cap * c;
      else if (o.align === "top-crop") baselineY = cap * (1 - c);
      else baselineY = h / 2 + cap / 2;
      m.fillText(word, (w - box.width) / 2, baselineY);
      const img = m.getImageData(0, 0, w, h).data;

      const gap = Math.max(3, o.dotGap + (w < 680 ? 1 : 0));
      const cols = Math.ceil(w / gap);
      const rows = Math.ceil(h / gap);
      const tmp: number[] = [];
      for (let gy = 0; gy < rows; gy++) {
        for (let gx = 0; gx < cols; gx++) {
          let sum = 0;
          for (let sy = 0; sy < 3; sy++) {
            for (let sx = 0; sx < 3; sx++) {
              const x = Math.min(w - 1, Math.floor(gx * gap + ((sx + 0.5) * gap) / 3));
              const y = Math.min(h - 1, Math.floor(gy * gap + ((sy + 0.5) * gap) / 3));
              sum += img[(y * w + x) * 4 + 3];
            }
          }
          const cov = sum / (9 * 255);
          if (cov < 0.08) continue;
          const hx = gx * gap + gap / 2;
          const hy = gy * gap + gap / 2;
          tmp.push(hx, hy, 0, 0, hx, hy, radiusFor(cov, gap));
        }
      }
      dots = new Float32Array(tmp);
      count = tmp.length / 7;
      awake = true;
    };

    const dissolveState = () => {
      const o = optsRef.current;
      if (o.dissolve === "none") return { offsetY: 0, fade: 1, shrink: 1 };
      const sp = Math.min(1, Math.max(0, window.scrollY / Math.max(1, window.innerHeight)));
      const e = sp * sp;
      return {
        offsetY: (o.dissolve === "up" ? -1 : 1) * e * 340,
        fade: 1 - e * 0.92,
        shrink: 1 - e * 0.75,
      };
    };

    const draw = (now: number) => {
      const o = optsRef.current;
      const ink = inkOf();
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, h);

      const { offsetY, fade, shrink } = dissolveState();
      const r = o.interactive && !reduced ? Math.max(0, o.radius) : 0;
      const ringAge = ring.t < 0 ? 1e9 : now - ring.t;
      const ringR = ringAge * 0.9;
      let moving = false;
      for (let i = 0; i < count; i++) {
        const j = i * 7;
        let x = dots[j];
        let y = dots[j + 1] + offsetY;
        let vx = dots[j + 2];
        let vy = dots[j + 3];
        const hx = dots[j + 4];
        const hy = dots[j + 5] + offsetY;
        if (!reduced) {
          if (ringAge < 900) {
            const dx = hx - ring.x;
            const dy = hy - ring.y;
            const d = Math.sqrt(dx * dx + dy * dy) + 0.001;
            const band = 1 - Math.min(1, Math.abs(d - ringR) / 26);
            if (band > 0) {
              const f = band * 3.2 * (1 - ringAge / 900);
              vx += (dx / d) * f;
              vy += (dy / d) * f;
            }
          }
          const s = spring(x, y, vx, vy, hx, hy, px, py, r);
          x = s[0];
          y = s[1];
          vx = s[2];
          vy = s[3];
          if (Math.abs(vx) + Math.abs(vy) > 0.02 || Math.abs(x - hx) + Math.abs(y - hy) > 0.05) moving = true;
          else {
            x = hx;
            y = hy;
            vx = 0;
            vy = 0;
          }
          dots[j] = x;
          dots[j + 1] = y - offsetY;
          dots[j + 2] = vx;
          dots[j + 3] = vy;
        }
        // displaced dots warm → here: they fade, keeping print monochrome
        const d = Math.hypot(x - hx, y - hy);
        const k = Math.min(1, d / 28);
        const a = Math.max(0, fade * (1 - k * 0.8));
        if (a < 0.02) continue;
        // the breath: a slow traveling wave through the printed tone
        const wv = o.wave > 0 && !reduced ? o.wave : 0;
        const undulate =
          1 -
          wv * 0.55 * (0.5 + 0.5 * Math.sin(now * 0.0016 + (dots[j + 4] + dots[j + 5] * 1.4) * 0.012));
        const rad = dots[j + 6] * shrink * undulate;
        if (rad <= 0) continue;
        ctx.fillStyle = `rgba(${Math.round(ink[0])},${Math.round(ink[1])},${Math.round(ink[2])},${a.toFixed(3)})`;
        ctx.beginPath();
        ctx.arc(x, y, rad, 0, 6.2832);
        ctx.fill();
      }
      awake = moving || ringAge < 900 || (o.wave > 0 && !reduced);
    };

    const loop = (now: number) => {
      raf = 0;
      if (!visible) return;
      draw(now);
      if (awake) raf = requestAnimationFrame(loop);
    };
    const wake = () => {
      awake = true;
      if (!raf && visible) raf = requestAnimationFrame(loop);
    };

    const toLocal = (e: PointerEvent | MouseEvent) => {
      const b = canvas.getBoundingClientRect();
      return [e.clientX - b.left, e.clientY - b.top] as const;
    };
    const onMove = (e: PointerEvent) => {
      if (!optsRef.current.interactive) return;
      const p = toLocal(e);
      px = p[0];
      py = p[1];
      wake();
    };
    const onLeave = () => {
      px = -1e5;
      py = -1e5;
      wake();
    };
    const onDown = (e: PointerEvent) => {
      if (!optsRef.current.interactive || reduced) return;
      // don't detonate on top of real controls
      const t = e.target as HTMLElement | null;
      if (t?.closest("a,button,input,textarea")) return;
      const p = toLocal(e);
      ring = { x: p[0], y: p[1], t: performance.now() };
      wake();
    };
    const onScroll = () => {
      if (optsRef.current.dissolve !== "none") wake();
    };

    layout();
    draw(performance.now());
    wake();

    root.addEventListener("pointermove", onMove);
    root.addEventListener("pointerleave", onLeave);
    root.addEventListener("pointerdown", onDown);
    window.addEventListener("scroll", onScroll, { passive: true });
    const ro = new ResizeObserver(() => {
      layout();
      wake();
    });
    ro.observe(root);
    const io = new IntersectionObserver((entries) => {
      visible = entries[0] ? entries[0].isIntersecting : true;
      if (visible) wake();
    });
    io.observe(root);
    // a theme flip re-inks the print; a late web font re-sets the word
    const themeMo = new MutationObserver(() => wake());
    themeMo.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
    let alive = true;
    if (document.fonts?.ready) {
      document.fonts.ready.then(() => {
        if (!alive) return;
        layout();
        wake();
      });
    }

    return () => {
      alive = false;
      cancelAnimationFrame(raf);
      ro.disconnect();
      io.disconnect();
      themeMo.disconnect();
      root.removeEventListener("pointermove", onMove);
      root.removeEventListener("pointerleave", onLeave);
      root.removeEventListener("pointerdown", onDown);
      window.removeEventListener("scroll", onScroll);
    };
    // key drives re-layout; per-frame options come through optsRef
  }, [key]);

  return (
    <div ref={rootRef} className={`htw-root ${className}`} style={{ height }}>
      <style>{HTW_CSS}</style>
      <canvas ref={canvasRef} aria-hidden="true" />
      {grain > 0 && <div className="htw-grain" style={{ opacity: Math.min(1, grain) * 0.12 }} />}
      <span className="htw-sr">{wordmark}</span>
    </div>
  );
}
