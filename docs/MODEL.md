# Model

Sight runs [EmbeddingGemma 2](https://huggingface.co/google/embeddinggemma-2) through
Apple's `CoreAI` runtime on macOS 27. This document explains where the model lives,
why the first launch is slow, and how to clear the store if a load gets interrupted.

## Pinned assets

`SightCore/Sources/SightCore/ModelStore/ModelManifest.swift` pins the exact revision of
`EverPaper/embeddinggemma-2-coreai` that the app downloads, along with the list of files
and their sizes and SHA-256 pins. Never move to `main` silently: a model update is a
reviewable change.

| asset | size | used for |
| --- | --- | --- |
| text + tokenizer + config | ~632 MB | text embeddings, and the shared 768-d space |
| vision | ~306 MB | images (on by default) |
| audio | ~585 MB | audio clips (off by default) |

Text + vision is the default first-run download (~971 MB on disk after unpacking).

## Where it lives

Inside the app's sandbox container:

```
~/Library/Containers/app.sight.mac/Data/Library/Application Support/Sight/
└── Models/EmbeddingGemma2/
    ├── config.json
    ├── tokenizer/
    └── model/
        ├── embeddinggemma-2-text-mm.aimodel
        └── embeddinggemma-2-vision.aimodel
```

The container is erased when you delete the app, so the download repeats on launch.

## First-launch specialization

`CoreAI` specializes each `.aimodel` for this executable the first time it loads it.
That work is wired to `app.sight.mac` in
`~/Library/Containers/app.sight.mac/Data/Library/Caches/coreai-cache/`.

Concretely:

- text tower alone: ~140 s
- text + vision: ~200 s
- all three towers: ~5 min

The UI shows a "Preparing your local model…" spinner. It looks stuck, but it is not.
Later launches are 1–3 seconds.

> ⚠ If the app is killed while specializing, the cache entry can end unusable and
> later loads fail inside `loadFunction`. Wipe
> `~/Library/Containers/app.sight.mac/Data/Library/Caches/coreai-cache/` and try again.

## Inference limits

- Text is capped at 2048 tokens before being truncated.
- Images run in one 280-soft-token budget (the 70/140/1120 budgets are not exported).
- Audio windows are 30 s; longer clips are averaged over windows (`chunk_mean`).

The only supported batch size is 1 — the Neural Engine serializes concurrent calls.
