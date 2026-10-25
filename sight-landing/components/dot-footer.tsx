"use client";

import type { ReactNode } from "react";
import { ArrowUp } from "lucide-react";
import { HalftoneWordmark } from "./halftone-wordmark";

/**
 * THE FOOTER — the name again, printed as a halftone field and cropped by
 * the page's bottom edge. Dots part around the pointer; a click sends a
 * shock ring through the word. Above the print: two quiet link columns
 * and a back-to-top. No traditional footer chrome.
 */
export function DotFooter() {
  return (
    <footer className="relative mt-8 border-t border-line">
      <div className="mx-auto max-w-6xl px-5 pt-10">
        <div className="flex flex-col gap-8 sm:flex-row sm:items-start sm:justify-between">
          {/* wordmark echo */}
          <p className="micro flex items-center gap-2.5 text-tertiary">
            <span className="size-2 animate-breathe rounded-full bg-primary" aria-hidden />
            SIGHT — opens &amp; files, on your Mac
          </p>

          {/* columns */}
          <nav className="flex gap-14 sm:gap-20" aria-label="Footer">
            <div className="flex flex-col gap-2.5">
              <span className="micro text-faint">Product</span>
              <FootLink href="#playground">Playground</FootLink>
              <FootLink href="#how">How it decides</FootLink>
              <FootLink href="#privacy">Why local</FootLink>
              <FootLink href="#download">Download</FootLink>
            </div>
            <div className="flex flex-col gap-2.5">
              <span className="micro text-faint">Project</span>
              <FootLink href="https://github.com/qtttyr/Sight" external>
                Source
              </FootLink>
              <FootLink
                href="https://github.com/qtttyr/Sight/blob/main/THIRD_PARTY_LICENSES.md"
                external
              >
                Licenses
              </FootLink>
            </div>
          </nav>

          {/* back to top */}
          <a
            href="#top"
            className="micro flex items-center gap-2 self-start text-tertiary transition-colors hover:text-primary"
          >
            <ArrowUp size={12} aria-hidden /> Back to top
          </a>
        </div>

        <p className="micro mt-10 text-faint">
          Made by{" "}
          <a
            href="https://miraskustaibek.me"
            target="_blank"
            rel="noreferrer"
            className="text-secondary transition-colors hover:text-primary"
          >
            Miras Kustaibek
          </a>{" "}
          · open source · Apache-2.0
        </p>
      </div>

      {/* the print — taller band, grain, shock ring on click */}
      <HalftoneWordmark
        wordmark="sight"
        height="min(46vh, 26rem)"
        align="bottom-crop"
        crop={0.16}
        dotGap={5}
        radius={90}
        grain={0.5}
        fontWeight={800}
        letterSpacing="-0.05em"
        className="mt-4"
      />
    </footer>
  );
}

function FootLink({
  href,
  children,
  external = false,
}: {
  href: string;
  children: ReactNode;
  external?: boolean;
}) {
  return (
    <a
      href={href}
      {...(external ? { target: "_blank", rel: "noreferrer" } : {})}
      className="text-[14px] text-secondary transition-colors hover:text-primary"
    >
      {children}
    </a>
  );
}
