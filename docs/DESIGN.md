# Sight design system

The entire UI is monochrome. There is no brand color — the accent is a tiny circle.
If something in this repo must be changed only because it does not belong to the
"pure black / pure white" language, that change is a bug, not a feature.

## Theme

The app implements two explicit themes:

- `dark` — pure black paper, pure white ink.
- `light` — pure white paper, pure black ink.

The user chooses at onboarding, or changes it from the sidebar footer
(`dark / light` toggle) inside the app. There is also a `System` option if you want to
follow macOS.

Tokens live in `Sight/DesignSystem/Theme/SightTheme.swift`. Every view that colors itself
uses `@Environment(\.sightTheme)`; nothing in the app target reaches for
`Color.white` or `NSColor` directly.

## Spacing and radii

```
SightSpacing.xs  = 4    SightSpacing.s  = 8    SightSpacing.m  = 16   SightSpacing.l  = 28
SightRadius.card       = 14   SightRadius.control   = 9   SightRadius.pill  = 999
```

These are all *layout* tokens, not colors. Keep them together so a single macro-level change
(say, "reduce all radii") still ships.

## Typography

```
SightFont.hero   54 pt semibold tracking -3
SightFont.title  34 pt semibold tracking -2
SightFont.label  17 pt regular
SightFont.body   15 pt regular secondary color
SightFont.micro  11 pt semibold tracking +3 uppercase
SightFont.mono    13 pt monospaced code
```

## Interaction

- Buttons: `SightButtonStyle` (primary = filled ink-on-paper, ghost = hairline outline).
- Hover: 150 ms, `opacity 0.85`, slight scale.
- Keyboard: `⌘K` opens the command palette from anywhere in the shell.
- The palette itself is a small, centered overlay; the sidebar also exposes it as a `⌘K` pill.

## Screens

| Screen | Purpose |
| --- | --- |
| `OnboardingView` | 3 steps: welcome, folder, model. Once only. |
| `LiveSorterView` | The primary screen: drop zone, activity, metrics, undo. |
| `RulesView` | Rule list (WIP / JUNK toggles), rule editor, zero-shot test. |
| `InsightsView` | Learned categories, confidence histogram, model card, fingerprints. |
| `SettingsView` | Watched folder, mode, threshold, embedding size, theme, model. |
| `CommandPalette` | Fuzzy navigation to every screen and action. |

## Accessibility

Every interactive control has a label or a `help`. Drag areas use `onDrag`/`onDrop`
plus a keyboard fallback through the command palette.
