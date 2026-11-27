# Buddies: agents that live in your notch and run your Mac

**Status:** design for Phase 2–7 of `docs/jarvis-roadmap.md`. Owner request 2026-11-27. Nothing here is built yet.
**Builds on:** `docs/crew.md` (engine, hub-and-spoke, ToolHost), `docs/widget-hub.md` (pages, grid), `docs/design.md` (rules), ADR 0022.
**Clean room:** dusk bot, Grok companions and Clicky are read for *behaviour and feel* only. No code, copy or assets are copied (ADR 0008, 0018).

> **In one line:** a buddy is a small character that lives beside the camera. You summon it, talk or type, and it
> *does things*: reads your screen, runs errands, works on a schedule. It never does anything outward or destructive
> without the rope card.

## 1. The three ideas we are joining

| From | The idea | What Belay takes |
|---|---|---|
| **Clicky-style** companion | The assistant is *beside you*, sees your screen, talks, and points at things | Screen-aware buddies, push-to-talk, a buddy that shows you where on screen (Sketch overlay), Mac actions |
| **Grok-style** companions | Characters with personality you chat with | Each buddy has a voice, a job and a mood; chat is the main surface, not a settings form |
| **dusk bot** | One buddy, one job, one thread; notes you can read; routines; group hand-offs | Same principles, local and in the notch (`crew.md` §0) |
| **Belay (ours)** | The rope: you approve what matters | Every outward or write-outside step shows a card first |

The wedge nobody else has: **they live in the notch and every action is supervised.** "Fully automated Mac" is the
destination; the rope is why you can trust it.

## 2. The cast

15 characters already exist as art (`brand/buddies/`). Each gets a job and a personality card. The job is the product
(one buddy, one job); the character is the personality. **Names and jobs below are proposals for the owner to edit.**

| Buddy | Job (crew role) | Personality in one line | Engine default |
|---|---|---|---|
| **beepo** | Belay, the coordinator you talk to; routes "who handles this" | Steady, brief, a little dry | Router (rules) → your CLI |
| **sprout** | Lead: code in your repos | Careful, asks before big moves | `claude` / `codex` CLI |
| **pip** | Porter: apps, files, Shortcuts, settings | Eager, tiny, does errands | Deterministic actions |
| **fizz** | Tempo: music | Chatty about songs only | Deterministic + small LLM |
| **willo** | Scout: browse and research with sources | Curious, cites everything | Your CLI with web tools |
| **fig** | Sketch: draws on screen to explain | Visual, points | Your CLI → SceneSpec |
| **otto** | Inbox: mail and calendar triage (Phase 5) | Organised, hates clutter | Your CLI + connectors |
| **bram** | Files: finds, sorts, cleans (Phase 6) | Gruff, tidy | Deterministic + CLI |
| remaining 7 | Custom buddies you create (name, job card, engine, tools) | You write it | Any |

Not every buddy ships at once. Ship order is §9.

## 3. Where a buddy lives (four surfaces)

1. **Closed notch wing.** The active buddy's sprite sits in the left wing (replacing the brand slot's idle mark). It is
   still at rest. It blinks once when it has something to say, and its eyes turn live green while it works (`design.md` §7:
   no idle loops). A held approval takes over the wing exactly as ADR 0005's rope drop does.
2. **Open notch, Agents page.** A fourth page after Day (the page reserved in `widget-hub.md` §6). Content in §4.
3. **Buddy widgets** on the Now page, same grid, same sizes (ADR 0023). Pin the buddies you use most. Small, wide, full.
4. **Base camp window.** A normal macOS window for long conversations, the roster, notes, routines and the activity
   log. The notch is for glances and quick asks; Base camp is for work. (`crew.md` §3 already names it.)

Plus one global entry: **summon bar** (⌥Space, rebindable). A small centered field that appears over any app: type or
hold the key to talk. "scout, find the Bun docs for Unix sockets" routes by name; no name goes to beepo.

## 4. Compact vs expanded: the difference, made unmistakable

The rule from ADR 0023 stands: expanded adds *room*, not bigger things. For buddies the two modes answer different questions.

| | **Compact** (default) | **Expanded** |
|---|---|---|
| Question it answers | "What are my buddies doing, and can I say one thing?" | "Let me work with them." |
| Layout | Roster strip: sprite + name + one status line each, most urgent first. A one-line composer. | Two panes: roster left (same strip, narrower), thread right with tool trace. |
| Chat | Last reply only (2 lines, truncated), reply field. | Full scrolling thread, each tool call as a collapsed row ("opened Safari · 2 s"), attachments, screenshots. |
| Approvals | Pinned card above the page, Allow ↵ / Deny ⎋ / Always ⇧↵ | Same card, plus the exact action and which buddy asked. |
| Extra | nothing | Memory notes (editable), routines list, task tree for group goals. |
| Typical time open | under 5 seconds | minutes |

A buddy **widget** follows span sizes:
- **small:** sprite + state dot + name. Tap summons its composer.
- **wide:** sprite, last reply (2 lines), one-line composer.
- **full:** the compact chat pane (last 4 messages + composer).

The mode toggle is the existing Expand button, so nothing new to learn. Base camp is always the "expanded" form.

## 5. Chat design (what it looks like)

- **A message is text, not a bubble.** Left-aligned buddy text in `ink`, your text in `ink2`, no avatars repeated per
  line (the sprite sits once at the top of a run). Matches the anti-slop list: no cards inside cards.
- **Tool calls are rows, not chatter.** A buddy that opens an app shows `OPENED SAFARI` as a status line (SF Mono 10),
  tap to expand its arguments. The reply text stays short.
- **Streaming** appears word by word, no typing-dots loop. A working buddy shows live-green eyes and elapsed time.
- **Group thread:** @mentions hand work off ("@sprout run the tests"); the coordinator closes goals (`crew.md` §6).
- **Voice:** hold the key, release to fill the composer; you confirm before send (ADR 0020). Spoken replies are opt-in.
- **Empty states, one line:** "No buddies yet. Add beepo." Not a tutorial.
- **Mood** is the only decoration: sprite moods already exist (happy after a finished task, sleep when idle for long).

## 6. Mac reach: "fully automated" without losing the rope

Buddies get abilities in four tiers. A buddy's card lists which tiers it may use; you set that.

| Tier | What | Examples | Permission and rope |
|---|---|---|---|
| **0 Observe** | Look, don't touch | Screenshot the screen or a window, read the front app and window title, clipboard (on request) | Screen Recording asked once, on first use. Reading is local; nothing leaves the Mac except what the engine receives. |
| **1 Errands** | Deterministic Mac actions | Open apps and URLs, Shortcuts, reveal in Finder, set Focus, timers, volume, playback | No card for read-like or reversible actions; a card for anything outward (send, post, install). |
| **2 Hands** | Drive the UI | Click, type, scroll via Accessibility, run AppleScript | Accessibility asked once. Each *session* of hands needs a start card ("Pip wants to control Mail"); "Always for this app" is a user rule, never automatic. |
| **3 Sandbox** | A separate virtual computer | Long unattended web or app work | Later, via Cua (`crew.md` non-goals). Out of scope until Phase 7+. |

Safety rules (ADR 0005, 0011): a buddy's actions pass the same RiskEngine and ApprovalBroker as your coding agents;
untrusted content (an email, a web page) can never grant permission; a tainted chain always drops the rope for sends,
writes outside the allowed folders and Shortcuts; timeouts and crashes mean "no decision", never "allow". Buddies don't
move your mouse while you are using it, and always show a visible "buddy is controlling" state in the wing.

## 7. Routines: the automation part

A routine = trigger + buddy + goal ("every weekday 8:30, otto: summarise my inbox and calendar into one note").
- Triggers: schedule (cron-like, with plain-language picker), event (a session finished, battery low, a calendar
  event starting, a file landing in a folder), and manual.
- Run by `belayd` on your Mac. If the Mac was asleep, the missed run is **shown, not silently replayed**; one tap runs it.
- Each run produces a short result in the thread and, if it did anything outward, the cards wait for you.
- Every routine is listed in Base camp with last result and a pause switch. Nothing runs that you can't see.

## 8. Settings and ownership

- **Settings → Buddies:** roster, pick style (smooth or pixel), engine per buddy, tiers per buddy, hotkey, voice on/off.
- **Memory** is a Markdown file per buddy you can open and edit (`crew/<buddy>/notes.md`, `crew.md` §4).
- Engines are your own CLIs or a local model or your own API key; Belay never touches credentials (ADR 0004).
- Everything is off by default except the buddy you add first; permissions are asked at first use, never at launch.

## 9. Build plan (ship order, each phase viewable)

The blocker named in ADR 0022: Phases 2+ need `belayd` and protocol v1, which don't exist in code. **Recommendation:**
begin Phase 2 by standing up the smallest `core/` (protocol v1 with only the crew messages, a socket, a minimal
`CrewService`, `FakeRuntime`), and build the Swift side against it. Don't wait for A1–A3; the approval path for buddies
is the same code A2 needs, so build it once, in this order, and A1–A2 reuse it.

| Phase | Ships | What you can see | Verified by |
|---|---|---|---|
| **2a Core stub** | `core/` protocol v1 (crew subset), 0600 socket, `CrewService` + `FakeRuntime` | nothing visible; a scripted buddy replies in the notch | core tests, socket permissions test |
| **2b Buddy in the notch** | Left-wing sprite with mood states, buddy widget (small/wide/full), add-a-buddy flow | beepo in the wing; a buddy widget on Now | screenshots in both modes; reduced motion; CPU idle < 1% |
| **3 Chat** | Agents page (compact + expanded), Base camp window, summon bar, real runtime (`claude -p`) | talk to beepo; Lead answers | Day 1 spike of CLI flags (UNVERIFIED today); a live reply |
| **4 Routines** | Scheduler in `belayd`, Routines list, missed-run card | "every morning" works | clock-injected tests; sleep/wake manual check |
| **5 Connectors** | Calendar (EventKit, exists), mail, files, web; every outward action behind a card | otto summarises the day | card shown for every send; taint tests |
| **6 Mac control** | Tier 0 → 1 → 2, Sketch overlay | pip opens things; fig points at a button | permission prompts asked once; "buddy is controlling" state |
| **7 Jarvis layer** | Push-to-talk, "<name>, …" routing, proactive nudges (rare, dismissable) | talk to your Mac | latency budget; nudge frequency cap |

Each phase: its own `feat/` branch, one commit per task, CHANGELOG, `docs/ui-inventory.md` rows, `verify-repo.sh`.

## 10. Open questions (UNVERIFIED or needs the owner)

1. Names and jobs in §2 (proposal only). Which 3 buddies ship first? *Recommend: beepo, sprout, pip.*
2. Is `core/` first (recommended) or A1–A2 first? Record in ADR 0022.
3. Exact `claude` / `codex` non-interactive flags, MCP config and resume (UNVERIFIED until the spike, `crew.md` §5.1).
4. Commercial-terms question before launching Claude Code from Belay (`oss-reuse.md` §2).
5. Whether Tier 2 (Accessibility hands) is acceptable for a free open-source app on distribution; needs signing first.
6. Summon-bar hotkey: ⌥Space may clash with Spotlight/Raycast users; keep rebindable.
7. The roadmap noted the owner's message was cut off at "…but for the". Not re-asked here; this spec assumes "…but for your Mac".
