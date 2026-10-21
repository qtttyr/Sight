<div align="center">

# Sight

**Your files, sorted by meaning.**

A native macOS app that keeps a folder organized — by building meaning vectors of files and
matching them against rules you write in plain language. Everything runs on-device.

</div>

<div align="center">

![macOS 27+](https://img.shields.io/badge/macOS-27%2B-black) ![Swift 6](https://img.shields.io/badge/Swift-6-blue) ![CoreAI](https://img.shields.io/badge/Core%20AI-Neural%20Engine-black)

</div>

---

Sight watches a folder (usually `~/Downloads`) and sorts newly dropped files into
meaning-based categories. It has no cloud, no telemetry, no telemetry-like "educational"
model sharing. It is one local embedding model + a rules engine + a review screen.

## What it does

1. **Drop a folder.** Sight monitors it (`FSEvents`) and proposes a category for each file
   using an on-device embedding.
2. **Review or auto-accept.** In `Review` mode Sight asks you before it moves anything.
   In `Auto` mode it sorts files quietly using a similarity threshold you control.
3. **Write rules in words.** Each rule is a sentence ("design files, mockups, screenshots").
   Sight converts it to an embedding fingerprint at startup and compares every new file
   against all rule fingerprints.
4. **Learn from the outcome.** The journal records every move, so you can undo.

## Why it is fast

Sight's engine is the Apple `CoreAI` runtime running:

- an **EmbeddingGemma 2 text tower** (~632 MB, Neural Engine preferred), and
- an **EmbeddingGemma 2 vision tower** (~306 MB, optional but on by default).

Text inference is ~5 ms and image inference ~0.37 s on the Neural Engine — enough to keep up
with ordinary desktop usage. The first launch specializes the towers for this app; that is
the 3–4 minute "Preparing" step. Later launches are 1–3 seconds.

## What is where

```
Sight/                 The macOS app target (SwiftUI + AppKit bridging, thin)
SightCore/             SPM package: engine, persistence, the rules engine and tests
SightTests/            Small XCTest suite for the app-level model
SightUITests/          Screenshot & flow tests (demo mode, real setup, second run)
docs/                  Architecture, design, demo mode
scripts/               Handy local scripts (fmt/test/release)
.github/workflows/     CI: SightCore unit tests + swift-format check
```

## Docs

| File | What it explains |
| --- | --- |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | How the app and SightCore fit together |
| [`docs/DESIGN.md`](docs/DESIGN.md) | The design system, sidebar, themes |
| [`docs/DEMO.md`](docs/DEMO.md) | The `-SightDemo` flag used by UI tests |
| [`docs/MODEL.md`](docs/MODEL.md) | Core AI model store, first-load specialization, cache |

## Building

```sh
xcodebuild -scheme Sight -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/DerivedData
```

Open `Sight.xcodeproj` in Xcode 27 and press `⌘R`. The app is sandboxed; the model lives in
the app's `Application Support/Sight/Models/EmbeddingGemma2` folder inside the container.

## Running the tests

```sh
xcodebuild -scheme Sight -destination 'platform=macOS' test
```

SightCore can also run standalone:

```sh
cd SightCore && swift test --scratch-path .build
```

## Contributing

Small PRs welcome. Keep the design system pure SwiftUI where possible and don't add
dependencies to the app target for the sake of it. Run the tests before submitting.

## License

Apache 2.0. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
