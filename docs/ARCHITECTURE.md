# Architecture

Sight is a native macOS SwiftUI application. It has a very small app target and a
package target, because the goal was to keep most of the interesting logic
framework-agnostic and easy to test.

## Targets

```
Sight.xcodeproj
├── Sight             (app target — SwiftUI UI exercising SightCore)
├── SightTests        (unit tests for the app-level model)
├── SightUITests      (screenshot / flow tests)
└── SightCore         (Mac core — SPM package)
    ├── Engine        (model engine + porter, tokenizer, embeddings)
    ├── Extraction    (file-context helpers)
    ├── ModelStore    (download + verify + path layout)
    └── Persistence   (JSON stores, AppPaths, bookmarks, journal)
```

## Layers

```
┌ SwiftUI app ─ AppModel ── SightCore ─┐
│   prose-writer UI        engine      │
└───────────────────observations──────┘
```

### 1. `SightCore` (SPM)

The honest core. It has almost no UI dependency:

- `Engine/` — the model adapter that produces 768-d vectors plus their
  Matryoshka prefixes (512/256/128).
- `Extraction/` — file-context hints (extension, size, path, spinner names).
- `ModelStore/` — a small downloader with pinned SHAs, a manifest of file sizes
  (so first-run UI can show a progress bar), and cache layout logic.
- `Persistence/` — atomic JSON stores (`ConfigStore`, `RuleStore`),
  the immutable `AppPaths` tree, and a reversible `Journal` for moves.

### 2. `Sight` (app target)

A thin SwiftUI front-end with an `AppModel` `@Observable` object at its root.
`AppModel` owns the state machine: it starts, loads config/rules, checks the model,
monitors the root folder, performs sweeps, and publishes events.

There are no `UIViewController`s. `WindowAccessor` is the single bridge that
configures the `NSWindow` for dark/light backgrounds and tiles.

### 3. Vendored runtime (`Sight/Vendor/EmbeddingGemma2CoreAI/`)

Because Sight needs exact behavior, it vendors the CoreAI runtime wrappers and the
model bundle format from the EverPaper conversion. This is the same Apache-2.0
licensing as the rest of the repo, so no extra license dependency is created.

## Data flow

```
user drops folder          FSEventsMonitor
                │              │
                ▼              ▼
            rootURL ──►  AppModel.startMonitoring
                               │
                               ▼
                        sweep → Sorter.classify
                               │
                               ├─► RoutingDecision (mode: review/auto)
                               │                         │
                               ▼                         ▼
                       ReviewView (human)        ExecuteMove (sandbox-safe)
                                                         │
                                                         ▼
                                                Journal.record → undo/steps
```

## Why the app target is small

Keeping tests tiny means CI runs in a couple of minutes. The engine, the store
and the journal are all fully testable without a display, so they have the strongest
test suite; the UI is exercised by light screenshot tests and a demo mode.

## The cost of a clean architecture

`AppModel` is intentionally sized in a few files (`AppModel.swift`, `AppModel+Model.swift`,
`AppModel+Sorting.swift`). It is not a service locator. It is a plain `@Observable`
object, which makes the whole tree testable with a fake `Sorter`.

## Life cycle

```
launch
 └─ AppModel.bootstrap
     ├─ DemoMode.isEnabled?  → seed the deterministic demo tree and return
     ├─ AppPaths.ensureDirectories
     ├─ ConfigStore.load
     ├─ RuleStore.load
     ├─ restoreFolderAccess
     ├─ ModelStore.diskUsage / isInstalled
     ├─ if installed → Task { loadModel }   (async — UI stays responsive)
     └─ if config.hasCompletedOnboarding && rootURL → startMonitoring
```

## Design rules

- No nested `ZStack` bloat; use design tokens (`sightTheme`).
- Keep UI views pure: no business-specific fallbacks inside a view.
- A repository concern belongs to `SightCore`, not to a view.
