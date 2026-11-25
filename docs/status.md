# Belay: product status report

**As of:** 2026-11-25, `main` (92 commits plus this branch). **Read this first** if you're a new agent session: it says what exists, what's true, what isn't verified, and what comes next. Details live in the linked docs.

> **Belay** is a free, open-source (MIT) macOS notch app.
> - **The product:** it supervises coding agents (Claude Code, Codex). Approve a command from the notch, and get caught before a dangerous one runs.
> - **Around that:** it's a calm, customizable Dynamic Island for the Mac.
> - **Goal:** reach and reputation (build in public on X), not revenue.

## 1. Where we are in one table

| Area | State |
|---|---|
| Research, product, plan, architecture | **Done:** `docs/` (landscape → verdict → product → features-final → architecture), ADRs 0001–0019 |
| Notch shell (Swift) | **Built and polished:** window, live activities, widgets, themes, Settings, performance modes |
| **Agent supervision (the product, A1–A6)** | **A0 spike passed** (hold, deny, allow, steer). A1 onward not started |
| Crew (dusk/grok-style helper agents, K1–K8) | Designed (`docs/crew.md`, ADRs 0009–0011). v0.2 / v0.3 |
| Brand | Mark system chosen (notch + point). A newer belayer mark is in progress in another agent's working tree (uncommitted `brand/`, `BelayMark.swift`). `BrandSlot` is the one place the notch draws it |
| Distribution | Not set up: ad-hoc signed only; needs the Apple Developer Program (§7) |

## 2. What's built (apps/mac)

**Closed notch:**
- **At rest:** exactly the size of the hardware notch, and invisible.
- **Live activities** grow as two wings beside the camera:
  - **music:** artwork, plus bars that follow the real audio;
  - **screenshot copied:** a copy icon, plus a green check that draws in;
  - **low battery** (20% and 10%) and **internet lost or back**;
  - **timer:** a ring and the minutes left, then "Done".

**Open notch** (hover or click; `docs/notch-widgets.md`):
- **Band beside the camera:**
  - left: brand slot, the future agent status light;
  - right: Expand/Compact, Edit widgets, Settings.
- **Widgets in the user's order,** packed with no holes (ADR 0019):
  - **Now playing:** art, title, artist, a seekable progress bar, prev/play/next;
  - **Last screenshot:** copy again, show in Finder;
  - **Timer:** optional, 1–180 min.
- **A widget with nothing to show takes no space.**
- **Edit widgets:** drag cards into slots; − hides; + chips restore.
- **Expanded:** 180 pt wider, full layouts, bigger art.

**Settings,** in five pill tabs:
- **General:** open with hover or click, delays, haptic, **performance mode with a live CPU/memory readout**, live activities, screenshots, open at login.
- **Widgets:** native drag list.
- **Appearance:** pinned live preview, theme swatches, plus Layout · Type · Colour · Surface · Motion. Every token is user-editable and shareable as JSON (ADR 0015).
- **Agents:** finds your `claude` / `codex` CLIs and never touches credentials (ADR 0004).
- **About.**

**System:**
- Screenshot auto-copy.
- Music and Spotify via notifications plus guarded AppleScript. Belay never launches a player.
- Haptics on hover only, never on click.
- Menu bar item: Open notch, Settings, Quit.

## 3. How it's built today
- **Swift 6, SwiftUI + AppKit,** built with SwiftPM and the Command Line Tools only (ADR 0013). `apps/mac/scripts/run.sh` builds, bundles, signs and launches.
- **Our own non-activating `NSPanel`** for the notch (ADR 0014), with themed tokens in `Tok` (ADR 0015).
- **Planned and not yet written:**
  - `belayd` (TypeScript on Bun), holding all product logic;
  - the `belay-hook` shim over a 0600 Unix socket;
  - protocol v1 between shell and core (ADRs 0001, 0005, 0006, `docs/architecture.md`).
  - **Swift renders; TypeScript decides.**

## 4. Quality bars and where we stand
- **Design:**
  - `docs/design.md` (rules and anti-slop list) and `docs/ui-inventory.md` (every element, its job, its status, and the purpose test).
  - Feel references are captured in the `dusk-feel` skill.
  - `docs/notch-comparison.md` compares Belay with the Dynamic Island and Boring Notch.
- **Performance** (`docs/performance.md`):

  | State | CPU |
  |---|---|
  | Closed, idle | 0.0% |
  | Music bars | ~2–3% (was 11–20%) |
  | Open, timer ticking | ~1% (was ~10%) |
  | Open/close | ~3 ms per frame |

  - Memory: 17 MB.
  - Launch: ~60 ms of our own setup.
- **Tests:**
  - `scripts/beat-selftest.sh` (analyzer and its cost) and `scripts/widgets-selftest.sh` (packing over every order and size).
  - XCTest needs Xcode, which isn't installed (ADR 0013).
- **Repo checks:** `.claude/skills/belay/scripts/verify-repo.sh` runs before every commit (provenance, ADR index).

## 5. Not verified yet (needs the owner or real hardware)
- **Live music cost** with the real audio tap while a song plays. The agent never starts playback.
  - Check: play a song, then `top -l 9 -s 1 -pid $(pgrep -x Belay) -stats pid,cpu`. The budget is ≤ 3%.
- **By hand:**
  - dragging widgets in the notch;
  - click-to-open mode;
  - Open at login (not toggled on the owner's Mac);
  - the battery change notification on plug or unplug;
  - the low-battery alert visuals;
  - the menu bar mark in light mode;
  - Spotify behaviour after it quits.
- **Possible small cost while the pointer moves:** 1–4% in `top` while the profile looks idle. Open item in `docs/performance.md`.
- **Several activities at once:** only one wing shows; the rest wait. Agents will need the minimal-presentation idea (`notch-comparison.md` §4).

## 6. How we work
- **Git:** one branch per major update (`<type>/<topic>`), one commit per task, merged into `main` with `--no-ff` and pushed to `github.com/Proxyy587/beyleaf` (AGENTS.md).
- **Before every commit:**
  - build with 0 warnings, then screenshot the changed state;
  - measure CPU if anything moves;
  - run the self-tests and `verify-repo`;
  - update `CHANGELOG.md` under `[Unreleased]`.
- **Unknowns are written UNVERIFIED.** Agents don't press system prompts, start playback or change the owner's settings.
- **Skills** (`docs/claude-skills.md`): `belay`, `belay-design`, `dusk-feel`, `swiftui-macos`, `dxe-apple-native-ui`, `frontend-design`, `agent-browser`, `improve-codebase-architecture` + `codebase-design`, `verification-before-completion`.
- **Subagent:** `.claude/agents/product-designer.md`.
- **Licences:**
  - vendor only MIT/Apache/BSD, through `scripts/vendor.sh` (ADR 0003);
  - dusk bot is PolyForm, so it's a local study clone only, never copied (ADR 0018);
  - Boring Notch is GPL, so we compare products only.
- **Debug flags** for screenshots and measuring: `--expand`, `--no-player`, `--start-timer`, `--edit-widgets`, `--flash-copied`, `--beat-demo`, `--cycle-open`, `--beat-probe`, `--settings --settings-pane <tab>`.

## 7. What's next

### Before anything (the owner, `docs/prerequisites.md`)
1. ~~Install Bun~~: done (1.4.5).
2. Install the Codex CLI to test Codex hooks.
3. Check the unverified items in §5 that only you can check, especially the live music cost.
4. Later, before sharing builds: Apple Developer Program (signing and notarization), final name check (Belay vs the repo name `beyleaf`), and legal review before any trading work.

### Phase A: agent supervision (v0.1, the product)
**The plan in `docs/build-plan.md` §3 is corrected here:**
- Day 1(a) "fork Clicky in Xcode" and Day 3 "DynamicNotchKit" are obsolete. The shell exists (ADRs 0013, 0014).

| Step | Deliverable | Done when |
|---|---|---|
| A0 · go/no-go spike | **Done: GO** (2026-11-25, `docs/spikes/a0-hooks.md`). Hold, deny and allow work; steering works when it's the user's words verbatim (ADR 0020) | ✓ |
| A1 | Session store and states (working, waiting, done, error) over protocol v1. The **brand slot becomes the status light**; a closed-notch wing per session | 3 sessions show correct states within 150 ms |
| A2 | Rope-drop approval card in the notch: Allow ↵ / Deny ⎋ / Always ⇧↵. Timeout hands back to the terminal (fail open, ADR 0005) | Approve a real command from the notch in < 1 s |
| A3 | Danger rules and the catch (rm -rf, force-push, prod DB, `curl \| sh`, secrets) | ≥ 50 rule tests pass |
| A4–A5 | Voice steer and spoken status | "No, use staging instead" works |
| A6 | E2E continuation matrix for Claude Code and Codex | Green before release |

**Design work to do first for agents:**
- an Agents widget (wide; expanded mode shows each session's detail);
- several-activities wings;
- add every element to `docs/ui-inventory.md` with the purpose test.

### Phase B: Crew (v0.2+, "agents like dusk bot / grok")
- Lead, Scout, Tempo and Porter work through the user's own AI CLIs. Hub-and-spoke through `CrewService`, with bounded turns and taint tracking (`docs/crew.md`).
- It builds on Phase A's protocol, approvals and risk engine, so it starts after A2–A3.

### Later
Converters (`docs/conversions.md`), trading as a non-custodial design (needs legal review, `docs/trading.md`), the website (`frontend-design` + `dusk-feel`), and launch (`docs/launch.md`).
