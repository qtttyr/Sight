# Sight design system

The entire UI is monochrome. There is no brand color — the accent is a tiny circle.
If something in this repo must be changed only because it does not belong to the
"pure black / pure white" language, that change is a bug, not a feature.

## Theme

The app implements two explicit themes:

- `dark` — pure black paper, pure white ink.
- `light` — pure white paper, pure black ink.

There is also a `System` option that follows macOS. The theme is changed in
Settings, or from the sidebar footer toggle.

Tokens live in `Sight/DesignSystem/Theme.swift`, `Typography.swift` and
`Motion.swift`. Every view that colors itself uses `@Environment(\.sightTheme)`;
nothing in the app target reaches for `Color.white` or `NSColor` directly.

### Text contrast

The four text steps are the only opacity ramp in the app, and every one of them
clears WCAG AA against its background:

| Token | Opacity | Contrast |
| --- | --- | --- |
| `textPrimary` | 1.00 | 21:1 |
| `textSecondary` | 0.72 | 10.7:1 |
| `textTertiary` | 0.58 | 6.5:1 |
| `textFaint` | 0.46 | 4.7:1 |

`textFaint` is the lightest step and is still readable — it carries real content
(the watched folder path, a rule's destination, timestamps), not decoration.

## Spacing and radii

```
SightSpace.xs = 4    SightSpace.sm = 8    SightSpace.md = 12   SightSpace.lg = 16
SightSpace.xl = 24   SightSpace.xxl = 32  SightSpace.huge = 48 SightSpace.giant = 64
SightRadius.control = 8   SightRadius.row = 12   SightRadius.card = 16
```

These are all *layout* tokens, not colors. Keep them together so a single macro-level change
(say, "reduce all radii") still ships.

## Typography

```
SightFont.display   48 pt semibold
SightFont.title     28 pt semibold
SightFont.headline  17 pt semibold
SightFont.number    32 pt medium
SightFont.body      13 pt regular
SightFont.label     11 pt medium
SightFont.micro     10 pt semibold monospaced
SightFont.mono      12 pt regular monospaced
```

## Interaction

- Buttons: `SightButtonStyle` (primary = filled ink-on-paper, ghost = hairline outline).
- Keyboard: `⌘K` opens the command palette from anywhere in the shell,
  `⌘1`…`⌘3` jump between Live, Rules and Insights, `⌘N` opens a new rule,
  `⌘R` sweeps, `⌘Z` undoes, `⌘⏎` opens the review queue.
- The palette is a centered overlay; `↑`/`↓` move the highlight, `⏎` runs it.
- Every animation goes through `SightMotion`, which collapses to an instant
  change when the system asks for reduced motion.

## Screens

| Screen | Purpose |
| --- | --- |
| `OnboardingView` | 3 steps: welcome, folder, model. Once only. |
| `LiveSorterView` | The primary screen: drop zone, activity, metrics, undo. |
| `RulesView` | Rule list, rule editor, zero-shot test. |
| `InsightsView` | Learned categories, confidence histogram, model card, fingerprints. |
| `SettingsView` | Watched folder, mode, confidence, renaming, embedding size, theme, model. |
| `CommandPalette` | Fuzzy navigation to every screen and action. |

## Accessibility

- Every interactive control has a label, and icon-only buttons carry a `help`.
- `SightSegmented` marks the selected option with `.isSelected`.
- `SightSwitch` announces its state and names what it belongs to.
- `SightSlider` supports `accessibilityAdjustableAction`, so it can be moved
  with VoiceOver and from the keyboard.
- Drag areas use `onDrag`/`onDrop` plus a keyboard fallback through the command
  palette.
- Motion follows the system "Reduce Motion" setting.
