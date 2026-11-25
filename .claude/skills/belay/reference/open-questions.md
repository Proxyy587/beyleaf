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
- **Notes by hand (UNVERIFIED, 2026-11-26):** pressing ⌃⌥N and the panel becoming key with the field focused; typing and Return in the field; hover Copy, Delete and Undo; Esc clearing then closing; keystrokes returning to the previous app after close. Registration (no prompt) and the save path to disk were checked; real key events were not sent.
- **Weather by hand (UNVERIFIED, 2026-11-26):** the Settings city search UI and its debounce, Retry, the OFFLINE and 3 h gone states, units switching, and the Open-Meteo link opening. Checked live: real geocoding and forecast fetch, parse, render (wide, with rain hint) and the ready state; the pure logic has fixture tests. Open-Meteo's terms (free for non-commercial, no ads or subscriptions) were read 2026-11-25; revisit if Belay ever charges.
- **Calendar by hand (UNVERIFIED, 2026-11-26):** the live permission flow (prompt text, grant, deny, write-only), real events from Calendar.app, `EKEventStoreChanged` reloads, the midnight reload, and the Join button opening a call. Checked with `--calendar-demo` only: card layout, Join glyph, the closed-notch wing; pure logic has self-tests. The agent cannot click the system prompt.
- **UNVERIFIED (2026-11-26, ADR 0023):** tap-to-cycle size and drag-to-reorder in edit mode with a real pointer; a real two-finger trackpad swipe (only synthetic phased scroll events and window captures were used; the screen was locked); that the notch stays open through real scrolling, typing in Notes and dragging; the look of expanded (3 columns) beside default wide widgets, which leave a free column until small widgets are placed.
