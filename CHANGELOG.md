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

### Changed
- Hook transport moved from localhost HTTP hooks with tokens to command hooks plus a 0600 Unix socket (ADR 0006, learned from Perch).

### Open (Day 1 checks)
- Bun HTTP/WebSocket on a Unix socket inside a compiled binary.
- Codex `PermissionRequest` hold time (Perch uses 5 s).
- Whether `PermissionRequest` fires in headless `claude -p`.
- Bun binary size and idle memory.
- Anthropic Commercial Terms for launching the user's own Claude Code (v0.2 Hands).
