---
license: apache-2.0
base_model: google/embeddinggemma-2
library_name: coreai
pipeline_tag: feature-extraction
language:
  - multilingual
tags:
  - coreai
  - apple-neural-engine
  - on-device
  - embeddings
  - sentence-similarity
  - image-embeddings
  - image-feature-extraction
  - audio-embeddings
  - audio-feature-extraction
  - multimodal
  - text-to-image-retrieval
  - text-to-audio-retrieval
  - gemma
  - macos
---

# EmbeddingGemma 2 for Apple Core AI (text + images + audio)

[google/embeddinggemma-2](https://huggingface.co/google/embeddinggemma-2) (Gemma 4 family, 768-d Matryoshka
embeddings) converted to Apple's **Core AI** runtime for **macOS 27 on Apple silicon**: the text encoder, since
1.1 the image encoder and since 1.2 the audio encoder, in one shared 768-d space. A screenshot, a chart, a slide,
a photo, a voice memo or a sound becomes one vector, and the vector of the query "bar chart of lamp units sold per
city" (or "the night train to the coast") lands next to it.

- **Text** — everything `SentenceTransformer("google/embeddinggemma-2").encode()` does for text runs in one graph:
  token embedding, 24 bidirectional encoder layers, final norm, 512→768 projection, masked mean pooling and L2
  normalization. One Neural Engine region plus the token lookup (a small GPU gather): about **5 ms, 0.3 ms of CPU
  and 0.4–0.5 ms of GPU time** per short text.
- **Images** — the 16-layer vision encoder turns an image into 280 "soft tokens" that go through the same text
  encoder, exactly as upstream does, plus an exact host-side preprocessing (decode, resize, patches) shipped in
  Swift and numpy. Two compute routes for images, both shipped and validated: the **Neural Engine** (default,
  ~0.37 s per image, ~2 ms of CPU, almost no GPU) or the **GPU** (~0.13 s per image, about 3× faster, more power),
  chosen independently of the text route (see "Images: Neural Engine or GPU").
- **Audio** — the 12-layer conformer audio encoder turns up to 30 s of audio into 25 soft tokens per second that go
  through the same text encoder, exactly as upstream does, plus the exact host-side front end (decode, mono,
  16 kHz, log-mel) in Swift and numpy. Neural Engine (default, 18 ms end to end for a 3 s clip, 0.16 s for 30 s,
  ~1–2 ms of CPU) or GPU (22 ms / 0.12 s), chosen independently of text and images (see "Audio: Neural Engine or
  GPU"). Speech (18 languages tested), music, sounds: a text query finds the clip and a clip finds its caption.

Ported by Everpaper — everpaper.app. Weights are the original ones (bf16 rounded to fp16), with a few constant
scales folded in and unused position rows cut (listed in NOTICE). Apache-2.0, see
[LICENSE](LICENSE) and [NOTICE](NOTICE) (modification list, Gemma Prohibited Use Policy pointer).

## Download

```bash
hf download EverPaper/embeddinggemma-2-coreai --local-dir EmbeddingGemma-2-CoreAI-v1.2
cd EmbeddingGemma-2-CoreAI-v1.2
```

(`hf` comes with `pip install -U huggingface_hub`.) Then run one of the quick starts below; both begin with a
smoke test that checks the model on your machine. Text only? Add `--exclude "model/embeddinggemma-2-vision.aimodel/*"
--exclude "model/embeddinggemma-2-audio.aimodel/*"` to skip the 293 MiB image encoder and the 562 MiB audio
encoder (or only one of them).

## What's new in 1.2

- **Audio**: `model/embeddinggemma-2-audio.aimodel` (functions `audio_192` … `audio_3000`, one per frame bucket),
  `embedAudio` / `embed_audio` in both runners, the exact audio front end (decode, mono, 16 kHz, log-mel) in Swift
  and numpy, audio smoke tests and 16 generated test clips. Up to 30 s per clip (the model's window, as upstream);
  longer audio is truncated or, on request, embedded as the mean of its 30 s windows.
- **Two audio routes**: the audio encoder runs on the Neural Engine (default) or on the GPU, set independently of
  text and images (`audioCompute:` / `audio_compute=` / `--audio-compute`).
- **Text and images are unchanged**: the text and image assets are byte-identical to 1.1, so vectors indexed with
  1.1 (and text vectors indexed with 1.0) stay valid. The audio sequence goes through the same `mm_<S>` functions.
- **Same API**: without `loadAudio: true` / `load_audio=True` nothing changes; the audio asset is not even loaded.

What was new in 1.1: images (`model/embeddinggemma-2-vision.aimodel`, `embedImage` / `embed_image`, exact image
preprocessing, two image routes); the text asset became `embeddinggemma-2-text-mm.aimodel` (functions `mm_<S>`,
bit-identical to the 1.0 text encoder with no image in the sequence; the 256 bucket became 288). Versions 1.0 and
1.1 remain available as the repository's earlier revisions; see CHANGELOG.md.

## What is in the package

```
EmbeddingGemma-2-CoreAI-v1.2/
  README.md, LICENSE, NOTICE, CHANGELOG.md, CHECKSUMS.sha256
  model/
    embeddinggemma-2-text-mm.aimodel/   text encoder, functions mm_32 … mm_2048 (fp16, 632.2 MB = 602.9 MiB)
    embeddinggemma-2-vision.aimodel/    image encoder, function vision_2520 (fp16, 307.0 MB = 292.8 MiB)
    embeddinggemma-2-audio.aimodel/     audio encoder, functions audio_192 … audio_3000 (fp16, 589.3 MB = 562.0 MiB)
    config.json                         assets, buckets, shapes, special ids, prompts, Matryoshka dims
    tokenizer/                          tokenizer.json + tokenizer_config.json, unchanged from google/embeddinggemma-2
    MODEL-ATTRIBUTION.json              base model, checkpoint sha256, exporter versions, modification list
  swift/      SwiftPM package: library `EmbeddingGemma2CoreAI` + tool `eg2-cli` (no third-party dependencies)
  python/     embeddinggemma2_coreai.py (library + CLI), eg2_image.py (exact image preprocessing),
              eg2_audio_frontend.py (exact audio front end), smoke_test.py, requirements(.lock)
  tests/      smoke-reference.json + tokenizer-cases.json (text), images/ (12 generated test images),
              image-smoke-reference.json, preprocess-cases.json, check_preprocess.py, audio/ (16 generated clips
              + ref/ front-end references), audio-smoke-reference.json, audio-preprocess-cases.json, and the generators
  export/     eg2_text.py, eg2_text_mm.py, eg2_vision.py, eg2_audio.py, export.py: reproduce the assets from the checkpoint
```

## Requirements

- macOS 27 or later on Apple silicon (validated on an M5 with 24 GB).
- Swift: Xcode 27 / Swift 6 toolchain; the `CoreAI`, `ImageIO`, `CoreGraphics`, `AVFoundation` (audio decoding)
  and `Accelerate` (audio FFT) frameworks of the macOS 27 SDK.
- Python (runtime): Python 3.12 (the validated version; 3.14 with numpy 2.5 also passed the text smoke tests). macOS
  does not ship 3.12: install it with `brew install python@3.12` or `uv python install 3.12` (see "Quick start —
  Python"). `python/requirements.txt` installs Apple's `coreai-core` Python runtime (provides `coreai.runtime`),
  `numpy`, `tokenizers`, `pillow` (images) and `soundfile` (audio decoding with libsndfile, the decoder upstream
  uses; if it is missing, the runner falls back to macOS `afconvert`). The exact validated versions are in
  `python/requirements.lock`. Only the exporter (`export/`, optional) needs torch 2.9.0.
- Disk: 1.56 GB for `model/` (1488 MiB): text asset 0.63 GB, image asset 0.31 GB, audio asset 0.59 GB, tokenizer
  0.03 GB (text + image assets 0.94 GB, 0.97 GB with the tokenizer). The system keeps a per-app specialization
  cache under `~/Library/Caches/coreai-cache/` (about 1.4 GB for the text asset, 5.5 GB with the image and audio
  assets).
- Memory with all three assets loaded on the Neural Engine: Python ~415 MB process footprint plus ~2.1 GB on the
  Neural Engine (the audio asset accounts for ~1.4 GB of it: five functions); the Swift CLI reported ~300 MB plus
  ~0.77 GB. 16 GB Macs: fine; 8 GB Macs were not tested.

## Quick start — Swift

Add the package to your app's `Package.swift`. SwiftPM names a local package after its folder, so the package
identity is `swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.macOS("27.0")],
    dependencies: [.package(path: "…/EmbeddingGemma-2-CoreAI-v1.2/swift")],
    targets: [
        .executableTarget(name: "MyApp", dependencies: [.product(name: "EmbeddingGemma2CoreAI", package: "swift")]),
    ]
)
```

```swift
import Foundation
import EmbeddingGemma2CoreAI

let pkg = URL(fileURLWithPath: "…/EmbeddingGemma-2-CoreAI-v1.2")            // the downloaded package folder
let modelURL = pkg.appendingPathComponent("model")
let model = try await EmbeddingGemma2(bundle: modelURL, compute: .neuralEngine, loadVision: true, loadAudio: true)
// images on the GPU instead (≈3× faster, more power), text stays on the Neural Engine:
// let model = try await EmbeddingGemma2(bundle: modelURL, compute: .neuralEngine, loadVision: true, imageCompute: .gpu)
// audio on the GPU instead (faster for long clips, ~16 ms of CPU per clip), text stays on the Neural Engine:
// let model = try await EmbeddingGemma2(bundle: modelURL, compute: .neuralEngine, loadAudio: true, audioCompute: .gpu)
try await model.prewarm()                                    // optional, ~1 s warm

// text (unchanged from 1.0)
let q = try await model.embed("bar chart of lamp units sold per city", kind: "search_query")   // [Float], 768
let d = try await model.embed("The lease runs until the last day of March.", kind: "document", dim: 256)

// images, same space (two of the package's test images)
let imageURL = pkg.appendingPathComponent("tests/images/chart_bar.png")
let photoURL = pkg.appendingPathComponent("tests/images/scene_sunset.jpg")
let img = try await model.embedImage(url: imageURL)                                         // as stored, no EXIF rotation
let photo = try await model.embedImage(url: photoURL, applyEXIFOrientation: true)           // camera photos upright
// let shot = try await model.embedImage(cgImage: someCGImage)                              // raw samples of a CGImage
let score = cosineSimilarity(q, img)

// lower level
let ids = model.tokenize("some text", kind: "document")      // <bos> + prefix + text + <eos>, truncated to 2048
let raw = try await model.embed(ids: ids)                    // runs mm_<smallest bucket that fits>
let inputs = try ImagePreprocessor.prepare(url: imageURL)    // decode + exact resize + patches (CPU, ~10 ms typical)
let soft = try await model.softTokens(inputs)                // [n * 512] Float16 (vision_2520)
let rawImage = try await model.embed(sequence: model.imageSequence(softTokens: soft))       // runs mm_288

// audio, same space (two of the package's test clips)
let clipURL = pkg.appendingPathComponent("tests/audio/speech_en_train_16k.wav")
let a = try await model.embedAudio(url: clipURL)                                            // first 30 s, as upstream
let longURL = pkg.appendingPathComponent("tests/audio/long_melody_35s_16k.mp3")
let long = try await model.embedAudio(url: longURL, longAudio: .chunkMean)                  // mean of the 30 s windows
// let live = try await model.embedAudio(samples: [leftChannel, rightChannel], sampleRate: 48000)   // PCM from AVAudioEngine etc.
let spoken = try await model.embed("the night train to the coast", kind: "search_query")
let hit = cosineSimilarity(spoken, a)
// lower level: decode -> mono -> 16 kHz -> log-mel frames -> audio_<Tb> -> sequence <bos> <|audio> [n] <audio|> <eos> -> mm_<S>
let wav = try AudioFrontend.loadMono16k(url: clipURL)        // [Float] at 16 kHz (AudioDecoder + AudioResampler)
let audioInputs = try AudioFrontend.prepare(wav16k: wav)     // log-mel features + masks for one frame bucket
let audioSoft = try await model.audioSoftTokens(audioInputs) // [n * 512] Float16 (audio_<bucket>)
let rawAudio = try await model.embed(sequence: model.audioSequence(softTokens: audioSoft))

// when the model is released (or at exit) you may delete the temp files this process created, see "Temp files"
EmbeddingGemma2.removeOwnMPSGraphTempFiles()
```

`EmbeddingGemma2(bundle:compute:)` without `loadVision: true` / `loadAudio: true` loads only the text asset (no
extra memory, no extra first-load cost); image and audio calls then throw. `compute` places the text asset;
`imageCompute` and `audioCompute` (default: the same as `compute`) place the image and audio encoders, see
"Images: Neural Engine or GPU" and "Audio: Neural Engine or GPU". `GemmaTokenizer` is public too (`encode`, `encodeWithSpecials`,
`decode`): an exact re-implementation of the Hugging Face `tokenizers` pipeline for this `tokenizer.json`.

Command line (`cd swift && swift build -c release`; the binary is `.build/release/eg2-cli` or
`.build/out/Products/Release/eg2-cli` depending on the toolchain):

```
eg2-cli smoke       ../model ../tests/smoke-reference.json ../tests/image-smoke-reference.json ../tests/audio-smoke-reference.json --compute ane --cleanup-temp
eg2-cli embed       ../model --kind search_query "bar chart of lamp units sold per city"      (text only, no vision/audio asset)
eg2-cli embed-image ../model ../tests/images/chart_bar.png ../tests/images/scene_sunset.jpg [--image-compute gpu] [--exif] [--dim 768]
                                                            (one JSON line per image)
eg2-cli embed-audio ../model ../tests/audio/speech_en_train_16k.wav ../tests/audio/long_melody_35s_16k.mp3 [--audio-compute gpu]
                    [--long truncate|chunk_mean] [--dim 768]  (one JSON line per clip)
eg2-cli tokcheck    ../model ../tests/tokenizer-cases.json
eg2-cli pixcheck    ../tests/preprocess-cases.json          (decode + resize vs the Python reference, no model)
eg2-cli audiocheck  ../tests/audio-preprocess-cases.json    (decode + resample + log-mel vs the Python reference, no model)
eg2-cli latency     ../model --compute ane [--image-compute gpu] [--audio-compute gpu] --trials 50 [--text-only]
eg2-cli prewarm     ../model [--image-compute gpu] [--audio-compute gpu] [--text-only]
```

`--compute ane|gpu|cpu` places the text asset (and the image and audio encoders, unless `--image-compute` /
`--audio-compute` are given); `--image-compute` / `--audio-compute ane|gpu` place only that encoder.

## Quick start — Python

From the package folder. macOS has no Python 3.12 of its own (its `python3` is 3.9 and Homebrew's default is
newer), so install one first, with Homebrew or with uv:

```
brew install python@3.12                                   # then:
python3.12 -m venv .venv && .venv/bin/pip install -r python/requirements.txt

# or, with uv instead of Homebrew:
uv python install 3.12 && uv venv --python 3.12 .venv && uv pip install --python .venv -r python/requirements.txt
```

```
source .venv/bin/activate
cd python && python3 smoke_test.py --compute ane --cleanup-temp      # first run: a few minutes to specialize, see below
```

```python
from embeddinggemma2_coreai import EmbeddingGemma2CoreAI, remove_own_mpsgraph_temp_files

m = EmbeddingGemma2CoreAI("../model", compute="ane", load_vision=True, load_audio=True)   # ane | gpu | cpu | default
# images on the GPU (≈3× faster, more power), text on the Neural Engine:
# m = EmbeddingGemma2CoreAI("../model", compute="ane", load_vision=True, image_compute="gpu")
# audio on the GPU, text on the Neural Engine:  ..., load_audio=True, audio_compute="gpu"
m.prewarm()
q = m.embed("bar chart of lamp units sold per city", kind="search_query")   # numpy float32 [768]
v = m.embed_image("../tests/images/chart_bar.png")            # path or PIL image; apply_exif_orientation=True for photos
a = m.embed_audio("../tests/audio/speech_en_train_16k.wav")   # path, or (samples array, sample_rate=...); first 30 s
long = m.embed_audio("../tests/audio/long_melody_35s_16k.mp3", long_audio="chunk_mean")   # mean of the 30 s windows
d = m.embed("The lease runs until the last day of March.", kind="document", dim=256)
score = float(q @ v)
del m
remove_own_mpsgraph_temp_files()                              # the Python runtime leaks ~650 MB per load, see below
```

`python3 embeddinggemma2_coreai.py embed|embed-image|embed-audio|smoke|tokcheck|latency|prewarm …` mirrors the
Swift tool, including `--compute`, `--image-compute` and `--audio-compute` (run it with the venv's Python).
`smoke_test.py --text-only` checks the text path without loading the image and audio encoders; `--no-audio` skips
the audio reference; `smoke_test.py --image-compute gpu --audio-compute gpu` checks the GPU routes.

## Text

| | |
|---|---|
| Functions | `mm_32`, `mm_64`, `mm_128`, `mm_288`, `mm_512`, `mm_1024`, `mm_2048` (one per sequence bucket S) in `embeddinggemma-2-text-mm.aimodel` |
| `input_ids` | `[1, S]` int32: `<bos>`=2, prompt-prefix tokens, text tokens, `<eos>`=1, right-padded with `<pad>`=0 |
| `attention_mask` | `[1, S]` float16: 1 for real tokens, 0 for padding |
| `mm_embeds`, `mm_mask` | `[1, S, 512]` / `[1, S]` float16: **zeros for text** (see "Images" and "Audio" for what goes there) |
| `embedding` | `[1, 768]` float16, already L2-normalized |
| Max length | 2048 tokens including `<bos>`/`<eos>` and the prefix. Longer input is **truncated** by the runners (the original model accepts 8192; chunk long documents at ≤ 512 tokens for retrieval, the embedding is a mean over tokens anyway). |
| Bucket choice | the smallest S ≥ token count. Padding does not change the result (padded and unpadded runs are bit-identical). |
| Matryoshka | 512 / 256 / 128 dims: take the first N values and re-normalize (`embed(..., dim:)` does it). |

**Task prompts** (exactly the upstream `config_sentence_transformers.json`; the runners prepend them by `kind`):

| kind | prefix |
|---|---|
| `document` | `title: none \| text: ` — for titled documents use `title: {title} \| text: {content}` yourself |
| `search_query` | `task: search result \| query: ` |
| `question_answering` | `task: question answering \| query: ` |
| `fact_checking` | `task: fact checking \| query: ` |
| `code_retrieval` | `task: code retrieval \| query: ` |
| `classification` | `task: classification \| query: ` |
| `clustering` | `task: clustering \| query: ` |
| `sentence_similarity` | `task: sentence similarity \| query: ` |

The runners add `<bos>` and `<eos>` themselves, as sentence-transformers does. Special tokens written literally in a
text (e.g. `<eos>`) are recognised as special tokens, exactly as in Hugging Face `tokenizers`; strip them if that
is not what you want.

## Images

### Neural Engine or GPU

The image encoder (`vision_2520`, ~0.92 TFLOP per image) runs on either the Neural Engine or the GPU. Both routes
use the same asset, both are validated, and you choose the route **for images independently of text**. Text always
runs where `compute` says (default: Neural Engine), and so does the image's final pass through the text encoder
(`mm_288`, ~15 ms). Measured on an M5 (24 GB, macOS 27) for one typical image (273 soft tokens):

| | **Neural Engine** (default) | **GPU** |
|---|---|---|
| time per image, end to end (excl. decode + resize) | 369 ms | 125 ms (**~3× faster**) |
| throughput, one process | ~2.7 images/s | ~8 images/s |
| CPU time per image (Swift / Python) | **2 ms** / 8.5 ms | 21 ms / 27 ms |
| GPU time per image | **~1 ms** (the GPU stays free) | ~103 ms (the GPU is ~80 % busy while indexing) |
| whole-machine power while indexing, above idle ¹ | **+8.3 W** | +28.5 W |
| energy per image, above idle ¹ | **3.1 J** | 3.8 J |
| memory (Swift, both assets loaded) | 260–275 MB + 608–1061 MB on the Neural Engine | 435–440 MB + 608–766 MB on the Neural Engine (text) |
| accuracy vs fp32, 373 + 30 tiny + 19 photo files (Python runner) | median 0.99998, min 0.9946 ² | median 0.99998, min **0.9989** ² |
| cross-modal retrieval (205 captions, both directions) | identical to fp32 at 768 dims | identical to fp32 at 768 dims |
| first load of the image encoder by a new executable | minutes (3–4 min for both assets; once per app and OS build) | 2–25 s |

¹ SMC whole-system power, MacBook on AC power, battery not charging, display on; idle ≈ 8 W. Python runner, 40 s
of continuous embedding, two runs each (8.1 / 8.4 W, 28.1 / 28.9 W). Running *everything* on the GPU (`compute:
.gpu`) costs +30.8 W and 4.2 J per image for the same speed.
² Both routes give median ≥ 0.99998 and ≥ 0.9997 on every ordinary image; the minimum is a 16×16 image upscaled to
768×768 (see "Limits"). On the GPU route with text on the GPU too, every image is ≥ 0.99975.

**Default: the Neural Engine.** It needs a fraction of the CPU and almost no GPU, draws about a third of the power,
and uses less energy per image, so indexing in the background does not heat the Mac, drain the battery or compete
with the UI, games or a local LLM on the GPU. **Choose the GPU** when wall-clock time matters more than power: a bulk
import on a plugged-in Mac, or a user waiting for a dropped image. Keep text on the Neural Engine in both cases
(text on the GPU is slower for short texts and costs ~10–30 ms of CPU per call).

How to switch (the route is fixed when the model is loaded; create a second instance to use both):

```swift
// Swift: images on the GPU, text on the Neural Engine
let model = try await EmbeddingGemma2(bundle: url, compute: .neuralEngine, loadVision: true, imageCompute: .gpu)
model.imageCompute          // .gpu   (if the `imageCompute:` argument is omitted, it equals `compute`)
```

```
# CLI (Swift eg2-cli and the Python runner take the same flags)
eg2-cli embed-image ../model --image-compute gpu ../tests/images/chart_bar.png ../tests/images/scene_sunset.jpg
eg2-cli smoke ../model ../tests/smoke-reference.json ../tests/image-smoke-reference.json --image-compute gpu
python3 embeddinggemma2_coreai.py embed-image ../model --image-compute gpu ../tests/images/chart_bar.png
```

```python
# Python
m = EmbeddingGemma2CoreAI("../model", compute="ane", load_vision=True, image_compute="gpu")
m.image_compute             # "gpu"   (if the image_compute= argument is omitted or None, it equals compute)
```

`imageCompute: .cpu` / `--image-compute cpu` also exists (~520 ms per image, the least precise route; for testing).
The shipped graph splits the attention queries into 12 blocks, which the Neural Engine needs (560 → 355 ms); an
un-split export takes ~10 % less time on the GPU (104 vs 116 ms for `vision_2520`, Python runner medians; `eg2-cli
latency` measures the shipped split graph at 109–111 ms) but was not worth a second 300 MB asset
(`export.py --qchunks 1` builds it for a GPU-only deployment).

### Prompts and cross-modal search

Images take **no prompt** (as the model card prescribes): the image sequence is `<bos> <|image> [soft tokens]
<image|> <eos>`. Text keeps its prompts. For "find the image that matches this text", embed the text with
`kind: "search_query"` and compare it with the image vectors by cosine (dot product: all vectors are
L2-normalized). Image vectors and document vectors live in the same space, so one index can hold both; for
image → text (caption search), embed the captions as `document`. Matryoshka prefixes work for images too.

### How an image becomes a vector

1. **Decode** to 8-bit RGB the way the reference does: alpha is dropped (not composited), EXIF orientation is
   **not** applied, no colour management. Palette, gray, gray+alpha, CMYK and 1-bit images are expanded; 16-bit
   samples are reduced to their high byte.
2. **Size**: the aspect ratio is kept, each side becomes a multiple of 48 px and the image fits 2520 patches of
   16×16 px (280 soft tokens). Small images are upscaled (1×1 → 768×768); extreme aspect ratios are allowed (a
   1-px-wide image becomes 48×13440). Most images end up with 250–280 soft tokens.
3. **Resize** with the exact antialiased bicubic filter the upstream processor uses on uint8 pixels (torchvision's
   kernel, width pass then height pass, integer arithmetic). This matters: Lanczos or bilinear resampling (what
   Core Image / vImage offer) moves the embedding down to cosine 0.96 (bilinear) or 0.86 (Lanczos) on the
   validation set, and wrong normalisation, BGR order or row-major patch order break it entirely.
4. **Patches** 16×16×3 of integer pixel values 0–255 (exact in float16; the graph applies upstream's ×1/255 and
   2p − 1 itself, folded into its first projection) in "cell-major" order (the 9 patches of each 3×3 pooling cell
   contiguous), with (x, y) positions, the axial-RoPE cos/sin tables and a padding mask → `vision_2520` →
   `[280, 512]` soft tokens, of which the first n are valid.
5. **Sequence** `<bos>`=2, `<|image>`=255999, n × `<|image|>`=258880, `<image|>`=258882, `<eos>`=1 (n + 4 ≤ 284
   tokens → bucket 288), the n soft tokens placed in the placeholder slots → `mm_288` → `[768]`, L2-normalized.

The runners do all of this; `VisionInputs` / `prepare_vision_inputs` expose the intermediate step for callers that
want to run the functions themselves (several images in one sequence, text + image).

### `vision_2520` (asset `embeddinggemma-2-vision.aimodel`)

| | |
|---|---|
| `patches` | `[1, 2520, 768]` float16: 16×16×3 patches flattened (py, px, c), **integer pixel values 0–255** (not ÷255), cell-major order, zero padded |
| `pos_x`, `pos_y` | `[1, 2520]` int32 patch column / row (0 for padding) |
| `cos`, `sin` | `[1, 1, 2520, 64]` float16 axial RoPE tables: channels 0–31 from x, 32–63 from y, 16 frequencies (θ = 100) duplicated |
| `patch_mask` | `[1, 2520]` float16, 1 for a patch, 0 for padding |
| `soft_tokens` | `[1, 280, 512]` float16; rows at index ≥ n are padding and must be ignored |

In `mm_<S>` the graph computes `x = embed(input_ids)·(1 − mm_mask) + mm_embeds·mm_mask` and then the text encoder,
so the soft tokens go into `mm_embeds` at the placeholder positions (not scaled) with `mm_mask` = 1 there. Any mix
fits a bucket: two images = 2·282 + 2 tokens → `mm_1024`, or text followed by an image.

### EXIF orientation: a decision for the integrator

The reference embeds a photo as stored: a portrait photo whose EXIF tag says "rotate 90°" is embedded sideways.
`applyEXIFOrientation: true` / `apply_exif_orientation=True` / `--exif` rotates it upright first; the upright
vector differs from the as-stored one by cosine ~0.97 and matches the same picture saved upright (0.998). For photos
from cameras and phones an app almost certainly wants `true`; for screenshots, renders and documents it makes no
difference. The default is `false` for parity with the reference. Pick one and index consistently.

### Video

Not included. Upstream embeds a video as **one** sequence of frames sampled at 1 fps (up to 32 frames, 140 soft
tokens per frame, `<|video|>` placeholders), which needs a 140-token vision shape and longer text buckets than this
package exports. Embedding sampled frames one by one as images works with this package and is a common
approximation, but it is not what upstream does and was not compared with upstream video vectors.

## Audio

### Neural Engine or GPU

The audio encoder (`audio_<Tb>`, ~0.6 GFLOP per soft token, ~450 GFLOP for 30 s) runs on either the Neural Engine
or the GPU; the clip's final pass through the text encoder (`mm_<S>`, S = tokens + 4) runs where `compute` says.
Measured on an M5 (24 GB, macOS 27), Swift `eg2-cli latency`, text on the Neural Engine:

| clip | bucket / tokens | `audio_<Tb>` Neural Engine | `audio_<Tb>` GPU | `mm_<S>` (Neural Engine) | end to end NE / GPU | CPU per clip NE / GPU |
|---|---|---|---|---|---|---|
| 3 s | 384 / 75 | 10.9 ms | 14.4 ms | 7 ms (`mm_128`) | **18 ms** / 22 ms | **1.1 ms** / 16 ms |
| 10 s | 1024 / 250 | 23.6 ms | 19–21 ms | 15 ms (`mm_288`) | 38 ms / **33–44 ms** | 1.2 ms / 14–22 ms |
| 30 s | 3000 / 750 | 86 ms | **50 ms** | 70 ms (`mm_1024`) | 156 ms / **119 ms** | 1.8 ms / 20 ms |

Front end (Swift, one core): decode + mono + resample of a 30 s stereo 48 kHz clip 39 ms (Accelerate dot products;
16 kHz input needs no resampling), log-mel + inputs 3 ms. The numpy front end takes ~0.6 s for the same resample.
Accuracy of the two routes is the same (table below). **Default: the Neural Engine** — a few milliseconds slower on
long clips, ~10–20× less CPU, almost no GPU (0.3–0.5 ms of GPU time per clip, against 10–47 ms per clip on the
GPU route). **Choose the GPU** for bulk indexing of long recordings when wall-clock time matters.
`audioCompute: .cpu` / `audio_compute="cpu"` / `--audio-compute cpu` is refused with an error before any asset is
loaded: the CPU route is not supported for audio.

```swift
let model = try await EmbeddingGemma2(bundle: url, compute: .neuralEngine, loadAudio: true, audioCompute: .gpu)
model.audioCompute          // .gpu   (if `audioCompute:` is omitted, it equals `compute`)
```

```
eg2-cli embed-audio ../model --audio-compute gpu ../tests/audio/speech_en_train_16k.wav
python3 embeddinggemma2_coreai.py embed-audio ../model --audio-compute gpu ../tests/audio/speech_en_train_16k.wav
```

### How an audio clip becomes a vector

1. **Decode** at the file's own sample rate, every channel, float32. Swift: AVAudioFile (AudioToolbox: WAV, AIFF,
   CAF, FLAC, ALAC, AAC/M4A, MP3, …). Python: `soundfile` (libsndfile, what upstream's `librosa.load` uses;
   installed by `requirements.txt`), and macOS `afconvert` for what libsndfile cannot read (AAC/M4A) or when
   `soundfile` is not installed.
2. **Mono**: the mean of the channels (as librosa does).
3. **Resample to 16 kHz** with the package's Kaiser-windowed sinc (identical in Swift and numpy, see "Audio:
   decoding and resampling"). Clips already at 16 kHz are untouched.
4. **Window**: the first 30 s (480 000 samples). Longer audio: see "Long audio".
5. **Log-mel frames** exactly as the upstream feature extractor: 160 zeros in front, frames of 320 samples every
   160 (periodic Hann), |FFT 512|, 128 triangular HTK mel bands 0–8 kHz, ln(mel + 0.001). A frame counts only if
   its whole window lies in real audio: n frames = ⌊(samples − 161) / 160⌋ + 1 (2999 for 30 s; fewer than 161
   samples give 0 frames and 0 tokens).
6. **Bucket**: the smallest of 192, 384, 1024, 1536, 3000 frames ≥ n; features zero-padded, three masks (frames,
   half frames, tokens) → `audio_<Tb>` → `[Tb/4, 512]` soft tokens, of which the first ⌈⌈n/2⌉/2⌉ are valid (25 per
   second; 750 for 30 s).
7. **Sequence** `<bos>`=2, `<|audio>`=256000, n × `<|audio|>`=258881, `<audio|>`=258883, `<eos>`=1 (n + 4 ≤ 754
   tokens → up to bucket 1024), the soft tokens placed in the placeholder slots → `mm_<S>` → `[768]`, L2-normalized.

Audio takes **no prompt** (as the model card prescribes). Text queries use `search_query`; captions as documents
use `document`. Image, audio and text vectors share the space, so one index can hold all three. Padding is exact:
the encoder is causal, so a clip's tokens do not depend on the bucket (verified: the same clip through its own
bucket and through `audio_3000` gives bit-identical soft tokens on the Neural Engine and tokens within float16
noise, cosine ≥ 0.99999, on the GPU).

### `audio_<Tb>` (asset `embeddinggemma-2-audio.aimodel`)

| | |
|---|---|
| Functions | `audio_192`, `audio_384`, `audio_1024`, `audio_1536`, `audio_3000` (frames of 10 ms; 1.92 s, 3.84 s, 10.24 s, 15.36 s, 30 s) |
| `features` | `[1, Tb, 128]` float16 log-mel frames, the first n rows real, zero after (values −6.9 … +7) |
| `frame_mask` | `[1, Tb]` float16: 1 for the first n rows |
| `half_mask` | `[1, Tb/2]` float16: 1 for the first ⌈n/2⌉ rows (after the first stride-2 convolution) |
| `token_mask` | `[1, Tb/4]` float16: 1 for the first ⌈⌈n/2⌉/2⌉ rows (= the soft-token count) |
| `soft_tokens` | `[1, Tb/4, 512]` float16; rows at index ≥ tokens are padding and must be ignored |

Why these buckets: they are the frame counts validated on the Neural Engine (placement and correctness); other
sizes are excluded for compatibility. Clips of 3.9–10 s therefore use the 1024 bucket (24 ms instead of ~15).
`export.py --audio-buckets` builds other sets; **verify every bucket you add on the Neural Engine**: correctness
with `eg2-cli smoke` and placement with the Neural Engine footprint that `eg2-cli latency` prints, not only that it
loads.

### Audio: decoding and resampling

The reference (`sentence-transformers` → `librosa.load(sr=16000)`) decodes with **libsndfile**, mixes to mono and
resamples with **libsoxr "HQ"**. The package reproduces the first two exactly and replaces the third:

- **Decoders.** Apple's AudioToolbox decoder (Swift; also the Python `afconvert` fallback) is sample-identical to
  libsndfile for WAV/AIFF/AIFC/CAF (any PCM depth, 8-bit to 64-bit float), FLAC and ALAC, and within 3e-7 for AAC
  (same decoder family). For **MP3** AudioToolbox does not always honour the LAME/Xing/Info tag: most files come out
  gapless, some as whole frames (encoder delay and padding still in place), and some with the delay removed but one
  or two whole frames too many at the end (`afinfo` then counts one packet more than the tag). The Swift decoder and
  the Python fallback read the tag and bring every case to its gapless length, after which the samples match
  libsndfile/mpg123 within 3e-5 (all 55 tagged MP3s tested: 16–48 kHz, mono/stereo, CBR/VBR). The residue sits
  where Apple's decoder outputs exact zeros and mpg123 values around 1e-5: inaudible, but the log-mel floor (0.001)
  makes the model sensitive to it in **digitally silent** passages. Clips with long digital silence (synthesized
  speech with pauses, synthesized sounds with silent decays) scored 0.990–0.9999 against the libsndfile-decoded
  reference (fp32, the same model on both waveforms; ≥ 0.99998 when the same files are decoded with libsndfile);
  MP3s without digital silence ≥ 0.99998. The Python runner decodes MP3 with `soundfile` (installed by
  `requirements.txt`) and is libsndfile-exact; only its `afconvert` fallback has this difference. In
  Swift, decode MP3 with another decoder and pass the samples to `embedAudio(samples:sampleRate:)`. **MP3 files
  without a LAME/Xing tag** cannot be trimmed: Apple's decoder removes the 529-sample decoder delay and libsndfile
  does not, so the two are 529 samples apart (cosine 0.92–0.993 on speech). **Ogg Vorbis**: libsndfile (Python with
  `soundfile`) is exact; Apple's decoder (Swift, `afconvert`) is 128 samples off libsndfile (cosine 0.990–0.9985 on
  speech).
- **Resampler.** libsoxr is LGPL and its "HQ" / "VHQ" settings already differ from each other by cosine up to
  0.004, so the package ships its own Kaiser-windowed sinc (polyphase, pass band 0.913 and stop band 1.0 of the
  lower Nyquist, 125 dB attenuation, unity DC gain, output length ⌈n·16000/rate⌉ like librosa), computed in double
  precision by the same formulas in Swift and numpy: the two give **bit-identical** 16 kHz waveforms on all 147
  resampled validation clips. Against libsoxr HQ, measured through the fp32 model on those 147 clips (8–96 kHz):
  median cosine 0.999999, 140 of 147 ≥ 0.9999, minimum 0.9953 (96 kHz synthesized wind noise; the 7 clips below
  0.9999 are all synthesized noise-like sounds), waveform SNR median 81 dB. Speech is unaffected (≥ 0.9999).
  An independent set (171 resampled lossless/AAC clips, 7.35–192 kHz) gave median 0.999999, 163 of 171 ≥ 0.9999,
  speech ≥ 0.99988, minimum 0.9939 (a synthesized 22.05 kHz engine hum whose upper mel bands sit at the log-mel
  floor); Swift and numpy were bit-identical on 191 of its 201 resampled clips and within 4e-15 on the rest (the AAC
  ones within the 3e-7 decoder difference). 16 kHz input bypasses the resampler entirely. Apple's own
  `AudioConverter` (even at maximum quality) would cost down to 0.93.
- **Features.** The numpy log-mel is bit-identical to the upstream extractor (214/214 clips, and 279/279 of the
  independent set). The Swift log-mel (Accelerate single-precision FFT) differs from numpy's by at most 0.006 per
  value (same waveform), which costs ≤ 0.0005 of cosine on the Neural Engine route (Swift vs Python vectors on 287
  clips: median 0.999996, min 0.99954).

### Long audio

The model's window is 30 s (`processor` default, 480 000 samples): upstream silently drops the rest. The runners
offer two policies: **`truncate`** (default; the first 30 s, exactly upstream) and **`chunk_mean`** (the mean of
the L2-normalized embeddings of consecutive 30 s windows, re-normalized; a trailing window too short for one
frame is dropped). Measured against the fp32 model on clips of 45–130 s (Neural Engine route): `chunk_mean`
matches the same policy in fp32 to ≥ 0.99996, and the mean is closer to an (unsupported) whole-clip embedding than the truncated one is (0.95
vs 0.94 at 130 s). Neither is what upstream returns for long audio, which is the truncated vector. For retrieval
over long recordings consider indexing each 30 s window as its own document.

### Audio accuracy

Parity with fp32 sentence-transformers on 214 generated clips (112 spoken sentences in 11 languages from 50+
macOS `say` voices and rates, used for local validation only and not shipped, 42 synthesized sounds, 30 edge cases, 17 copies of one sentence in different formats and
rates, 11 long clips, 3 mixtures; features from the upstream extractor so that the table measures the model):

| route (audio / text) | median | min | speech min | sounds min | edge / format / long min |
|---|---|---|---|---|---|
| Neural Engine / Neural Engine (default) | 0.99996 | 0.9981 (a synthesized chord) | 0.9987 | 0.9981 | 0.9991 / 0.99994 / 0.9997 |
| GPU / Neural Engine | 0.99998 | 0.9994 (phase-inverted stereo noise) | 0.99978 | 0.99943 | 0.9994 / 0.99997 / 0.99977 |

Cross-modal retrieval, 154 captions ↔ 154 clips (captions as `search_query` / `document`):

| | text → audio R@1 / R@5 / MRR | audio → text R@1 / R@5 / MRR |
|---|---|---|
| fp32 reference, 768 dims | 0.545 / 0.701 / 0.629 | 0.597 / 0.682 / 0.642 |
| Neural Engine route, 768 dims | 0.545 / 0.727 / 0.629 | 0.597 / 0.688 / 0.643 |
| GPU route, 768 dims | 0.545 / 0.714 / 0.628 | 0.597 / 0.682 / 0.642 |
| fp32 reference, 128 dims | 0.532 / 0.643 / 0.603 | 0.500 / 0.643 / 0.573 |
| Neural Engine route, 128 dims | 0.532 / 0.649 / 0.603 | 0.500 / 0.630 / 0.573 |

(Spoken sentences alone retrieve at MRR 0.79; the 42 synthesized sounds are a parity check, not a retrieval
benchmark: fp32 itself ranks only a third of them first.) The re-authored graph run in fp32 reproduces the
reference soft tokens to cosine ≥ 0.99999998 (213 clips).

On the Neural Engine the least precise inputs are digital silence (0.9993 on a 1 s silent clip, 0.9991 on 30 s)
and dense synthesized chords (0.998): float16 arithmetic on near-constant spectra. Speech from every voice and
language tested stayed ≥ 0.9983 (median 0.99997) across both validation sets.

**Independent validation set** (generated separately from the set above: 287 clips — 100 spoken sentences in 18
languages from 84 macOS `say` voices and rates (local only, not shipped), 46 synthesized sounds, 74 copies of two sentences in 17 containers/codecs
at 7.35–192 kHz, 54 edge cases (1 sample to 40 s, every bucket boundary, silence, clipping, DC offset, a 30 kHz
tone at 96 kHz, 2/4/6 channels, phase-inverted stereo), 8 long clips of 29.9–150 s, 5 speech-over-sound mixtures;
reference: fp32 sentence-transformers on the runner's own 16 kHz waveform, so the table measures features + model;
282 clips, upstream fails below 129 samples). Cosine at 768 dims, both runners:

| route (audio / text) | median | min | speech min (any format) | sounds min | edge min | Swift vs Python |
|---|---|---|---|---|---|---|
| Neural Engine / Neural Engine | 0.99996 | 0.9972 (30 kHz tone at 96 kHz: near-silence after resampling) | 0.9983 | 0.9984 | 0.9972 | median 0.999996, min 0.99954 |
| GPU / Neural Engine | 0.99998 | 0.9994 (speech at −90 dBFS) | 0.99996 | 0.9997 | 0.9994 | min 0.9999 |
| GPU / GPU | 1.00000 | 0.9995 (the same clip) | 0.99997 | 0.99985 | 0.9995 | min 0.99993 |

512 / 256 / 128 dims are the same or better (Neural Engine minimum 0.9973 / 0.9979 / 0.9987); the runners'
`dim:` output equals the truncated, re-normalized 768-d vector. Long clips: `truncate` ≥ 0.9999 and `chunk_mean` ≥
0.99978 (Neural Engine), ≥ 0.99985 (audio on the GPU, text on the Neural Engine) and ≥ 0.99996 (everything on the
GPU) against the same policy in fp32. Retrieval with the 146 captions (100
sentences, 46 sounds) as `search_query` / `document`: fp32 text → audio R@1 / R@5 / MRR 0.548 / 0.699 / 0.625,
audio → text 0.568 / 0.664 / 0.625; at 768 dims every route is within one query (0.007) of fp32 on every metric
(R@1 identical); at every size R@1 stays within one query and MRR within 0.007, and R@5 within one query except
text → audio R@5 at 256 dims (2 of 146 queries lower on the Neural Engine and GPU-audio routes) and at 128 dims
(2 of 146, Python GPU-audio route): synthesized-sound captions whose own clip tied the 5th result within 0.002 in
fp32.
End to end against upstream's own file path (libsndfile + libsoxr), the decoder and resampler effects described
above come on top: median 0.99995, minimum 0.990 for MP3/Ogg via Apple's decoder, 0.92 for an MP3 without a tag.

## Accuracy (measured)

Reference: sentence-transformers 6.1 / transformers 5.19 / torch 2.14.1 / torchvision 0.29.1, fp32, CPU, original
checkpoint; images passed as paths with no prompt; audio as 16 kHz arrays (libsndfile/ffmpeg + libsoxr HQ) with
no prompt (audio figures: "Audio accuracy" above). All test texts, images and audio clips are fictional and generated from code
(charts, UI-like screens, slides, documents, diagrams, drawn scenes, shapes, plus size, aspect-ratio, colour-mode,
JPEG-quality and EXIF stress cases); 19 files made from 14 public-domain camera photos (16 JPEGs plus 3 lossless PNG
re-saves) were used for local validation only and are not shipped.

### Images

Cosine between this port and the fp32 reference, 768 dims, on the independent validation set (373 generated
images, 205 of them with distinct captions, 30 extra tiny images, plus the 19 photo files; 512/256/128 dims behave
the same or better):

| route (images / text) | median | min | min, captioned | min, 30 tiny images | photos |
|---|---|---|---|---|---|
| Neural Engine / Neural Engine (default), Python | 0.99998 | 0.9946 ¹ | 0.99972 | 0.9958 | ≥ 0.99992 |
| GPU / Neural Engine, Python | 0.99998 | 0.9989 ¹ | 0.99994 | 0.99975 | ≥ 0.99998 |
| GPU / GPU, Python | 1.00000 | 0.99975 | 0.99996 | 0.99992 | ≥ 0.99998 |
| CPU only, Python | 0.99993 | 0.946 ¹ | 0.99930 | 0.966 | ≥ 0.99980 |
| any route, Swift, lossless files (PNG, WebP lossless, GIF, …) | same as Python (cosine to the Python vector ≥ 0.99988) | | | | |
| any route, Swift, JPEG and lossy WebP files | 0.9998 | 0.982 ² | | | ≥ 0.9981 (median 0.9994) |

¹ One 16×16 image upscaled to 768×768 (see "Limits"); every other image of the main set is ≥ 0.9997 on the Neural
Engine route. ² Synthetic charts with saturated colour edges saved as chroma-subsampled JPEG (see "JPEG in Swift").

A first, separate set (239 generated images, 77 queries) gave Neural Engine min 0.99966 / median 0.99997; it was
measured on an earlier build of the image asset (pixel/255 inputs, attention queries not split), not on the shipped
one, which was validated on the set above.
The Python preprocessing is bit-identical to the upstream processor on all 389 files upstream can read (its
patches × 1/255 equal the processor's `pixel_values` exactly); the Swift decoder + resampler is bit-identical to the
Python one on 280/280 lossless files. The re-authored graphs in fp32 reproduce the reference exactly (embedding
cosine 1.000000).

**Cross-modal retrieval** (205 captions ↔ 205 images, captions as `search_query` / `document`):

| | text → image R@1 / R@5 / MRR | image → text R@1 / R@5 / MRR |
|---|---|---|
| fp32 reference, 768 dims | 0.937 / 1.000 / 0.968 | 0.917 / 0.990 / 0.952 |
| this port, every tested route (Python: Neural Engine, GPU, mixed, CPU; Swift: Neural Engine, GPU, mixed), 768 dims | 0.937 / 1.000 / 0.968 | 0.917 / 0.990 / 0.952 |
| fp32 reference, 128 dims | 0.912 / 1.000 / 0.956 | 0.888 / 0.966 / 0.922 |

At 768 dims all seven routes rank every caption and every image exactly where fp32 does (205/205 in both
directions); at 512/256/128 dims every metric stays within 0.005 of fp32 and 201–205 of 205 keep their rank.

**JPEG in Swift.** ImageIO's JPEG decoder upsamples chroma differently from libjpeg (which the reference uses via
Pillow/torchvision), so JPEG pixels differ by 1–4 values on documents and up to 80 at saturated colour edges of
chroma-subsampled charts, before any resizing. Camera photos stay ≥ 0.998 (median 0.9994); JPEGs saved without
chroma subsampling ≥ 0.9999; retrieval ranks at 768 dims were unchanged for all 205 captions on every route. PNG and
every lossless format are exact. If you need reference-exact JPEG vectors, decode JPEGs with a libjpeg-compatible
decoder (e.g. the Python runner, which uses Pillow) and pass the pixels to `ImagePreprocessor`.

### Text

Unchanged from 1.0: the text functions give bit-identical outputs to 1.0 on 466 texts across every bucket, so the
1.0 figures hold. Cosine to fp32 on 357 fictional texts (English, Italian, code, Unicode stress, bucket
boundaries; 2–2048 tokens): Neural Engine min 0.99992 / median 0.99997; GPU min 0.99998; CPU only min 0.99916.
A second, independent set of 100 texts: min 0.99985 (an emoji-heavy text). **Expect ≥ 0.9998 on the Neural Engine
and GPU routes, ≥ 0.999 on the CPU route.** Retrieval on 1,712 fictional passages / 53 queries: MRR 0.766 at 768
dims, identical to fp32 (53/53 same first-relevant rank); 0.782 / 0.785 / 0.735 at 512 / 256 / 128 (fp32 0.790 /
0.786 / 0.735). On the image validation set, its 410 captions and documents scored ≥ 0.99993 on the Neural Engine.

**About float16.** The upstream model card says *"Do not use float16"*: the activations exceed the fp16 range
and a naive fp16 run returns NaN or degraded vectors. This port runs in fp16 on purpose (the Neural Engine is
fp16-only) and avoids the overflow by dividing every RMSNorm row and the final L2 normalization by its max-abs
value before squaring (see NOTICE). The figures above are the evidence; if you change the graph, keep that rescaling.

**Tokenizer.** The Swift `GemmaTokenizer` re-implements the Hugging Face `tokenizers` pipeline described by
`tokenizer.json` (special-token extraction, `Replace " " → "▁"`, BPE with byte fallback, rank-ordered merges),
on Unicode scalars and exact UTF-8 bytes, and reads `tokenizer.json` with an exact JSON reader (Foundation's
`JSONSerialization` strips a leading U+FEFF from string values). `tests/tokenizer-cases.json` holds 3,758
fictional texts (608,225 ids: CRLF, NFD/NFKD accents, emoji ZWJ sequences, Arabic with diacritics, Thai, CJK, 30+
languages, whitespace runs, control characters, special-token look-alikes, 5,000–80,000-character inputs);
`eg2-cli tokcheck` reports **3758 / 3758 identical** to `tokenizers` 0.23.3. The Python runner uses `tokenizers`.

### Smoke tests

`tests/smoke-reference.json` (3 fictional sentences, threshold 0.999) and `tests/image-smoke-reference.json` (10
generated images, their 10 queries and 2 documents; thresholds 0.998 for images and 0.999 for texts; every query
must rank its own image first). This package on the validation machine, all SMOKE PASS:

| route (images / text) | images (10) min, Swift / Python | texts (15) min | text → image |
|---|---|---|---|
| Neural Engine / Neural Engine (default) | 0.99972 (the JPEG; PNGs ≥ 0.99994) / 0.99995 | 0.99995 | 10 / 10 |
| GPU / Neural Engine (`--image-compute gpu`) | 0.99973 (the JPEG; PNGs ≥ 0.99997) / 0.99997 | 0.99995 | 10 / 10 |
| GPU / GPU (`--compute gpu`) | 0.99974 (the JPEG; PNGs ≥ 0.99998) / 0.99999 | 0.99999 | 10 / 10 |
| CPU only (Swift) | 0.99965 | 0.99996 | 10 / 10 |

Text-only smoke (vision and audio assets not loaded) passes with the same text cosines as 1.0 (0.999948 / 0.999979 /
0.999976; Matryoshka 512 / 256 / 128: 0.999979 / 0.999981 / 0.999989). `eg2-cli tokcheck` 3758 / 3758,
`eg2-cli pixcheck` 11 / 12 bit-identical plus the JPEG (decoder difference, expected), `tests/check_preprocess.py`
identical to torchvision and the upstream processor on all 12 test images.

**Audio smoke** (`tests/audio-smoke-reference.json`: 15 generated clips — 8 invented sentences in 7 languages
spoken by the eSpeak NG formant synthesizer, 4 synthesized sounds, silence, a tone and a 35 s MP3 melody — with
their 13 captions as queries and documents; per-clip thresholds 0.9995 for 16 kHz lossless clips, 0.995 for
resampled and MP3 clips, two measured exceptions carried in the file: digital silence 0.998 and the MP3 melody
0.985; a query must rank its own clip first wherever fp32 does, which is 11 of 13 — fp32 itself misses two
synthesized sounds). All SMOKE PASS:

| route (audio / text) | 12 speech + sound clips, min (Swift / Python) | silence | MP3 melody (Swift / Python with `soundfile` / Python `afconvert` fallback) | text → audio |
|---|---|---|---|---|
| Neural Engine / Neural Engine (default) | 0.9983 / 0.9991 (the piano chord; speech ≥ 0.99995) | 0.99926 | 0.9908 / 0.9994 / 0.9909 | 11 / 11 |
| GPU / Neural Engine (`--audio-compute gpu`) | 0.99989 / 0.99986 (speech ≥ 0.99997) | 0.99986 | 0.9902 / 0.9997 / 0.9903 | 11 / 11 |
| GPU / GPU (`--compute gpu`, Swift) | 0.99993 | 0.99996 | 0.9904 | 11 / 11 |

The MP3 melody is the one clip where the decoder matters: Apple's decoder (Swift, the Python `afconvert` fallback)
against libsndfile on a clip with silent decays (see "Audio: decoding and resampling"). `eg2-cli audiocheck` 16 /
16 within tolerance of the Python front end (11–13 waveforms bit-identical: every PCM, FLAC and ALAC file except
the 96 kHz tone, which is within 4e-17, and the two AAC files in some runs: Apple's AAC decoder varies by about one
float32 step between runs, ≤ 2e-7; MP3 within 3e-5; features within 0.0022 except MP3).

Caveats: one machine (M5, macOS 27). Core AI specializes per machine and OS build; re-run
`smoke` on your targets.

## Performance (measured, M5, Swift `eg2-cli latency`)

All timings in this README were measured on AC power. On battery with Low Power Mode on, the same machine took
1.4–1.6× as long for every figure (e.g. a 30 s clip 218 ms end to end on the Neural Engine, text `mm_1024` 107 ms
instead of 69 ms).

Images: see "Images: Neural Engine or GPU" for the side-by-side comparison (time, CPU, GPU, power, energy,
memory). Per function:

| | Neural Engine | GPU |
|---|---|---|
| `vision_2520` (one image, 273 soft tokens) | 355 ms | 109–111 ms |
| `mm_288` (the image's sequence) | 15 ms | 17 ms (14 ms when text stays on the Neural Engine) |
| image end to end (excl. decode + resize) | 369 ms | 125 ms |
| CPU time per image (excl. decode + resize) | 2.0 ms | 21 ms (text on the Neural Engine) / 34 ms (all on the GPU) |
| `audio_384` / `audio_1024` / `audio_3000` (3 s / 10 s / 30 s clips) | 10.9 / 23.6 / 86 ms | 14.4 / 19–21 / 50 ms |
| `mm_128` / `mm_288` / `mm_1024` (those clips' sequences, Neural Engine) | 7 / 15 / 70 ms | — |
| audio end to end, 3 s / 10 s / 30 s (excl. decode + front end) | 18 / 38 / 156 ms | 22 / 33–44 / 119 ms (text on the Neural Engine) |
| CPU time per clip (excl. decode + front end) | 0.7–1.9 ms | 14–22 ms |
| text buckets 32 / 64 / 128 / 288 / 512 / 1024 / 2048, p50 | 4.9 / 5.3 / 6.8 / 14.4 / 28 / 69 / 196 ms | 8.1 / 8.4 / 10.3 / 16 / 22 / 50 / 143 ms |
| text CPU per call | 0.3–0.7 ms | 10–31 ms |
| process footprint + Neural Engine footprint (text + images) | 260–275 MB + 608–1061 MB | 435–440 MB + 608–766 MB (images on the GPU, text on the Neural Engine); 0.9–1.1 GB, no Neural Engine (all on the GPU) |
| process footprint + Neural Engine footprint (all three assets) | 300–475 MB + 1.6–2.5 GB (Python; the Swift CLI reported 0.77 GB) | 650–850 MB + 766 MB (audio and images on the GPU) |

Text-only use (`loadVision` and `loadAudio` off): ~225 MB footprint plus ~770 MB on the Neural Engine. Decode + exact resize +
patches on the CPU (Swift, multi-threaded resampler): 10 ms median, 43 ms at the 90th percentile, 125 ms for a
6000×4000 JPEG (numpy: 45 ms median). Audio front end (Swift, one core): 14 ms median per clip over the 215
validation clips, 39 ms for the resample of a 30 s 48 kHz stereo clip, 3 ms for the log-mel of 30 s (numpy: ~0.6 s
for that resample, 6 ms log-mel). The CPU-only route takes ~520 ms per image and does not work for audio. The
Python runner gives the same model latencies within a few percent (8.5 ms CPU per image on the Neural Engine,
27 ms on the GPU; 1.3–4.7 ms CPU and 0.3–0.5 ms GPU time per audio clip on the Neural Engine, 15–25 ms CPU and 10–47 ms GPU time with audio on the GPU).

On the Neural Engine the 12 × 2520 × 2520 attention is the cost of the vision graph. Each function is batch-1; the
Neural Engine serializes concurrent calls. Nothing stops an app from running two routes at once (e.g. one instance
with images on the Neural Engine for background work and one on the GPU for interactive imports), at the memory cost
of a second instance.

**Load time** (`AIModel(contentsOf:)` + `loadFunction`):

| situation | time |
|---|---|
| warm (this executable has loaded these assets before) | 0.5–1.8 s, plus ~0.7 s for `prewarm()` |
| first load by an executable that has not loaded them before (a new app, a new binary name, the Python interpreter) | **about 5 minutes for all three assets** on the Neural Engine route (5 min 01 s measured for a new executable in a clean-room test); **about 3–4 minutes** for text + images (about 200 s observed for a Python interpreter that had never loaded them; the text asset alone took ~140 s in 1.0); about 30 s was observed for a renamed `eg2-cli` when another executable on the same machine had already compiled the same assets — do not rely on it |
| audio encoder, first load | 90–200 s on the Neural Engine when the assets were new to the machine; 19.5 s (Neural Engine) and 16 s (GPU) for a renamed `eg2-cli` after another executable had compiled them (text asset 28.5 s in the same situation) |
| image encoder on the GPU, first load | 2–25 s |

Load and `prewarm()` in the background at app start (or in a first-run step) and show progress; never on the main
thread and never lazily in front of the first query. The cache lives in
`~/Library/Caches/coreai-cache/<OS build>/<app>/`, where `<app>` is the executable name for a plain binary such as
`eg2-cli` and the bundle identifier for a bundled executable (`org.python.python` for a framework build of Python,
e.g. Homebrew's). It survives reboots but not OS updates, a renamed executable or a re-exported asset (including the
1.0 → 1.1 upgrade).

## Why three assets (and why `mm_<S>` also serves text)

- The image and audio encoders are separate assets so that users neither download nor load what they do not
  need (`--exclude` at download, `loadVision` / `loadAudio` off at runtime). The three graphs share nothing.
- The text asset carries the soft-token inputs so that one 600 MB text encoder serves texts, images and audio. With
  zero soft tokens it is the 1.0 encoder, bit for bit, so there is no reason to ship both.
- The text buckets are 32, 64, 128, **288**, 512, 1024, 2048: 288 holds one image sequence (≤ 284 tokens) and
  replaces 256 so that an image does not pay for the 512 bucket; a 30 s clip (754 tokens) uses 1024.
- The audio buckets (192, 384, 1024, 1536, 3000 frames) are the sizes validated on the Neural Engine, see "Audio:
  `audio_<Tb>`".

## Temp files (please read)

Each Neural Engine load writes compiled-graph copies to `$TMPDIR/com.apple.MetalPerformanceShadersGraph/
mpsgraph-<pid>-<date>-<n>/` (~360 MB for the text asset, ~300 MB for the image asset; the audio asset added
nothing on either route in our measurements, only an empty folder on the GPU route). Measured on macOS 27:

- Swift (`CoreAI` framework): the runtime deletes the folder when the model is released; our CLI leaves nothing
  behind. If your app exits or is killed while the model is loaded, the folder may remain.
- Python (`coreai.runtime`): the folder is **never** deleted, not even after `del model` and a clean interpreter
  exit (~650 MB per load with all three assets). Over a day of development this fills a disk.

Both runners ship a cleanup that removes only the folders belonging to the **current process** (its pid, created
after the process started): `EmbeddingGemma2.removeOwnMPSGraphTempFiles()`, `remove_own_mpsgraph_temp_files()`,
or `--cleanup-temp` on every CLI command. Call it after the model has been released, or at exit. Folders of other
processes are never touched; a leftover from a crashed run has to be removed by hand (the name carries pid and date).

## Limits and known issues

- **Very small images upscaled a lot** (a 10–16 px image becomes 768×768, every patch a smooth gradient) are the
  least precise case on the Neural Engine. Since 1.1 the graph takes exact integer pixels (the input rounding that
  cost such images up to 0.004 is gone). On the GPU image route the worst image is 0.9989 with text on the Neural
  Engine (`imageCompute: .gpu`; 30 targeted tiny images ≥ 0.99975) and 0.99975 with text on the GPU too (`compute:
  .gpu`). On the Neural Engine its own float16 arithmetic remains: worst image 0.9946 (a 16×16 image), 30 targeted
  tiny images 0.9958–0.99999 (median 0.99993), every other validation image ≥ 0.9997. Retrieval is unaffected. If
  you index many icons or thumbnails of ≤ 16 px and want the closest match to the reference, put the images on the
  GPU: `imageCompute: .gpu` (worst 0.9989) or, closest, `compute: .gpu` (worst 0.99975).
- **JPEG decoding in Swift** differs from libjpeg (above): photos ≥ 0.998, chroma-subsampled synthetic charts
  down to 0.982; lossless formats are exact. This is the same on every compute route.
- **CPU-only route** (`compute: .cpu` / `imageCompute: .cpu`): fine on ordinary images (median 0.99993, captioned
  ≥ 0.9993) and texts (≥ 0.9991) but the least precise route (tiny upscaled images down to 0.946) and the slowest;
  use the Neural Engine or the GPU.
- **One image budget.** Only the default 280-soft-token budget (2520 patches) is exported. The upstream processor
  also supports 70, 140 (video frames), 560 and 1120; those need other static shapes (`export/eg2_vision.py`:
  `MAX_SOFT`), and 1120 is probably GPU-only.
- **File formats**: the reference reads only JPEG, PNG, WebP and GIF from a path. The runners also read BMP and
  TIFF (Swift: also HEIC and anything else ImageIO decodes); there is no upstream vector to compare those with.
  16-bit images: upstream divides the 16-bit samples by 255 (garbage); the runners take the high byte, on purpose.
  Premultiplied-alpha CGImages cannot be un-premultiplied exactly; exotic pixel formats (float, Lab, …) fall back
  to a colour-managed Core Graphics draw over black.
- **2048-token cap** for text (longer input is truncated); buckets of 4096/8192 can be exported but were not
  validated and would run on the GPU.
- **Audio: 30 s window.** Like upstream, one call embeds at most 30 s; longer audio is truncated by default or
  averaged over 30 s windows (`chunk_mean`, our extension, not an upstream vector). Fewer than 161 samples (10 ms)
  give zero audio tokens and the embedding of an empty audio sequence (upstream crashes below 129 samples).
- **Audio: MP3 and Ogg decoding** with Apple's decoder (Swift and the Python `afconvert` fallback): tagged MP3s
  match the reference decoder within ~3e-5 per sample after the gapless trim; inaudible, but digitally silent
  passages amplify it in the log-mel floor: clips with long digital silence (synthesized speech with pauses,
  synthesized sounds with silent decays) score 0.990–0.9999 against the reference, other MP3s ≥ 0.99998. MP3 files
  without a LAME/Xing tag are 529 samples off the reference (cosine 0.92–0.993); Ogg Vorbis 128 samples (0.990–
  0.9985). The Python runner with `soundfile` (the default install) is exact; in Swift, decode these formats
  yourself when that matters.
- **Audio: resampling** uses the package's sinc instead of libsoxr: ≤ 0.00012 of cosine on speech, up to 0.006 on
  synthesized sounds whose upper bands sit at the log-mel floor. 16 kHz input is exact.
- **Audio on the Neural Engine**: near-silence (digital silence, a 30 kHz tone resampled to nothing, speech at
  −90 dBFS) and dense synthesized chords are the least precise inputs (0.997–0.9993); speech ≥ 0.9983. The GPU
  route is ≥ 0.9994 on everything. Only the shipped frame buckets are supported (see "Audio: `audio_<Tb>`"), and
  the CPU route is not supported for audio, so the runners refuse it.
- **Audio sample arrays**: Python `embed_audio(array, sample_rate)` takes `[n]` or `[n, channels]` and rejects a
  channel-first `[channels, n]` array (librosa / torchaudio layout: pass `array.T`); Swift
  `embedAudio(samples:sampleRate:)` takes channel-major `samples[channel][frame]` and rejects frame-major arrays,
  channels of different lengths and a non-positive rate (before 1.2's validation pass, these were silently embedded
  as near-empty audio or crashed).
- **Audio asset memory**: ~1.4 GB on the Neural Engine for the five functions (the runtime does not share the
  weights between them on the Neural Engine); on the GPU route ~300 MB of process memory instead.
- **An interrupted first load** (the process is killed while the runtime specializes an asset) can leave the
  per-app cache entry unusable, so later loads of that asset fail in `loadFunction`. Delete
  `~/Library/Caches/coreai-cache/<OS build>/<app>/<asset hash>/` and reload (one more first-load specialization).
- **Batch 1.** Concurrency did not increase throughput (the Neural Engine serializes). Short texts are not faster
  than ~4.8 ms (per-call floor in our measurements).
- **Latency is not shape-stable across bucket sets**: Core AI specializes the whole function set together; measure
  the exact set you ship.
- **Specialization cache is per app** (executable name or bundle identifier); **temp files** as described above;
  **fp16 output** (relative precision ~5e-4; convert to float32 before accumulating dot products, as the runners do).
- Validated on one machine (macOS 27). Core AI is new in macOS 27 and its runtime
  behaviour (first-load time, placement, temp files) may change between OS releases.

## Reproducing the export

```
# a separate environment with Python 3.12 (torch 2.9.0); exact versions in python/requirements.lock
python3.12 -m venv .venv-export && source .venv-export/bin/activate
pip install coreai-core==1.0.0b3 torch==2.9.0 coreai-torch==0.4.3 coreai-opt==0.3.0 torchao==0.17.0 \
    safetensors numpy pillow tokenizers huggingface-hub
hf download google/embeddinggemma-2 --local-dir ./embeddinggemma-2
cd export
python3 -W ignore export.py --model-dir ../embeddinggemma-2 --out ../model-rebuilt \
    --buckets 32,64,128,288,512,1024,2048 --qchunks 12 --audio-buckets 192,384,1024,1536,3000 --date 2026-10-12
```

About 40 s on an M5 (`--part text|vision|audio` rebuilds one asset). `eg2_text.py` is the re-authored text encoder
(byte-identical to 1.0), `eg2_text_mm.py` adds the soft-token mix, `eg2_vision.py` is the re-authored image
encoder, `eg2_audio.py` the re-authored audio encoder; `export.py` does one `torch.export` per asset, converts with
`coreai_torch.TorchConverter`, clones the text and audio entry points per bucket with `set_static_shape_config`
and writes the bundle. torchao must be 0.17.0 with torch 2.9 (0.18 breaks `import coreai_opt`).

A rebuilt bundle is **functionally identical, not byte-identical**: the converter names internal graph resources at
random (`main.mlirb` / `main.hash` differ by a few bytes) and the runtime writes `metadata.json` with the export
time. `config.json`, `MODEL-ATTRIBUTION.json` and the tokenizer files come out byte-identical. Verify a rebuild
with `smoke`, not with checksums; a rebuilt asset has a new content hash, so its first load takes the full time.

Neural Engine eligibility without running: `xcrun coreai-build compile model/<asset>.aimodel --output ./compiled
--preferred-compute neural-engine --architecture h17g 2>&1 | grep -c ane_validation_message` prints 0 for the
text and image assets (no op rejected; delete `./compiled` afterwards). The specialized text and image graphs have
one Neural Engine region and one GPU region (the token / position-table gather) per function; each audio function
is a single Neural Engine region. For the audio asset this offline check is not sufficient: verify placement with
the process's Neural Engine footprint (`eg2-cli latency` prints it) and correctness with `smoke`.

## Credits and license

- Model: EmbeddingGemma 2 by the Gemma Team, Google DeepMind — Apache-2.0. Deployments must adhere to the
  [Gemma Prohibited Use Policy](https://ai.google.dev/gemma/prohibited_use_policy).
- Architecture, image-processor and audio-feature-extractor reference: Hugging Face transformers (Apache-2.0).
  Resize arithmetic: ported from the logic of ATen's uint8 antialiased bicubic kernel (PyTorch, BSD-3-Clause),
  itself modelled on Pillow's resampling; CMYK conversion ported from Pillow's formula (MIT-CMU). Their license
  notices are in NOTICE. The audio resampler is the package's own design (upstream uses libsoxr, not included).
- The max-abs RMSNorm rescaling idea comes from the FluidInference Core ML port of this model (Apache-2.0); no code
  was copied.
- Port, exporter, runners, Swift tokenizer implementation, preprocessing and audio front end, tests, test images
  and test audio: Copyright 2026 Everpaper, Apache-2.0.
- Gemma and EmbeddingGemma are trademarks of Google LLC; Apple, Core AI, Apple silicon and Neural Engine are
  trademarks of Apple Inc. This port is not affiliated with, sponsored by or endorsed by Google or Apple.
