# Third-party licenses

This repo is Apache-2.0 overall. It depends on three non-original artifacts, each
with its own licensing rules.

## EverPaper/embeddinggemma-2-coreai

- **Source:** https://huggingface.co/EverPaper/embeddinggemma-2-coreai
- **Revision:** pinned in `SightCore/Sources/SightCore/ModelStore/ModelManifest.swift`
- **License:** Apache-2.0
- **Used for:**
  - The vendored Swift sources under `Sight/Vendor/EmbeddingGemma2CoreAI/`
    (tokenizer, image/audio front-end, CoreAI model wrapper).
  - The `.aimodel` bundle downloaded into the Windows/Downloads model store
    (`text + vision`, and optionally `audio`).

The Apache-2.0 text is reproduced in `LICENSE` at the root of this repository
because the vendored sources are Apache-2.0 as well.

## google/embeddinggemma-2

- **Source:** https://huggingface.co/google/embeddinggemma-2
- **Revision:** see the `EverPaper` conversion metadata plus the pinned revision above.
- **License:** Gemma Prohibited Use Policy (it is a Google model, not a license you can
  copy into another app).
- **Used for:** the trained weights the model store downloads. They stay on-device; the app
  never uploads or shares them.

## Apple `CoreAI` runtime

- **Source:** macOS 27 SDK. Not redistributed.
- **License:** Apple SDK terms. If you ship a compiled Sight binary, you already accepted
  those terms when you installed Xcode.

## Fonts and icons

- System UI text (SwiftUI, SF Pro) — Apple system font stack, not bundled.
- SF Symbols — Apple system iconography via `Image(systemName:)`, not bundled.
- App icon — original to this repository.

When in doubt, copy a license from an existing file header onto `NOTICE.md` and then
add it here. Try to keep `THIRD_PARTY_LICENSES.md` to those three items; it is easier to
review a short list than an enormous one.
