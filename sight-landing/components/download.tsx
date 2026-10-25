"use client";

import React from "react";
import { Apple } from "lucide-react";
import { Reveal } from "./playground";

// Update this URL when the release asset is published. The download button
// prompts first, then triggers a direct download — no GitHub tab opens.
const RELEASE_URL =
  "https://github.com/mirasawe/Sight/releases/latest/download/Sight.dmg";

/**
 * DOWNLOAD — one button, one question, one file.
 * Clicking "Download" never navigates away: a small confirmation sheet asks
 * for permission, then the installer downloads directly to the user's Mac.
 */
export function DownloadCta() {
  const [open, setOpen] = React.useState(false);
  const dialogRef = React.useRef<HTMLDivElement>(null);

  React.useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", onKey);
    // lock scroll while the sheet is open
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
  }, [open]);

  const confirm = () => {
    setOpen(false);
    const a = document.createElement("a");
    a.href = RELEASE_URL;
    a.download = "Sight.dmg";
    a.rel = "noreferrer";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  };

  return (
    <section
      id="download"
      className="dotgrid scroll-mt-20 px-5 py-28 md:py-40"
      aria-labelledby="download-title"
    >
      <Reveal className="mx-auto max-w-3xl text-center">
        <h2
          id="download-title"
          className="text-balance text-5xl font-semibold tracking-[-0.03em] sm:text-6xl md:text-7xl"
        >
          Download Sight
        </h2>
        <p className="mx-auto mt-5 max-w-[48ch] text-balance text-secondary md:text-lg">
          Free and open source. The local model (~932 MB) is downloaded once —
          after that, everything happens on your Mac.
        </p>
        <div className="mt-10 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <button
            type="button"
            onClick={() => setOpen(true)}
            className="flex h-14 items-center gap-3 rounded-full bg-primary px-8 text-[16px] font-medium text-paper transition-transform hover:scale-[1.03] active:scale-[0.98]"
          >
            <Apple className="size-5" aria-hidden />
            Download for macOS
          </button>
          <a
            href="https://github.com/mirasawe/Sight"
            target="_blank"
            rel="noreferrer"
            className="flex h-14 items-center gap-3 rounded-full border border-line-strong px-8 text-[16px] text-secondary transition-colors hover:border-primary hover:text-primary"
          >
            <GitHubMark className="size-5" />
            Star on GitHub
          </a>
        </div>
        <p className="micro mt-8 text-faint">
          Free and open source · macOS 27 and later · Apache-2.0
        </p>
      </Reveal>

      {/* confirmation sheet */}
      {open && (
        <div
          className="fixed inset-0 z-50 flex items-end justify-center p-4 sm:items-center"
          role="dialog"
          aria-modal="true"
          aria-labelledby="download-dialog-title"
        >
          <button
            type="button"
            aria-label="Close"
            className="absolute inset-0 bg-black/50 backdrop-blur-sm"
            onClick={() => setOpen(false)}
          />
          <div
            ref={dialogRef}
            className="relative z-10 w-full max-w-md rounded-2xl border border-line bg-surface-raised p-6 shadow-2xl shadow-black/40"
          >
            <div className="flex items-center gap-3">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/icons/app-icon.png"
                alt=""
                className="size-11 rounded-xl"
              />
              <div>
                <p
                  id="download-dialog-title"
                  className="text-[17px] font-medium text-primary"
                >
                  Download Sight?
                </p>
                <p className="micro text-faint">Sight.dmg · macOS 27+</p>
              </div>
            </div>
            <p className="mt-4 text-[14px] leading-relaxed text-secondary">
              The installer is about 12 MB. On first launch Sight downloads the
              local model (~932 MB) once — after that, everything happens on
              your Mac. No account, no cloud.
            </p>
            <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
              <button
                type="button"
                onClick={() => setOpen(false)}
                className="h-11 rounded-full border border-line-strong px-6 text-[14px] text-secondary transition-colors hover:border-primary hover:text-primary"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={confirm}
                className="flex h-11 items-center justify-center gap-2 rounded-full bg-primary px-6 text-[14px] font-medium text-paper transition-transform hover:scale-[1.03] active:scale-[0.97]"
              >
                <Apple className="size-4" aria-hidden />
                Download
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}

function GitHubMark({ className = "" }: { className?: string }) {
  return (
    <svg viewBox="0 0 16 16" className={className} aria-hidden fill="currentColor">
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.4 7.4 0 0 1 4 0c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8Z" />
    </svg>
  );
}