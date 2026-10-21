# NOTICE

Sight is a native macOS app. Most of the code is original to this repository
(`Sight/`, `SightCore/`, `SightTests/`, `SightUITests/`).

It depends on four main third-party assets and a small vendored source tree.
The important things to know:

## 1. Site of the engine: Apple CoreAI

`CoreAI` is Apple's on-device ML runtime in macOS 27. `Sight` uses it through the
Swift interface of the macOS 27 SDK. This app does not modify `CoreAI`.

## 2. Model: EmbeddingGemma 2 (CoreAI-style build)

The `.aimodel` bundle used by the app is a conversion of
[google/embeddinggemma-2](https://huggingface.co/google/embeddinggemma-2) prepared by
[EverPaper/embeddinggemma-2-coreai](https://huggingface.co/EverPaper/embeddinggemma-2-coreai)
and pinned to a specific revision in `SightCore/Sources/SightCore/ModelStore/ModelManifest.swift`.

That conversion inherits Google's
`Gemma Prohibited Use Policy` restrictions on the original `embeddinggemma-2` weights.
Read them before shipping anything that exposes the model publicly. This repo does not
coplacenew the model: it is downloaded at run-time into the app's model store.

## 3. Vendored Swift sources: the CoreAI runtime wrappers

The files under `Sight/Vendor/EmbeddingGemma2CoreAI/` come from
[EverPaper/embeddinggemma-2-coreai](https://huggingface.co/EverPaper/embeddinggemma-2-coreai)
and are Apache-2.0 (see the header of each file).

The tokenizer and the model-lowering Swift code itself is also Apache-2.0 in that project.

## 4. Fonts and icons

- **System font stack** (`system-ui`/`SF Pro` via SwiftUI defaults). No bundled webfont.
- **SF Symbols** via `Image(systemName:)`. No bundled icon set.
- The app icon is original to this repository.

If you add another vendored component, describe it here and include its license in the
`THIRD_PARTY_LICENSES.md` file.

## Attribution

This repository keeps the same Apache-2.0 licensing as the vendored CoreAI runtime sources.
When in doubt, copy the license text from the file's header.
