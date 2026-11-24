# Belay Convert: file conversion spec

**Status:** design, planned for v0.2 (core) and v0.3 (extended). Not part of the 2-week v0.1.
**Written:** 2026-11-24.
**Decision:** ADR 0012 (built-ins first; bundle only permissive libraries; GPL-family tools detected, never shipped).

> **In one line:** drop any file on the notch, right-click it in Finder, or just say "make these PNGs". A conversion wheel offers the formats that make sense, and Belay converts it locally, for free, in seconds. Nothing is uploaded.

---

## 1. What we measured (2026-11-24, on the dev Mac)

A smoke test of real conversions with tools that ship with macOS (plus two Homebrew tools that happened to be installed):

| Conversion | Tool | Result |
|---|---|---|
| png → jpeg / heic / avif / pdf | `sips` (ImageIO) | ✅ |
| png → webp | `sips` | ❌ ImageIO **reads** WebP and JPEG XL but can't **write** them (`sips --formats`: no "Writable") |
| png → webp | `cwebp` (Homebrew, libwebp BSD-3) | ✅ |
| txt → docx, docx → html, docx → txt | `textutil` | ✅ (textutil formats: txt, rtf, rtfd, html, doc, docx, odt, wordml, webarchive) |
| txt → pdf | `cupsfilter` | ✅ |
| html → pdf | `cupsfilter` | ❌ produced an empty file |
| md → anything | `textutil` | ❌ no Markdown support |
| aiff → m4a (AAC) | `afconvert` | ✅ |
| aiff → mp3 | `afconvert` | ❌ no MP3 encoder |
| aiff → mp3 | `ffmpeg` (Homebrew) | ✅ |

**Also built in, not yet exercised:**
- `avconvert`: video re-encode by preset. It strips privacy-sensitive metadata by default.
- `qlmanage`: thumbnails and previews.
- Native Swift frameworks:
  - **PDFKit**: PDF pages to images, text extraction, merge and split.
  - **WebKit** `WKWebView.createPDF`: HTML to PDF.
  - **Vision**: OCR text from images and scans.
  - **ImageIO / Core Image**: image transforms.
- Using any of these from Belay is **UNVERIFIED** until prototyped.

**Licences** (GitHub licence metadata, read 2026-11-24):

| Licence | Projects |
|---|---|
| MIT | markitdown (Microsoft), turndown, pdf-lib |
| BSD-2-Clause | mammoth.js |
| BSD-3-Clause | libwebp, libjxl |
| Apache-2.0 | pdf.js, sharp |
| LGPL-2.1 | libvips |
| GPL-2.0 | **pandoc** |
| GPL-3.0 | **LibreOffice/core** (as GitHub detects it; LibreOffice's own licensing is **UNVERIFIED** here) |
| NOASSERTION (not detectable) | FFmpeg (LGPL or GPL depending on the build: **UNVERIFIED**), ImageMagick (its own licence: **UNVERIFIED**), Ghostscript (**UNVERIFIED**), marked |

## 2. Principles

1. **Local, free, private.** Convert on the Mac. No upload, no account. Metadata stripping is on by default for media (GPS/EXIF), with a toggle.
2. **Built-ins first.** Prefer what ships with macOS (`sips`, `textutil`, `afconvert`, `avconvert`, PDFKit, WebKit, Vision). They're fast, signed by Apple, and add zero download size.
3. **Bundle only permissive code.** MIT, BSD or Apache JS/Wasm libraries can ship inside Belay. **GPL/LGPL/AGPL tools (pandoc, ffmpeg builds, LibreOffice, Ghostscript, libvips) are never bundled.** If the user already has them installed, Belay **detects and uses them** as separate programs, and says so (ADR 0012).
4. **Honest about quality.** Every route is labelled lossless, lossy or best-effort (e.g. PDF → DOCX loses layout). Belay warns before a lossy conversion.
5. **Never destroy the original.** Output goes next to the source as `name.ext` (or `name (1).ext`). The original is never overwritten. Undo moves the output to the Trash.
6. **Never execute content.** Converters run as child processes in their own process group, inside a temp work dir, with time and size limits. Macros and scripts in documents are never run.

## 3. How you use it (entry points)

| Entry point | Interaction | Phase |
|---|---|---|
| **Drop on the notch** ★ | Drag a file or files toward the notch. It opens into a **conversion wheel**: 4–6 most-likely targets for that type as segments (e.g. a HEIC shows JPG · PNG · PDF · WebP · smaller). Move onto a segment (a haptic detent as you cross each one), release to convert. Hold ⌥ while hovering for "More…" (the full list) and options (quality, size, strip metadata). | v0.2 |
| **Finder right-click** | Right-click a file → **Quick Actions / Services → "Convert with Belay…"**. The wheel appears at the cursor, or a submenu offers the top targets. Implementation path (Services via `NSServices`, an App Intent shown as a Quick Action, or an Action extension) is **UNVERIFIED** and gets a 1-day spike. | v0.2 |
| **Voice** | "Convert these to PNG", "make this PDF a Word doc", "shrink this video for WhatsApp". "These" means the current Finder selection, read through Finder's AppleScript dictionary (needs an Automation permission prompt). | v0.2 |
| **Hotkey** | A global shortcut on a Finder selection opens the wheel at the cursor | v0.2 |
| **Crew (Porter)** | Porter owns conversions: `convert.plan` / `convert.run` tools (`docs/crew.md` §6). Lead can ask Porter ("export the diagram as PNG"). | v0.2 |
| **Clipboard** | A copied image can be pasted as another format ("paste as PNG") | v0.3 |
| **Watch folders** | "Always turn HEIC in ~/Downloads into JPG". Runs only while the Mac is awake. | v0.3 |
| **Shortcuts app** | A "Convert File" App Intent for automations (E7) | v0.3 |

**Wheel design:**
- Segments are ordered by what *you* pick most for that source type (learned locally), then by common sense.
- The centre shows the file icon and the count.
- On release, the notch shows progress as a rope being pulled up. Done plays the summit chime and a haptic, and Reveal/Undo appear.
- Batch drops convert in parallel, up to the CPU count.

## 4. Architecture

Following ADR 0001: **TypeScript decides, Swift touches macOS.**

```
Drop / right-click / voice / Porter
        │  (shell: file URLs, UTIs, drop location)
        ▼
belayd ConvertService
  ├─ FormatRegistry   UTI ⇄ extension ⇄ family (image, doc, pdf, audio, video, data, archive, ebook)
  ├─ RouteGraph       nodes = formats, edges = converter capabilities {cost, lossy, needs}
  ├─ Planner          cheapest valid path (Dijkstra); prefers lossless; never uses a missing provider
  ├─ Providers        builtin-cli · native (via shell) · bundled-js · detected-external
  ├─ Runner           temp work dir · own process group · timeouts · size caps · progress events
  └─ Output policy    name next to source · never overwrite · strip metadata · undo
        │                                    │
        ▼ child processes                    ▼ convert.native.* requests over protocol v1
 sips · textutil · afconvert · avconvert     Swift shell: PDFKit · WebKit createPDF · Vision OCR · ImageIO
 cupsfilter · bundled JS (marked, turndown, mammoth, pdf-lib)
 detected: cwebp · ffmpeg · pandoc · LibreOffice (if the user installed them)
```

**Multi-hop routes.** Many conversions chain through a **pivot format**:

| Pivot | Example routes |
|---|---|
| HTML | `md → html (marked) → docx (textutil)`; `docx → html (textutil) → md (turndown)`; `docx → html → pdf (WebKit)` |
| PNG/TIFF | `heic → png → webp (cwebp)`; `pdf page → png (PDFKit) → jpeg (sips)` |
| WAV/CAF | `m4a → caf (afconvert) → flac (afconvert)` |
| Plain text | `pdf → txt (PDFKit)`; `image → txt (Vision OCR)` |

The Planner picks the cheapest path. If two paths exist, it prefers fewer lossy steps.

**Providers**

| Kind | Examples | Shipped in Belay? |
|---|---|---|
| `builtin-cli` | `sips`, `textutil`, `afconvert`, `avconvert`, `cupsfilter`, `ditto`/`zip` | No (part of macOS) |
| `native` (shell side) | PDFKit, WebKit, Vision, ImageIO, Core Image | No (part of macOS) |
| `bundled-js` | marked or another MIT Markdown parser, turndown (MIT), mammoth (BSD-2), pdf-lib (MIT); pdf.js (Apache-2.0) if PDFKit falls short | **Yes**, permissive only, recorded in `THIRD_PARTY_NOTICES.md` |
| `detected-external` | `cwebp`/libwebp (BSD-3), `ffmpeg`, `pandoc`, LibreOffice `soffice`, ImageMagick | **No.** Used only if the user has them installed. Settings shows "Unlock more formats: install X with Homebrew", with the command, never auto-installed. |

**Protocol additions (v1, additive):**
- `convert.offer {files, targets[]}` (core → shell, populates the wheel)
- `convert.request {files, target, options}` (shell → core)
- `convert.progress {jobId, pct}`
- `convert.done {jobId, outputs[], warnings[]}`
- `convert.native.* {op, in, out, opts}` (core asks the shell to run a native framework step)

## 5. Format coverage

✅ means built-in or bundled (works out of the box). 🔌 means it needs a detected external tool. ⚠️ means it works but is lossy or best-effort.

### Images
| From → To | Route |
|---|---|
| HEIC, JPEG, PNG, TIFF, GIF, BMP, PSD (read), RAW camera formats (read), AVIF, JP2, ICO/ICNS ↔ PNG / JPEG / HEIC / AVIF / TIFF / GIF / BMP / ICO / ICNS / JP2 / PDF | ✅ ImageIO (`sips` or native). The writable set is as measured in §1. |
| any image → **WebP** | 🔌 `cwebp`. Alternatively bundle a permissive Wasm encoder (libwebp is BSD-3) so it works out of the box; size and performance are **UNVERIFIED**. |
| WebP / JPEG XL → PNG / JPEG | ✅ ImageIO reads them |
| any image → **JPEG XL** | 🔌 or a bundled libjxl (BSD-3) build. **UNVERIFIED** |
| SVG → PNG / PDF | ✅ WebKit render (native). **UNVERIFIED** |
| image → text (OCR) | ✅ Vision (native). v0.3 |
| resize, compress, strip metadata | ✅ ImageIO / Core Image |

### Documents and text
| From → To | Route |
|---|---|
| txt ↔ rtf ↔ html ↔ doc ↔ docx ↔ odt (+ rtfd, webarchive) | ✅ `textutil` |
| md → html | ✅ bundled Markdown parser |
| md → docx / rtf / odt | ✅ md → html → `textutil` |
| md → pdf | ✅ md → html → WebKit PDF |
| html / docx / rtf → **md** | ✅ → html → turndown (⚠️ complex layout simplified) |
| docx → md with better structure | ✅ mammoth (BSD-2) → html → turndown |
| html / docx / txt → pdf | ✅ WebKit PDF (txt also via `cupsfilter`) |
| epub, LaTeX, reStructuredText, org, etc. | 🔌 pandoc, if installed |
| xlsx / pptx / key / pages / numbers → pdf | 🔌 LibreOffice, if installed (⚠️). Apple's iWork apps can export via AppleScript if installed (**UNVERIFIED**). |
| csv ↔ json ↔ tsv ↔ yaml ↔ xml (data) | ✅ bundled TS (no external tools) |

### PDF
| From → To | Route |
|---|---|
| pdf → png / jpeg (per page) | ✅ PDFKit render |
| pdf → txt | ✅ PDFKit text (⚠️ layout lost); scanned PDFs need OCR via Vision (v0.3) |
| pdf → md / html | ✅ text + structure heuristics (⚠️ best-effort) |
| pdf → docx | ⚠️ text and images only, through html → `textutil`. Faithful layout needs LibreOffice (🔌). Belay says so before converting. |
| images → pdf, merge, split, rotate, compress | ✅ PDFKit / pdf-lib |

### Audio
| From → To | Route |
|---|---|
| wav, aiff, caf, m4a/aac, alac, flac, mp3 (read) ↔ wav / aiff / caf / m4a / alac / flac | ✅ `afconvert` (CoreAudio) |
| → **mp3**, ogg/opus | 🔌 `ffmpeg` |
| text → speech audio | ✅ `say -o` (bonus) |

### Video
| From → To | Route |
|---|---|
| mov / mp4 / m4v (H.264, HEVC) → mp4 / mov by preset (720p, 1080p, 4K, HEVC, "smaller") | ✅ `avconvert` |
| → webm / mkv / avi / animated GIF, trims, audio extraction to mp3 | 🔌 `ffmpeg` |
| video → audio (m4a) | ✅ AVFoundation export (native). **UNVERIFIED** |

### Archives
| From → To | Route |
|---|---|
| folder/files → zip, zip → files | ✅ `ditto` / `zip` / `unzip` |
| 7z / rar / tar.zst | 🔌 if `7zz` or `unar` is installed |

**"Anything to anything" is not literally possible.** Some pairs only make sense through a lossy middle step (video → pdf, mp3 → docx), and Belay doesn't offer those. The wheel only shows targets with a valid route. The "More…" list shows 🔌 targets greyed out, with the one tool that would unlock them.

## 6. Safety and performance

- Inputs are read-only. Work happens in `~/Library/Caches/Belay/convert/<job>/`, which is cleaned after the job.
- Per-job limits: 2 GB input, 10 min CPU (video 60 min), output size sanity checks.
- Child processes run in their own process group (vendored `group-exec.ts`), so cancelling kills everything.
- Documents are converted with macros and scripting disabled. PDFs are never "opened" with JavaScript.
- The external tools Belay detects are listed in Settings with their path and version. Belay only runs binaries found at absolute paths under `/opt/homebrew`, `/usr/local` or `/usr`.
- The Logbook records conversions (types, sizes, duration), not file contents.

## 7. Phasing

| Phase | Scope |
|---|---|
| **v0.2** | ConvertService, Planner and Runner; built-in providers. Bundled MIT/BSD JS: Markdown, turndown, mammoth, pdf-lib, plus data formats. Native: PDFKit render/text, WebKit html→pdf. **Drop-on-notch wheel**, Finder right-click, voice, hotkey, Porter tools. Images, documents, PDF, audio (no mp3), video presets, zip. |
| **v0.3** | Detected externals (cwebp, ffmpeg, pandoc, LibreOffice, 7zz). Vision OCR. Clipboard paste-as. Watch folders. Shortcuts App Intent. Learned wheel ordering. Possibly a bundled WebP/JXL Wasm encoder. |

## 8. Open questions (also in `.claude/skills/belay/reference/open-questions.md`)

1. Finder right-click integration: Services vs App Intent Quick Action vs Action extension. Which shows up reliably in the context menu on macOS 14–26?
2. `WKWebView.createPDF` quality for long HTML/DOCX documents (pagination, page size).
3. Wasm builds of libwebp/libjxl: size, speed and licence of the build.
4. The real licences of FFmpeg builds (Homebrew's), ImageMagick, LibreOffice and Ghostscript. They're only *detected*, never shipped, but Settings should state them correctly.
5. Reading the Finder selection by AppleScript: the Automation permission prompt and failure UX.
