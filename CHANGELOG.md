# Changelog

All notable changes to Belay are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/) once code ships. Update `[Unreleased]` in the same commit as the change.

## [Unreleased]

### Added
- **Research:** competitive landscape, evidence of pain, technical feasibility, verdict, market growth (`docs/`).
- **Product:** concept and hero moment, full ecosystem spec, locked v0.1/v0.2/v0.3 feature list, 2-week build plan, launch plan.
- **Engineering:** tech stack, architecture, open-source reuse and AI-subscription rules.
- **Decisions:** ADRs 0001–0007 (`docs/decisions/`).
- **Reference repos:** pinned in `refs.lock`; `scripts/fetch-refs.sh` recreates `refs/`.
- **Vendoring:** `scripts/vendor.sh`, with a licence gate, pinned-commit check and SHA-256 provenance.
- **Vendored (verbatim, in `third_party/`):**
  - Perch (MIT): hook server and installer, terminals, notch geometry, live status, notch state machine.
  - Clicky (MIT): push-to-talk monitor, on-device speech provider, overlay window.
  - Avo (MIT): Spotify control, dictation waveform.
  - OpenMausBot (Apache-2.0): secret redaction.
- **Licensing:** `THIRD_PARTY_NOTICES.md`, MIT `LICENSE`.
- **Agent context:** `AGENTS.md`, `CLAUDE.md`; `CONTRIBUTING.md`.
- **Skeleton:** monorepo folders (`apps/mac`, `apps/web`, `core/packages/*`, `rules/`, `e2e/`), each with a README mapping it to features and vendored sources; root Bun workspace manifest.

- **Decisions:** ADR 0008 (source-available projects such as dusk bot are inspiration only) and ADRs 0009–0011 (Crew hub and tool surface, runtimes and turns, taint tracking).
- **Crew spec:** `docs/crew.md`, the engineering design for Belay's sub-agents (Belay, Lead, Porter, Tempo, Scout, Sketch). Folded into `features.md` (section K), `features-final.md` (v0.2/v0.3), `architecture.md` (CrewService) and `AGENTS.md` (rules 8–9).
- **Vendored:** OpenMausBot `server/group-exec.ts` (Apache-2.0), process-group stop for crew members.

- **Claude Code skill:** `.claude/skills/belay/`, a project skill with rules, live repo state, playbooks (commit, feature work, vendoring, decisions, crew), references (docs map, glossary, open questions) and `scripts/verify-repo.sh` (licence, provenance, ADR-index, changelog and credential-path checks).

- **Convert spec:** folded into `features.md` (section L), `features-final.md` (v0.2: L1–L5; v0.3: L6–L9), `architecture.md` (ConvertService), `crew.md` (Porter's `convert` tools) and the skill's references.
- **Convert spec:** `docs/conversions.md`, local file conversion (drop-on-notch wheel, Finder right-click, voice, Porter) across images, documents, PDF, audio, video and archives, grounded in a smoke test of the macOS built-in converters.

- **Decision:** ADR 0012 (converters: built-ins first, permissive bundles only, GPL-family tools detected, never shipped).

- **Decisions:** ADR 0013 (SwiftPM + bundle script instead of XcodeGen) and ADR 0014 (own notch window; supersedes 0007).

- **Mac app v0.0 prototype** (`apps/mac`): our own notch panel and spring-animated notch shape with hover open/close and haptics; compact wings (climber, battery or equalizer); open panel with clock, Music/Spotify now playing and controls, Wi-Fi, battery, volume and a Convert drop-zone placeholder. Builds with SwiftPM and the Command Line Tools; idle CPU measured at 0.0%.

- **Vendored:** OpenMausBot `DESIGN.md` (Apache-2.0), the upstream design rules behind the dusk bot look; basis for Belay's own design rules.

- **Design rules:** `docs/design.md` (adapted from OpenMausBot's Apache-2.0 design rules; feel references from Aria's and dusk bot's public sites) and the `belay-design` Claude skill with an anti-slop review gate.

- **Features:** M (launcher and clipboard, competing with Raycast), N (screenshot auto-copy and peek), O (settings and appearance), added to `features.md` and `features-final.md`.

- **Mac app:** notch redesigned to `docs/design.md` (tokens, Aria-style rows, no plates or gradients); **screenshot auto-copy** (N1); **Settings window** (O1: general, appearance, screenshots, AI-account detection, about).

- **Themes (ADR 0015):** every visual token comes from a user theme. Fonts (any installed), text size, status style, colours, solid or glass surface, roundness, width, density, row order and visibility, and motion speed, blur and bounce. Four presets; save, export and import as JSON; live preview while Settings is open. Subtle blur reveals and blur swaps.

- **Open and close delays:** Settings → General has two sliders, 0–1 s, both instant by default. Replaces the fixed 0.35 s close delay and the open-delay presets.

- **Exact-fit closed notch (default):** the closed shape is exactly the hardware notch (measured: 208 × 37 pt, x 856–1064 on a MacBook Air display), with no side wings or top flares. A live activity (screenshot copied) briefly widens it, then it snaps back. "With info beside" in Settings → Layout restores the climber, battery, time and equalizer wings. The canvas is larger so wide or tall themes and their shadow never clip.

- **Live activities (Dynamic Island style):** while music plays, the closed notch widens with album art and live bars (keep, brief or off). Short alerts for screenshot copied, charging, low battery and Wi-Fi online/offline. A jelly spring and blur swap on each new activity or track.
- **Open panel:** the header moves into the band beside the camera; Now playing becomes a hero card with real album art (Music via AppleScript, Spotify artwork URL), a seekable progress bar with elapsed/remaining time, and centred controls.

- **Prerequisites:** `docs/prerequisites.md`, a checklist of what only the human can do (installs, permissions, Apple Developer Program, naming, legal questions, broker accounts, launch accounts).

- **Trading agent design:** `docs/trading.md` and ADR 0016. Non-custodial, the model only proposes, deterministic risk engine, rope-card approvals, paper first, kill switch. Blocked on legal review.

- **Features P and Q:** live activities and system HUD (inspired by DynamicNotch, Boring Notch and NotchNook: ideas only, no GPL code) and the trading agent, added to `features.md`; `features-final.md` gains a "Built so far" table and P/Q phasing. `mediaremote-adapter` (BSD-3) pinned in `refs.lock` for any-app now playing.

- **Product-designer agent:** `.claude/agents/product-designer.md`, a reusable subagent that owns UI/UX polish and Claude Code skills setup.

- **Fixed:** opening the notch could launch Spotify (or Music). `tell application` starts an app that isn't running, and the position, artwork, seek and controls calls used the last-known player without checking. All player AppleScript now goes through one guard (checked in Swift and inside the script), and a player is forgotten the moment it quits.

### Changed
- **Haptics:** only the hover-open tick remains. Buttons, chips, switches, screenshot copies and timer endings no longer buzz; with the trackpad's own click they felt like a double tap.
- **Settings → Widgets:** a native list to drag widgets into order and switch them on or off (replaces the Rows section in Layout). Live activities gain a Timer switch. The preview shows the new panel.
- **Notch redesign:** the open panel is now widgets on tonal cards: Now playing (title, artist, progress and controls in one compact card), a new **Timer** (presets 5/15/25/50 min, ring + countdown, pause/stop, "Done" flash in the closed notch) and Last screenshot. The band beside the camera holds the brand slot (left) and Edit widgets + Settings (right). Edit widgets in the notch: reorder with ↑/↓, switch widgets on or off, right-click a card to move or hide it. "Not playing" and empty placeholder lines are gone; a widget with nothing to show takes no space.
- **Logo:** the Belay mark is now the belayer — soft head, cutout eyes, rope chin (`brand/`). Live state lights green pupils instead of the old notch-and-point. Menu bar template, `BelayMark` shape, About pane and `AppIcon.icns` all use the new geometry.
- **ADR 0019 + `docs/notch-widgets.md`:** the open notch becomes user-ordered widgets (Now playing, Timer, Last screenshot) packed with no gaps; widget order moves out of the theme.
- **Workflow:** every major update gets its own `<type>/<topic>` branch, merged into `main` with `--no-ff` (AGENTS.md).
- **Skills:** `dusk-feel` (ours) captures the dusk bot look the owner wants: surfaces, pills, radii, motion with SwiftUI curves, copy, and its audit method. Written from our study, with no dusk text or code (ADR 0018).
- **Skills:** `dxe-apple-native-ui` (kemiljk, MIT) for native macOS behaviour and accessibility reviews.
- **Skills:** Hallmark removed at the owner's request; `frontend-design` (Anthropic, Apache-2.0) is back, unchanged at e4bb5d9.
- **Design skills:** `belay-design` records what unfair.so, dusk bot and Aria share, in our own words. `swiftui-macos` gains Liquid Glass rules: macOS 26 APIs gated, the notch stays black, Reduce Transparency honoured.
- **Skills:** `agent-browser` (Vercel Labs, Apache-2.0) so agents can screenshot and inspect reference sites and, later, our website.
- **Skills:** `improve-codebase-architecture` and `codebase-design` (Matt Pocock, MIT) for on-demand architecture reviews. Our three edits are listed in their `SOURCE.md`.
- **Skills:** the Hallmark design plugin (MIT) replaces `frontend-design`, installed at project scope in `.claude/settings.json`. It covers web pages only; the notch follows `docs/design.md`.
- **ADR 0018** (amends 0008): dusk bot may be cloned to the git-ignored `refs/duskbot` for design study only. Never in `refs.lock`, never vendored or adapted, and what we learn is written in our own words. AGENTS.md rule 9 is updated to match.
- Hook transport moved from localhost HTTP hooks with tokens to command hooks plus a 0600 Unix socket (ADR 0006, learned from Perch).
- **Notch header:** no brand text. The open notch's header is just the time (left of the camera) and the Settings gear (right); the climber and the "Belay" title are gone.
- **Calm defaults:** a new theme shows now playing (the hero when a track is known, otherwise one line: "Not playing", with Play when a player is paused) and the last-screenshot row, which appears only after a copy. Wi-Fi, battery and volume are off by default and one toggle away in Settings → Layout; saved themes keep their rows, and applying a preset no longer replaces your rows.
- **Music bars:** the looping green equalizer is gone. While music plays, the closed notch's bars follow the player's real audio (4 bands, a small lift on each beat), in ink. Belay listens only to Music or Spotify, only while the bars are on screen, in memory only (ADR 0017). Without permission, or under reduced motion, a still glyph shows instead.
- **Purpose audit, applied:** removed the volume row and slider (Belay no longer reads or sets system volume), the Wi-Fi and battery rows, the clock in the open header, the "With info beside" closed style with its Mark/Battery/Time wings, and the charging alert: each duplicated the menu bar or had no job (`docs/ui-inventory.md` §5). Kept: now playing, last screenshot, and the music, screenshot, low-battery and "Internet lost or back" live activities. Saved themes that list retired rows still load; the rows are dropped. Belay no longer polls Wi-Fi (CoreWLAN unlinked) and reads the battery every 30 s instead of every second while open.
- **UI inventory:** `docs/ui-inventory.md`, the source of truth for every UI element (purpose, when it appears, default, interactions, states, accessibility, status), the information hierarchy, interaction and motion rules, a purpose test, and what was cut and why. Linked from AGENTS.md, design.md, README and the belay-design skill.
- **Claude Code skills:** `swiftui-macos` (ours: building and verifying `apps/mac`), `frontend-design` (Anthropic, Apache-2.0) and `verification-before-completion` (obra/superpowers, MIT) added under `.claude/skills/`, each third-party one verbatim with its licence and a `SOURCE.md`. `docs/claude-skills.md` lists them and what was skipped and why.
- **Detail pass:** tertiary text (status lines, track times) raised from 40% to 48% ink, clearing 4.5:1 on black (was 3.4:1); edge icon buttons pull out by their inset so the gear's glyph lines up with right-aligned values; the progress bar starts on the track title's column; the now-playing hero's space above and below is balanced.
- **Logo:** the Belay mark (the notch and the one point that needs you, `brand/`) replaces the climber glyph: a vector template image in the menu bar, a `BelayMark` shape for the "Mark" wing option (was "Climber"; saved choices carry over) and the About pane, and `AppIcon.icns` bundled as the app icon. The point stays still; it's reserved for "needs you" moments.
- **Settings, consistent controls:** every number is a slider with a right-aligned value and units in one 300 pt column (open and close delays read as a pair); segmented controls and menus trail-align with them; toggles are switches. Each section has a header and a Reset that appears only when it differs from its theme or default. Appearance panes start with a live notch preview (Motion adds Replay). Font menus show each family in its own face, with a live sample line under each picker.
- **Settings:** essentials first (General, Layout, Screenshots, AI accounts, About). Theme, typography, colours, surface and motion appear with "Show advanced settings" in General (remembered). "Keep the notch open while Settings is open" moved to General.

### Open (Day 1 checks)
- Bun HTTP/WebSocket on a Unix socket inside a compiled binary.
- Codex `PermissionRequest` hold time (Perch uses 5 s).
- Whether `PermissionRequest` fires in headless `claude -p`.
- Bun binary size and idle memory.
- Anthropic Commercial Terms for launching the user's own Claude Code (v0.2 Hands).
