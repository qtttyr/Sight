"use client";

import { useEffect, useState } from "react";
import { ThemeToggle } from "./theme";
import { AudioLines } from "lucide-react";

export function MenuBar({ onOpenPalette }: { onOpenPalette: () => void }) {
  const [time, setTime] = useState("");
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const tick = () =>
      setTime(
        new Date().toLocaleTimeString("en-US", {
          hour: "numeric",
          minute: "2-digit",
          hour12: false,
        })
      );
    tick();
    const id = setInterval(tick, 10_000);
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const links = [
    ["Try", "#playground"],
    ["How it decides", "#how"],
    ["Why local", "#privacy"],
    ["Download", "#download"],
  ] as const;

  return (
    <header
      className={`fixed inset-x-0 top-0 z-40 transition-all duration-200 ${
        scrolled ? "border-b border-line bg-paper/85 backdrop-blur-md" : "bg-transparent"
      }`}
      style={
        scrolled
          ? undefined
          : // over the hero print: a paper halo keeps the chrome legible
            { textShadow: "0 1px 3px var(--paper), 0 0 14px var(--paper), 0 0 34px var(--paper)" }
      }
    >
      <div
        className="mx-auto flex max-w-6xl items-center gap-6 px-5 py-3"
        style={{ maxWidth: "min(100%, 1100px)" }}
      >
        {/* brand: app icon + SIGHT */}
        <a href="#top" className="flex items-center gap-2.5" aria-label="Sight — home">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/icons/app-icon.png"
            alt=""
            className="size-6 rounded-md"
          />
          <span className="micro-wide micro">SIGHT</span>
        </a>

        <nav className="hidden items-center gap-5 md:flex" aria-label="Sections">
          {links.map(([label, href]) => (
            <a
              key={href}
              href={href}
              className="text-[13px] text-tertiary transition-colors hover:text-primary"
            >
              {label}
            </a>
          ))}
        </nav>

        <div className="ml-auto flex items-center gap-3">
          <button
            onClick={onOpenPalette}
            className="micro hidden rounded-full border border-line px-2.5 py-1 text-tertiary transition-colors hover:text-primary md:block"
            aria-label="Command palette (⌘K)"
          >
            ⌘K
          </button>
          <span className="micro hidden items-center gap-1.5 text-faint sm:flex">
            <AudioLines className="size-3 opacity-60" aria-hidden />
            {time || "—"}
          </span>
          <ThemeToggle compact />
        </div>
      </div>
    </header>
  );
}
