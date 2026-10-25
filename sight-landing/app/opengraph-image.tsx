import { ImageResponse } from "next/og";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

export const alt = "Sight — Your files, sorted by meaning";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function Image() {
  const icon = await readFile(join(process.cwd(), "public", "icons", "app-icon.png"));
  const iconSrc = `data:image/png;base64,${icon.toString("base64")}`;

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          padding: "72px 80px",
          background: "#000000",
          color: "#ffffff",
          fontFamily: "sans-serif",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 20 }}>
          <img src={iconSrc} width={64} height={64} alt="" style={{ borderRadius: 14 }} />
          <span style={{ fontSize: 26, letterSpacing: 2, opacity: 0.7 }}>SIGHT</span>
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
          <div style={{ fontSize: 88, fontWeight: 700, lineHeight: 1.02, letterSpacing: -2 }}>
            Your files, sorted by meaning.
          </div>
          <div style={{ fontSize: 28, opacity: 0.7, maxWidth: 900 }}>
            An on-device file organizer for macOS. No cloud, no telemetry, no
            accounts. Free and open source.
          </div>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", fontSize: 22, opacity: 0.5 }}>
          <span>Made by Miras Kustaibek</span>
          <span>sightmk.vercel.app</span>
        </div>
      </div>
    ),
    size,
  );
}
