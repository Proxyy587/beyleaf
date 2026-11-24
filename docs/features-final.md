# Belay: final feature list

**Locked:** 2026-11-24.

**Supersedes:** the scope sections of `product.md` and `features.md`. Those docs keep the rationale; **this is the build list.**

**IDs:** IDs match `features.md`.

**Columns:**
- "Built in" names the components in `architecture.md`.
- "Done when" is the acceptance test.

## v0.1: launch (2 weeks)

The question v0.1 answers: *does the catch-and-steer moment work, feel native, and spread?*

| ID | Feature | Built in | Done when |
|---|---|---|---|
| A1 | Live climbers in the island (one rope per Claude Code / Codex session; climbing / rope / summit / dangling) | HookGateway, Adapters, SessionStore → Island | 3 concurrent sessions show correct states within 150 ms of each hook |
| A2 | Rope-drop approval card: Allow ↵ / Deny ⎋ / Always ⇧↵ | ApprovalBroker → RopeCard | Approve from the card; the agent continues. The terminal takes over on timeout. Focus never stolen. |
| A3 | Catch a fall: built-in danger rules with a catch animation, 3× haptic, sound and spoken warning | RiskEngine → Character, FeelKit, Voice | ≥ 50 rule test cases pass; `rm -rf`, force-push, prod-DB, `curl\|sh` and secrets paths all catch |
| A4 | Voice steer: "yes / no / always / stop / no, X instead" | Voice → IntentRouter → ApprovalBroker | "No, use staging instead" makes Claude retry on staging (Codex: allow and deny-with-message only) |
| A5 | "What are my climbers doing?" spoken status | Narrator (templates) | A correct spoken sentence for 3 sessions |
| A6 | Verified-continuation test matrix, published in the README | `e2e/` | Green for the current Claude Code + Codex versions before release |
| B1 | Now playing (basic): track and artwork in the collapsed island when idle; play/pause/skip | MacBridge.NowPlaying | Works with Music and Spotify (cut first if Day 8 slips) |
| B8 | Notch, camera-island and no-notch island modes | NotchShell (DynamicNotchKit) | Looks right on a notch MacBook and an external display |
| C1 | Push-to-talk, on-device speech | Voice | Hold key → waveform → transcript, offline |
| C2 | Spoken replies (system voices) | Voice | A voice picker in Settings |
| E1 | Haptics: catch + allow | FeelKit | Felt on a Force Touch trackpad; a sound and visual twin always plays |
| E2 | Sound pack v1 + auto-mute when the asking terminal is focused | FeelKit | No sound while the user is in that terminal |
| E3 | Spring-physics island (never flashes black) | NotchShell | 120 Hz on ProMotion, no frame drops on open or close |
| E8 | Battery-light, event-driven | both processes | Idle CPU < 1% combined |
| G1 | Daily Belay log card, with Copy or Post to X | Logbook, CardRenderer | A PNG with hours, approvals, falls caught and summits; two clicks to post |
| H1 | One-click hook install with diff preview; clean uninstall | Installer | Uninstall restores byte-identical original configs |
| H2 | No network port: 0600 Unix sockets only (ADR 0006) | HookGateway | The socket is mode 0600; no TCP listener exists (test) |
| H3 | "What Belay reads" page | web + Settings | Published and linked from onboarding |
| H4 | Guided Codex hook trust | Installer → onboarding | A fresh user gets Codex approvals working without reading docs |

## v0.2: the ecosystem starts (about 2–4 weeks after launch)

| ID | Feature | Built in |
|---|---|---|
| A7 | Jump to the climber's terminal | MacBridge.WindowLocator |
| A8 / D1 | Rope drawn from the notch to the window that needs you | WindowLocator + Overlay |
| A9 | Auto-mode watch ("auto mode said no to 2 things") | Adapters (PermissionDenied) + Narrator |
| A10 | Summit summary (template; on-device model if available) | Narrator + Engines |
| B2 | Agent-aware music (duck on rope drop, flow playlist) | NowPlaying + EventBus |
| B3 | Chalk bag shelf (drop a file on a rope to paste its path) | Shell + core |
| B5 | Calendar hold + "meeting soon, climbers still going" | MacBridge + QuestEngine |
| B7 | Focus timer aligned to summits | QuestEngine |
| C3 | Talk over it (barge-in) | Voice |
| C4 | Command phrases (music, timers, mute, stats) | IntentRouter + Actions |
| E1 | Full haptic vocabulary | FeelKit |
| E4–E6 | Focus/DND respect, accessibility and Reduce Motion, multi-display | Shell |
| F1–F5 | Side quests: body, review the last summit, wrap up sessions, learn a hold, rule tuning | QuestEngine → QuestCard |
| G2–G4 | Grades, streaks, weekly logbook card | Logbook + CardRenderer |
| H5, H6 | Sparkle auto-update; opt-in crash reports | Shell + CI |
| I2 | Rule-pack format (YAML), community `rules/` folder | RiskEngine |
| I5 | Docs site | apps/web |
| **J1–J4** | **Hands:** engines (your `claude`/`codex` CLI, a local model, BYOK), "ask Belay to do it", instant Mac actions, edit-before-it-happens cards | Engines, Actions, IntentRouter |
| **L1–L5** | **Convert:** drop-on-notch wheel, Finder right-click, voice/hotkey, route planner on macOS built-ins + permissive bundles, coverage v1 (`conversions.md`) | ConvertService (core), native steps in MacBridge |
| **K1–K3, K5, K6** | **Crew:** Belay, Lead, Porter, Tempo, Scout (engine web tools); talk by name; ask, handoff and report with budgets; editable memory; taint and "stop everyone" (`crew.md` §14) | CrewService, ToolHost + MCP bridge, Runtimes, MemoryStore |

## v0.3+: platform

| ID | Feature |
|---|---|
| A11 | Undo last pitch |
| A12 | Replay timeline |
| A13 | Spend and quota hold |
| A14 | More agents (Gemini CLI, OpenCode, Cursor: observe-only first) |
| B4 | Clipboard history with secret masking |
| B6 | System HUD |
| C5 | Hand a new prompt to a running climber (only if a documented path exists) |
| C6 | Ask about your screen (BYOK) |
| D2–D4 | Highlight the risky line, diff spotlight, freehand pointing (OpenClicky draw stage) |
| E7 | Shortcuts / App Intents |
| F6, F7 | Micro-break games, community quests |
| G5, G6 | Profile card, optional Crag community |
| I1, I3, I4 | TypeScript plugin API, skins and sound packs, standalone `belay` CLI for Linux |
| J5–J7 | Accessibility-tree control, Cua sandboxed computer use, opt-in cloud connectors |
| L6–L9 | Convert: detected external tools (WebP, MP3, WebM, epub, office→pdf), OCR, paste-as, watch folders, Shortcuts action |
| K1, K4, K7, K8 | Crew: Sketch, custom members, group goals with plan cards, SceneSpec drawings, on-device routines; Scout's dedicated browser |
| — | Rust `belay-core` + Tauri shells for Windows/Linux (`architecture.md` §10) |

## Never

- Paid tiers.
- Accounts.
- Our own cloud computer.
- Prompt sentiment analysis.
- Reading agent credentials.
- GPL code.
