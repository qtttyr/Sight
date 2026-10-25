"use client";

import React from "react";
import { MenuBar } from "./menu-bar";
import { Palette } from "./palette";
import { DesktopHero } from "./desktop-hero";
import { Playground } from "./playground";
import { StickyNote } from "./sticky-note";
import { HowDecides } from "./how-decides";
import { PrivacyTerminal } from "./privacy-terminal";
import { DownloadCta } from "./download";
import { DotFooter } from "./dot-footer";

/**
 * Sight landing — one page, same design tokens as the Mac app.
 * Order is deliberate: try → understand → trust → download.
 */
export function App() {
  const [palette, setPalette] = React.useState(false);

  return (
    <>
      <MenuBar onOpenPalette={() => setPalette(true)} />
      <main>
        <DesktopHero />
        <Playground />
        <StickyNote />
        <HowDecides />
        <PrivacyTerminal />
        <DownloadCta />
      </main>
      <DotFooter />
      <Palette open={palette} setOpen={setPalette} />
    </>
  );
}
