# 0012: Converters are built-in first; ship only permissive code; detect GPL-family tools

- **Status:** accepted (2026-11-24)
- **Context:**
  - Belay Convert (`docs/conversions.md`) needs broad format coverage. A smoke test on 2026-11-24 showed macOS built-ins (`sips`, `textutil`, `afconvert`, `avconvert`, `cupsfilter`) cover most image, document, audio and video conversions. They can't write WebP or MP3, or do Markdown or HTML→PDF.
  - The best-known general converters carry copyleft or unclear licences per GitHub metadata: pandoc GPL-2.0, LibreOffice/core GPL-3.0 as detected, libvips LGPL-2.1; FFmpeg, ImageMagick and Ghostscript are not detectable.
  - Belay is MIT and bundles no GPL code (ADR 0003).
- **Decision:**
  1. Prefer macOS built-in tools and native frameworks (PDFKit, WebKit, Vision, ImageIO).
  2. Bundle only MIT/BSD/Apache-2.0 converter libraries (e.g. turndown, mammoth, pdf-lib, an MIT Markdown parser), credited in `THIRD_PARTY_NOTICES.md`.
  3. GPL/LGPL/AGPL or unclear-licence tools (pandoc, ffmpeg, LibreOffice, Ghostscript, libvips, ImageMagick) are **never bundled or auto-installed**. If the user already has them, Belay detects them at absolute Homebrew/system paths and runs them as separate programs. Settings shows the tool, path, version and licence, and a copyable install command.
  4. Routes are labelled lossless, lossy or best-effort. Lossy steps warn first. Originals are never overwritten.
- **Consequences:**
  - Out of the box, some targets (mp3, webm, epub, office-to-pdf with full fidelity) show greyed out with "install X to unlock".
  - A permissive Wasm WebP/JXL encoder can be added later to close the most common gap, after its size, speed and build licence are verified.
