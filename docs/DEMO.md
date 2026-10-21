# Demo mode

UI tests are deterministic: they pass `-SightDemo` to the app and the app ignores
all persistence.

## Usage

```sh
xcodebuild -scheme Sight -destination 'platform=macOS' \
  test -only-testing:SightUITests/SightScreenshotTests
```

The screenshot test launches the app with `-SightDemo`, which:

- skips `bootstrap()`'s real work,
- seeds a deterministic set of rules and events,
- installs an on-disk `appState` handler for "approve in review".

## Why not production wiring?

Because tests should not mutate your real model store or your real folder. The real
paths are still covered by UI tests that do not pass `-SightDemo`:

- `SightRealSetupTests` — first-run onboarding + real download (very slow).
- `SightSecondRunTests` — second launch after onboarding is done.

Deleting the app container between runs is how the real-flow tests get a clean start
(`~/Library/Containers/app.sight.mac/Data/Library/Application Support/Sight`).

## What the demo mode does

```swift
DemoMode.configure(model)
// - model.rules  = 4 fixed rules
// - model.events = 3 deterministic events
// - model.isDemoMode = true (saveConfig/saveRules become no-ops)
```

The flag is `#if DEBUG`-gated in `AppModel+Model.swift`, so release builds ignore it
entirely.
