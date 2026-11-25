# Changelog

All notable changes to Belay are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/) once code ships. Update `[Unreleased]` in the same commit as the change.

## [Unreleased]

### Added
- **Weather widget (Day page):** temperature now, today's high and low, and when rain starts ("Rain from 15:00" / "Dry until 02:00") for a city you search in Settings → Widgets → Weather (Open-Meteo, CC BY 4.0, no key, no Location permission; units automatic, °C or °F). One request, only while the Day page is visible and the forecast is older than 30 minutes; a kept forecast shows `OFFLINE`, one older than 3 h on a dead network takes no space; "Open-Meteo" link on the card. Debug: `--weather-city <name>` (live, never saved).
- **Notes widget (Notes page) and capture shortcut:** one field captures and searches (Return saves, typing filters case- and accent-insensitively, Esc clears then closes); newest first, 3 notes (5 expanded) with age, hover for Copy and Delete, Undo for 4 s, `NOT SAVED` if the write fails. Plain JSON at `~/Library/Application Support/Belay/notes.json`, written atomically, read the first time the page shows, capped at 5,000; a damaged file is moved aside, never overwritten. **⌃⌥N** opens the notch on Notes with the field focused (Carbon hotkey, no permission; closes after saving; toggle and "taken by another app" message in Settings → Widgets → Notes). Debug: `--notes-file`, `--notes-capture`.
- **Stopwatch widget (Now page, off by default):** ready, running and paused states; lap and pause, or reset and resume; elapsed ticks once a second only while visible, paused and laps show hundredths; wide form lists the last three laps. The closed notch shows the stopwatch glyph and elapsed minutes while it runs and nothing higher (music, timer) is live; toggle in Settings → General → Live activities → Stopwatch. In memory only. Debug: `--start-stopwatch`, `--demo-stopwatch`, `--enable-widget <kind>` (this run only).
- **Jarvis roadmap:** `docs/jarvis-roadmap.md` (phases 1–7: polish pages and widgets, buddy core, chat and Agents page, routines, connectors, Mac control, voice layer; state, rules and Phase 1 handoff for agents without chat context) and ADR 0022 (proposed). Phase 1 found that Clock, Stopwatch, Notes, Weather and Calendar are specified but not built; status and docs map updated to say so.
- **Pages in the open notch:** the open notch shows one page at a time (Now, Notes, Day; empty pages are skipped, a single page shows no dots). Two-finger swipe follows the fingers with resistance (at most 40 pt), commits past 60 pt, springs back, and gives a little at either end (no wrap); momentum and vertical scrolls never turn a page. Dots in the band, ⌘[ ⌘] ⌘1–4 and Esc while the panel is key, VoiceOver adjustable dots. Reduced motion: no follow, cross-fade only. Pages that are taller than the room scroll vertically (no scrollbar, edges fade) instead of clipping widgets, and the panel stays within 60% of the screen. Debug: `--page-limit <pt>`, `--cycle-pages`. The swipe and the fit are pure logic with self-tests.
- **Widget hub spec:** `docs/widget-hub.md` and ADR 0021. The open notch becomes pages (Now, Notes, Day; Agents at A1) you swipe between, each packed like before; clock with time zones, smart timer, stopwatch, notes, weather (Open-Meteo, city only, no Location) and calendar (EventKit, asked once) are specified with every state, permission and CPU budget. The UI inventory records the clock and weather as owner overrides.
- **Buddies in the Mac app:** `BuddyView` draws any buddy in either style at any size (16–256 pt checked), from art generated out of `brand/buddies/buddies.json`: smooth as vector paths, pixel as cells with anti-aliasing off (nearest neighbour, whole-cell motion). Moods: idle, blink, look left/right, hover, sleep, happy (^ ^ and one hop), all ≤ 280 ms, nothing at rest, reduced motion honoured. Debug: `--buddies [mood]`, `--buddies-cycle`.
- **Logo (temporary):** beepo replaces the mark in the notch's brand slot (its own purple; eyes turn live green from A1) and in Settings → About, where hover lifts it, a click blinks and a double-click hops. App icon and menu bar icon unchanged for now.
- **Buddies:** 15 buddies in two styles, traced from the owner's reference sheets (`brand/buddies/`). Smooth: vector SVGs with silhouette IoU 0.993–0.997 against the sheet. Pixel: each sprite's grid recovered and sampled cell by cell, faces redrawn on the grid, SVG + lossless PNG (IoU 0.953–0.993; the sheet's own grid drifts). Eyes are separate parts for blink, look, sleep and a happy ^ ^ with a hop. `comparison.png` shows reference beside ours for all 30; `preview/index.html` plays every animation; `tools/run.sh` rebuilds it all.
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
- **Spike A0: GO.** A minimal `belayd` and `belay-hook` on Bun held a Claude Code permission request for 20 s, then denied it and steered Claude. Steering works only when it is the user's own words, quoted and attributed (ADR 0020). Bun pinned at 1.4.5.
- **`docs/status.md`:** the product report: what is built, how, quality numbers, what is unverified, how we work, and the corrected next steps (A0 spike → A1–A6, then Crew). AGENTS.md now points new sessions there first.
- **Open with Hover or Click** (General → Notch): click mode catches clicks only on the notch itself. **Open Belay at login** (General → Startup) via macOS Login Items. The open haptic now fires only on hover.
- **Expand / compact:** a band button widens the open notch by 180 pt (up to 640), gives every widget its full layout and grows the album art; remembered between launches. Room for agents and Crew later.
- **Battery** is read when macOS reports a power change, not every 30 s; Macs without a battery never wake for it. Removed dead code (`NotchSwitch`, the old advanced-settings flag).
- **`docs/performance.md`:** budgets for every state, the measured numbers, the debug flags and the eight rules that keep Belay fast. Launch time is logged (`app.belay.mac:perf`): ~60 ms of our own setup.
- **Open/close:** the hosting view no longer recomputes its size every frame, and the panel moves as one unit while the shape springs. About 3 ms of CPU per frame during a transition (120 Hz budget: 8.3 ms), 0.0% at rest. Debug `--cycle-open` measures it.
- **Screenshot copied** is two wings again, no line under the notch: a copy icon on the left, a green check that draws in on the right.
- **Settings → General → Performance:** Automatic (saves energy in Low Power Mode), Save energy (30 fps, no blur) or Smoothest (display rate, 120 Hz on ProMotion), with a live readout of Belay's own CPU and memory.
- **Music bars, ~8× cheaper:** drawn by Core Animation layers on a display link instead of 30 SwiftUI updates a second. Levels pass from the audio queue through a lock, not `@Published`; the link parks itself when the bars settle. The stereo mixdown uses Accelerate. Measured with synthetic levels (`--beat-demo`): 11–20% → ~1.9% CPU.
- **Docs:** `docs/notch-comparison.md` compares Belay with the Dynamic Island (Apple HIG) and Boring Notch (README); UI inventory updated for widgets.
- **Settings revamp:** five tabs in a pill bar (General · Widgets · Appearance · Agents · About, ⌘1–⌘5) instead of an 11-item sidebar. General gathers hover, live activities, screenshots and feel. Appearance pins a live preview, shows themes as swatches drawn in their own colours, and switches between Layout · Type · Colour · Surface · Motion. "Show advanced settings" is gone.
- **Edit widgets** is now direct manipulation: drag a card to the exact slot you want (it lifts and the others make room), − hides it, + chips bring hidden widgets back. The ↑/↓ list is gone.
- **Screenshot copied** is now a proper moment: the notch springs wider and drops a line ("Screenshot copied · ⌘V to paste") with the thumbnail and a green check that draws in.
- **Timer:** now a side option, off by default (turn it on in Edit widgets or Settings → Widgets). Pick any length with − / + or by dragging the number, instead of fixed 5/15/25/50 chips. The countdown no longer rolls its digits, which cut the open panel from ~10% to <1% CPU while a timer runs.
- **Haptics:** only the hover-open tick remains. Buttons, chips, switches, screenshot copies and timer endings no longer buzz; with the trackpad's own click they felt like a double tap.
- **Settings → Widgets:** a native list to drag widgets into order and switch them on or off (replaces the Rows section in Layout). Live activities gain a Timer switch. The preview shows the new panel.
- **Notch redesign:** the open panel is now widgets on tonal cards: Now playing (title, artist, progress and controls in one compact card), a new **Timer** (presets 5/15/25/50 min, ring + countdown, pause/stop, "Done" flash in the closed notch) and Last screenshot. The band beside the camera holds the brand slot (left) and Edit widgets + Settings (right). Edit widgets in the notch: reorder with ↑/↓, switch widgets on or off, right-click a card to move or hide it. "Not playing" and empty placeholder lines are gone; a widget with nothing to show takes no space.
- **Logo:** the Belay mark is a soft pebble pet — one body, two tall eyes (`brand/`). Same dusk/Grok/Dots pet formula (inspiration only), Belay's own climbing-hold silhouette. Live fills the eyes green. Menu bar, `BelayMark`, About and `AppIcon.icns` updated.
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
