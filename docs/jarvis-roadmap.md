# Jarvis roadmap: buddies, routines, connectors and Mac control

**Status:** owner request 2026-11-26, plan accepted, **Phase 1 partly done**. Update the table in §2 in the same commit as any phase work.
**Read first:** `docs/status.md` (what exists), then this file (what we're building and in what order).
**Design spec for Phases 2–7:** `docs/buddies.md` (cast, compact vs expanded, chat, Mac reach tiers, routines, build order).
**Decision record:** ADR 0022 (direction), ADR 0008/0018 (clean-room rule), ADR 0009–0011 (crew).

> **In one line:** Belay becomes a Mac-native assistant like Jarvis or Friday. Buddies (the crew, `docs/crew.md`)
> have personalities, chat, routines on schedules and connectors, and they can act on your Mac (the Clicky side),
> always behind the rope card. This is dusk bot's *behaviour* with Clicky's *Mac reach*, built in our own design.

## 0. The owner's ask, in their words (condensed)
1. Polish the notch's slide pages: flawless, nothing missing, every widget working, content that overflows scrolls.
2. Then a **buddies agent**, like dusk bot: the pet characters, **cron-style routines and schedules, chat, connectors**.
3. Plus **Mac customisability from Clicky** (control and personalise the Mac).
4. Together that is "Jarvis / Friday". Don't build it in one go: break it into phases, use the architecture docs and feature
   list, add / remove / change anything, and ship phase by phase so each change can be viewed.
5. The original message was cut off after "…but for the". Ask the owner what it was meant to say before finalising Phase 2.

## 1. Rules every phase obeys
- **Clean room (ADR 0008/0018).** `refs/duskbot` is PolyForm Noncommercial. It may be read for behaviour and feel
  (numbers, flows). **Never copy, adapt or translate its code, CSS, skill text, assets or copy.** Prefer the Apache-2.0
  upstream OpenMausBot (`refs/OpenMausBot`, vendor via `scripts/vendor.sh`) and Clicky/OpenClicky (MIT) for code.
- Swift renders and touches macOS; TypeScript (`belayd`) decides (ADR 0001). Buddies' brains live in `core/`, not Swift.
- Fail open, never auto-allow; any outward or write-outside action shows a card first (ADR 0005, 0011).
- Never read agent credentials; engines are the user's own CLIs (ADR 0004).
- Git: one branch per phase (`feat/<topic>`), one commit per task, `--no-ff` into `main`, push (memory: Belay git workflow).
- Before any commit: build with 0 warnings, run self-tests, `verify-repo.sh`, update `CHANGELOG.md` `[Unreleased]`.
- Anything not checked is written **UNVERIFIED**. Agents don't move the owner's mouse, start playback or change settings.
  (Phase 1's test scripts warped the cursor and wrote page defaults; avoid that, and restore state if unavoidable.)

## 2. Phases and state

| # | Phase | Branch | State |
|---|---|---|---|
| 1 | **Polish pages + widgets** | `feat/widget-hub` | **Done in code.** Paging + overflow committed (`149f106`). All eight widgets exist (§3). Not merged, not pushed |
| 1b | **Build the missing widgets** (Clock, Stopwatch, Notes, Weather, Calendar) per `docs/widget-hub.md` §3, one commit each | `feat/widget-hub` | **Built** (owner go-ahead 2026-11-26): all five widgets, one commit each, self-tests pass; by-hand checks still UNVERIFIED (`open-questions.md`). Not merged, not pushed |
| 2 | **Buddy core:** a buddy = persistent character + own thread + memory notes + personality + engine choice; shown in the notch with the 30 traced sprites | `feat/buddy-core` | **Partly done (2026-11-27):** crew protocol subset, scheduler and router in `core/` (14 tests); Agents page, Buddies and Routines widgets in Swift on demo data. **Not done:** socket between shell and core, `CrewService`/`FakeRuntime`, real engine, persistence |
| 3 | **Chat + Agents page:** 1:1 and group threads; the Agents page reserved in `widget-hub.md` §6 | `feat/buddy-chat` | Layout and composer exist (Phase 2); no real replies yet |
| 4 | **Routines:** cron-style schedules per buddy, run by `belayd`; missed runs shown after sleep | `feat/buddy-routines` | Not started |
| 5 | **Connectors:** calendar, mail, files, web; every outward action behind a card | `feat/connectors` | Not started |
| 6 | **Mac control (Clicky side):** Porter actions for apps, files, Shortcuts, screen, voice | `feat/mac-control` | Not started |
| 7 | **Jarvis layer:** push-to-talk, "Scout, …" routing, proactive nudges | `feat/jarvis` | Not started |

**Dependency to settle (open decision):** `docs/status.md` §7 says Crew starts after A1–A3 (session store, rope card,
danger rules) because it reuses protocol v1, `ApprovalBroker` and `RiskEngine`. Phases 2–7 need `belayd` and protocol v1,
which don't exist in code yet. So **Phase 2 must begin by standing up `core/` (protocol v1, socket, a minimal
`CrewService`)**, or A1–A2 must come first. The owner has not chosen. Record the choice in ADR 0022.

## 3. Phase 1 handoff (what the next agent needs)
**Done (commit `149f106`, branch `feat/widget-hub`):**
- `SwipeTracker` (pure, in `WidgetLayout.swift`): 0.35 resistance capped at 40 pt, commit past 60 pt, spring-back,
  ~14 pt give at the ends (no wrap), axis decided once per gesture, momentum swallowed, reduced motion = cross-fade.
- `PageScroller` + `PanelFit`: pages taller than the room scroll vertically (no scrollbar, edge fades); panel capped to
  the 620 pt canvas minus 32 pt shadow, and 60% of screen height minus the notch. Content clipped to card edges.
- `NotchPanel` becomes key only while open (`becomesKeyOnlyIfNeeded`), as `widget-hub.md` §1.5 says.
- ~25 new checks in `apps/mac/Tests/WidgetsSelfTest/main.swift`. Debug flags `--page-limit <pt>`, `--cycle-pages`.

**Truth about widgets:** `WidgetKind` has only Now playing, Timer and Last screenshot. **Clock, Stopwatch, Notes,
Weather and Calendar are specified only** (`docs/widget-hub.md` §3, ADR 0021). Notes and Day pages never show because
they hold no widgets. Nothing was removed.

**UNVERIFIED:**
- Real trackpad feel and natural-scrolling direction (`isDirectionInvertedFromDevice`); only synthetic events were used.
- Scrolling a tall page with real input (three widgets can't overflow it).
- ⌘[ ⌘] ⌘1–9 and Esc: they only fire while the panel is key, and nothing makes it key until the Notes field exists.
- Key returning to the previous app after close.

**Known gaps:** the widget editor (edit mode) is not inside the scroller and can outgrow the panel when many widgets are
hidden. The Phase 1 work is one commit because it shared files with earlier uncommitted pages work.

**Next task (1b):** build the five widgets in the order Clock → Stopwatch → Notes → Weather → Calendar. Weather uses
Open-Meteo with city only (no Location permission); Calendar uses EventKit, asked once; budgets in `docs/performance.md`.
Add every element to `docs/ui-inventory.md`.

## 4. Phase 2 sketch (to refine in its own spec before code)
- A buddy record: id, name, sprite + style (from `brand/buddies/buddies.json`), personality card, engine, allowed tools,
  memory notes (readable and editable by the user), routines. Stored by `belayd`, never by Swift.
- Behaviour to match from public dusk bot pages and the allowed study clone: one buddy, one job, one chat; notes you can
  read and edit; routines; group threads with hand-offs; "you step in when one needs a yes". Write what we learn in our own
  words in `.claude/skills/belay-design/` or `docs/crew.md`, never paste.
- Write the spec to `docs/buddies.md` first, add ADR 0022, then build.
