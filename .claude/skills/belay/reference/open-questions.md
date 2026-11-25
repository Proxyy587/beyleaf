# Open questions (UNVERIFIED until checked)

Check these before building on them. When you resolve one, move it to the "Resolved" list with the evidence and date, and update the doc that depended on it.

## Day 1 (v0.1)
- [ ] Bun can serve HTTP and WebSocket on a Unix socket inside a `bun build --compile` binary (ADR 0006). Fallback: localhost plus a per-launch token.
- [ ] A Claude Code `command` hook holds `PermissionRequest` while the shim waits (Perch uses a 3600 s timeout).
- [ ] Codex `PermissionRequest` hold time (Perch registers it with **5 s**).
- [ ] Bun binary size and idle memory versus the budgets in `docs/tech-stack.md` §4.
- [ ] Whether `PermissionRequest` fires for headless `claude -p` runs (needed by `e2e/`).
- [ ] Haptic pattern range on Force Touch trackpads (`NSHapticFeedbackManager`).

## Before v0.2 (Hands / Crew)
- [ ] Claude Code non-interactive flags: streaming JSON output, per-run MCP config, session resume.
- [ ] Codex exec / app-server JSON events; per-server MCP environment for the capability token.
- [ ] Anthropic Commercial Terms for **launching** the user's own Claude Code from Belay (`docs/oss-reuse.md` §2).
- [ ] Whether engines report plan usage (for the usage guard).
- [ ] Apple Foundation Models quality for one-line summaries (macOS 26).
- [ ] Spotify AppleScript reliability on the current Spotify build.

## Convert (v0.2)
- [ ] Finder right-click: Services vs App Intent Quick Action vs Action extension (macOS 14–26)
- [ ] `WKWebView.createPDF` quality for long HTML/DOCX documents
- [ ] Wasm libwebp/libjxl encoders: size, speed, build licence
- [ ] Actual licences of Homebrew FFmpeg, ImageMagick, LibreOffice, Ghostscript (shown in Settings)
- [ ] Finder selection via AppleScript: Automation permission UX

## Product and admin
- [ ] "Belay" name and handle availability (GitHub, X, domain).
- [ ] Apple Developer Program enrolment, for signing and notarization.

## Resolved
- (none yet)

- **Clock CPU (UNVERIFIED, 2026-11-26):** debug build with the notch open and music playing sampled 13–14% (0.4% after close). Not attributed to the Clock; measure a release build with only the Clock on Now (budget ≤ 0.3% idle).
