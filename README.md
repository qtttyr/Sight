# Sight

```
███████╗██╗ ██████╗ ██╗  ██╗████████╗
██╔════╝██║██╔════╝ ██║  ██║╚══██╔══╝
███████╗██║██║  ███╗███████║   ██║
╚════██║██║██║   ██║██╔══██║   ██║
███████║██║╚██████╔╝██║  ██║   ██║
╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝
```

> **Your files, sorted by meaning.**
> On your Mac. By a model that lives in your home folder.
> No cloud. No accounts. No telemetry. Apache-2.0.

[![macOS 27+](https://img.shields.io/badge/macOS-27%2B-000000?style=flat-square&labelColor=ffffff&color=000000)](https://github.com/mirasawe/Sight)
[![License](https://img.shields.io/badge/license-Apache--2.0-000000?style=flat-square&labelColor=ffffff&color=000000)](./LICENSE)
[![Open source](https://img.shields.io/badge/open-source-000000?style=flat-square&labelColor=ffffff&color=000000)](https://github.com/mirasawe/Sight)

---

## The idea

Your Mac is already smart enough.

Sight gives the neural engine your files — **to read, not to scan** — and sorts
them by meaning. The model is a 632 MB text tower (plus an optional vision
tower), specialized once for this app, resident in your home folder. Downloads
read, sorted, archived. The network card takes a nap.

It is one quiet project, for one quiet folder.

## What it does

- **Reads** a file the way a careful human would — name, content, context.
- **Decides** where it belongs, with a confidence score you can see.
- **Files** it, or asks you first, depending on the mode you chose.
- **Never leaves the Mac.** Zero sockets. Zero accounts. Zero cloud.

Two modes. **Review** — every move waits for your nod. **Auto** — Sight files
on its own and shows you the receipt. Switch any time. One folder, one app.

## How it decides

Sight builds a *meaning vector* of each file and matches it against rules you
write in plain language — *"design files, mockups, screenshots"* — not regex,
not extensions. Each rule carries a **fingerprint**: a small, readable
signature of what the rule learned. You can see why a file went where it went.

```
invoice_2026_0032.xlsx  →  Invoices     · 90%  ·  4 ms
IMG_4032.HEIC           →  Screenshots   · 98%  ·  3 ms
backup_2026.zip         →  Archives      · 96%  ·  4 ms
```

Thirteen filed. One left for you. Zero bytes left the Mac.

## Privacy, stated plainly

If it's not on your Mac, it doesn't exist.

- The engine is **resident**, not streamed.
- The network card is **offline by construction** — `lsof` shows zero sockets.
- No telemetry, no analytics, no crash reporters phoning home.
- You own the model. You own the rules. You own the folder.

## Quick start

```bash
# build the app
open Sight.xcodeproj
# ⌘R in Xcode  (macOS 27+, Apple Silicon)

# or, the landing site
cd sight-landing
npm install
npm run dev        # http://localhost:3000
```

The local model (~932 MB) downloads once, on first launch, into your home
folder. After that, everything is air-gapped.

## The landing

`sight-landing/` is a standalone Next.js 16 site (Tailwind 4, motion, lucide).
Monochrome by design — any color is a bug. It ships the same tokens as the app.

```bash
cd sight-landing
npm run build      # static export → out/
npm run lint       # eslint, zero warnings
```

## Contributing

Pull requests welcome. Keep it quiet:

- Monochrome only. Big type, bold scale, responsive on every device.
- Less text, more motion. One orchestrated moment per section.
- Real interactivity over decoration.

See [`docs/DESIGN.md`](./docs/DESIGN.md) and [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md).

## Credits

Made by **[Miras Kustaibek](https://github.com/mirasawe)**.

If you search my name, this project should be the first thing you find.

## License

Apache-2.0. See [`LICENSE`](./LICENSE) and [`THIRD_PARTY_LICENSES.md`](./THIRD_PARTY_LICENSES.md).

---

*Sight — one folder, one app, zero cloud.*
