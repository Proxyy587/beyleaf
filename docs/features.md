# Belay: feature spec (the whole ecosystem)

**Written:** 2026-11-24.

**Role:** product design.

**Companion docs:** `product.md` (concept, hero moment), `build-plan.md` (2-week build), `launch.md`.

**What we're making:** a free, open-source (MIT) Mac companion that lives in the notch. It supervises your coding agents, keeps your music and system one glance away, and turns the waiting time between agent runs into something pleasant. Heyclicky and Aria are the benchmarks. The goal is **not to copy them, but to make the better, free, open version with its own brand**: a climbing world, not a cursor buddy and not an orb.

---

## 0. What the benchmarks actually ship (read 2026-11-23/24)

### heyclicky (closed source, paid tiers $0 / $16 / $80 a month on yearly billing; Mac + Windows)

Source: https://www.heyclicky.com/changelog, about 40 releases from 1.0.15 (2026-05-13) to 1.1.7 (2026-11-21).

- **Voice:**
  - Push-to-talk, realtime voice
  - "Interrupt me anytime"
  - Talks in 130+ languages; dictation in 117
  - "It learns your words"
  - Voices in your language; Bluetooth headphones support
- **Screen:**
  - Sees your screen on hotkey
  - **Draws on screen**: rings, highlights, arrows, hand-drawn annotations. 2D and **3D drawings**, and drawings that scroll with the page.
  - "Walkthroughs" that point to where to click; learned 89 apps
- **Agents ("Clickys"):**
  - Named background agents that research, write and build
  - Run through a Chrome extension and "HeyClicky drive" (computer use)
  - Routines and scheduled jobs ("every Monday at 9")
  - Proactive morning suggestions hung "under the notch", with *Do it / Adjust / Nah*
  - Retry, frozen-job detection, "Your turn" hand-backs
- **Notch & UI:**
  - Home in the notch, resizable; drag files into the notch
  - Unread count on the notch; green "working glow" on external monitors
  - Camera-island support on the new MacBook Pro
  - Hold a finger on the island to open it
  - "Next steps" pills after every answer
  - A calm dotted-background visual style
- **Life:**
  - "Any song on Spotify", Google Calendar, HeyClicky Notes
  - "Types for you, anywhere"
  - Connected apps (Gmail, Meta Ads, etc.)
  - Memory ("remembers how you like to be talked to")
- **Growth:**
  - Referral ("Invite friends, get Pro")
  - Onboarding tour with personality ("my lord, are you sure?")
  - Paid $10 usage resets

### Aria (closed source, free beta; Pro $15/mo planned; Mac only)

Sources: https://joinariapp.com, /pricing, /updates, /what-aria-reads.

- **Agents:**
  - See sessions live; approve and steer from the notch
  - Replay ("laps"), parallel worktrees, review/merge/checkpoints, undo, hand-off
  - "Agent races"
  - Overlap warnings and a budget guard
- **Assistant:** talk or type, on-device speech, receipts and undo for its actions, routines, Lens (text from an image).
- **Notch life:** now playing, shelf, clipboard, calendar, window tools, volume/brightness/battery HUD.
- **Social:** rooms, presence, teams, profiles, streaks, badges, clubs, a feed of published laps.
- ⚠️ **Aria's own agent-support page** (reviewed by its developer 2026-10-12):
  - On its approval flow: "What is not verified: live allow and deny continuation… I have not confirmed end to end, on a live session, that the agent carries on correctly after Aria answers."
  - Gemini, Cursor and Copilot are observe-only.
  - OpenCode, Aider and others are "activity only" (guessed from processes).

### Where both leave room

| Gap | heyclicky | Aria | Belay's answer |
|---|---|---|---|
| Free forever, open source | ✗ (paid usage, closed) | ✗ (closed, paid tiers coming) | **MIT, no account, no servers** |
| Coding-agent supervision done properly | ✗ (general assistant) | Built, but self-described as **not verified end to end** | **Tested end to end on every release, with a public test matrix** |
| Costs nothing to run | ✗ (cloud voice and LLM) | Partly (bring your own key) | **On-device everything by default**; bring-your-own-key optional |
| A world and character people love | The cursor buddy is charming | An orb | **A climber with a whole climbing language** (§2) |
| Extensible by the community | ✗ | ✗ | **TypeScript plugin API** for holds, quests and rule packs (§9) |
| Haptics, physicality | Not mentioned | Not mentioned | **Trackpad haptics as a first-class design layer** (§7) |

---

## 1. Design principles (these come before any feature)

1. **Glance, don't open.** 80% of the value should come from the collapsed notch: shape, colour, motion, sound, haptic. Opening it is a choice, not a requirement.
2. **Felt, not just seen.** Every important moment has a matching **sound + haptic + motion** signature. You know the agent needs you without looking (§7).
3. **Never steal focus.** Belay never takes keyboard focus unless you invoke it. Cards appear; your typing keeps going to your editor.
4. **Fail open, never fail permissive.** If Belay crashes or is slow, agents fall back to their own terminal prompt. Belay never auto-allows anything you didn't set.
5. **Local by default.** Speech, summaries and stats all run on your Mac. Anything that would leave the Mac is opt-in and labelled.
6. **Calm by default, playful on purpose.** Personality shows up in *moments* (a catch, a summit), not constant chatter.
7. **One climbing language.** Every name, sound and animation comes from the belay world. It's our brand and it keeps the product coherent.

## 2. The brand world: climbing

| Climbing term | In Belay |
|---|---|
| **Belayer** | Belay, the character in your notch |
| **Climber** | Each running agent session |
| **Route** | A repo or project |
| **Pitch** | One agent task (prompt → done) |
| **Rope drop** | An agent needs you (approval or question) |
| **Catch / "falls caught"** | Belay intercepted a dangerous action |
| **Summit** | A task finished successfully |
| **Dangling** | Error, stuck or timed out |
| **Base camp** | The expanded notch home |
| **Logbook** | History, stats and the daily share card |
| **Holds** | Small notch widgets (music, timer, battery…) |
| **Side quests** | Things to do while agents climb (§6) |
| **Grades** | Your level (5.6 → 5.15), earned through use |
| **Chalk bag** | Shelf/clipboard for files and snippets |
| **Crag** | A shared community space (later) |

**Character:**
- Pixel-art belayer, about 18 px tall in the notch.
- States: idle (sitting, swinging legs), belaying (rope taut), rope-drop (stands up, rope falls), **catch** (braces, slides, holds), summit (flag), dangling (worried, looking down), sleeping (nothing running, night).
- Unlockable skins: helmet colours, a chalk-dust trail, seasonal gear.
- **No vendor logos.** Agents are coloured ropes with text labels.

---

## 3. Feature list

**Phases:**
- **v0.1** is the 2-week launch build (`build-plan.md`).
- **v0.2** is about 2–4 weeks after launch.
- **v0.3+** is later.
- ★ marks a Belay original (not in heyclicky or Aria).

### A. Agents: the core ("the rope")

| # | Feature | Detail | Phase |
|---|---|---|---|
| A1 | **Live climbers** | One coloured rope per running Claude Code or Codex session in the collapsed notch. Climbing (working) / taut (needs you) / flag (done) / dangling (error). Hover for repo, current action and elapsed time. | **v0.1** |
| A2 | **Rope-drop approval card** | Exact command, agent, repo, a plain-English one-line risk note. **Allow ↵ / Deny ⎋ / Always ⇧↵**. "Always" writes a scoped allow rule (Claude Code `updatedPermissions`). | **v0.1** |
| A3 | ★ **Catch a fall** | A local danger-rules engine (rm -rf, force-push, reset --hard, DROP/TRUNCATE, prod hosts, `curl\|sh`, writes outside the repo, secrets paths, chmod 777). Triggers the catch animation, a sound, **a strong haptic**, and a spoken warning. Counted in the Logbook. | **v0.1** |
| A4 | **Voice steer** | Push-to-talk: "yes / no / always / stop / no, *X* instead". "Instead" becomes a deny with your words as `message`, so the agent adapts. "Stop" becomes `interrupt`. Codex gets allow and deny-with-message only. | **v0.1** |
| A5 | **"What are my climbers doing?"** | A spoken and written status from hook events, using templates. No LLM needed. | **v0.1** |
| A6 | ★ **Verified-continuation badge** | Every release runs a public end-to-end test: a real Claude Code + Codex session → Belay answers → the agent continues correctly. The README shows a green matrix per agent version. **Directly answers Aria's admitted gap.** | **v0.1** (manual), v0.2 (CI) |
| A7 | **Jump to the climber** | Click a rope → focus the exact iTerm2 or Terminal.app window or tab (AppleScript). Ghostty, Warp and VS Code are best-effort. | v0.2 |
| A8 | ★ **Rope to the window** | When a climber needs you, Belay *draws* a rope from the notch to that terminal window's on-screen frame. It's our version of heyclicky's on-screen drawing, but grounded in real data (window bounds), with no vision model and no cost. | v0.2 |
| A9 | **Auto-mode watch** | When auto mode silently blocks something (`PermissionDenied` hook / OTel `classifier_verdict`), Belay shrugs and says so. A daily "auto-mode said no to 2 things" line. | v0.2 |
| A10 | **Summit summary** | When a pitch finishes: "Claude summited *billing-v2*: 3 files, tests pass, 14 min." Uses an on-device model where available (§8), otherwise a template. | v0.2 |
| A11 | **Undo last pitch** | Snapshot via a git stash or worktree before risky pitches; one-click revert. Aria has undo; ours is **free and open**. | v0.3 |
| A12 | **Replay (Logbook timeline)** | Step through a pitch: reads, edits, commands, your step-ins. Parsed from transcripts (unstable formats, so best-effort). | v0.3 |
| A13 | ★ **Spend & quota hold** | A small gauge of plan usage and limits (reads the same local data as ccusage). Belay warns *before* you hit a limit. | v0.3 |
| A14 | **More agents** | Gemini CLI, OpenCode, Cursor, observe-only at first. Be honest about it on an "agent support" page. | v0.3+ |

### B. Notch life: holds (widgets)

| # | Feature | Detail | Phase |
|---|---|---|---|
| B1 | **Now playing** | Track, artist and artwork in the collapsed notch when no climber needs you. Play/pause/skip, and a scrub bar in base camp. Spotify + Apple Music. | **v0.1** (basic) |
| B2 | ★ **Agent-aware music** | Music ducks (lowers volume) on a rope drop and comes back after you answer. Optional "flow playlist": music runs while climbers climb and pauses when everything summits. | v0.2 |
| B3 | **Chalk bag (shelf)** | Drag files or snippets into the notch to hold them; drag out to any app. Drop a file onto a climber's rope to paste its path into that session's next prompt (★). | v0.2 |
| B4 | **Clipboard history** | Last 20 copies; secrets-like strings auto-masked (★). | v0.3 |
| B5 | **Calendar hold** | Next meeting with a join button. ★ "Meeting in 5 min, 2 climbers still going" warns you before you leave agents running unattended. | v0.2 |
| B6 | **System HUD** | Volume, brightness, battery, and charging animations through the notch. | v0.3 |
| B7 | **Timers / focus** | Pomodoro whose breaks line up with agent summits (★). | v0.2 |
| B8 | **Camera-island + no-notch modes** | Works on notch Macs, the new camera-island MacBook Pro (heyclicky supports it), and as a floating island on external or no-notch displays. | **v0.1** (island fallback) |

### C. Voice and the assistant

| # | Feature | Detail | Phase |
|---|---|---|---|
| C1 | **Push-to-talk** | Hold a key (configurable; default ⌥Space or Fn). Waveform in the notch. On-device speech. | **v0.1** |
| C2 | **Spoken replies** | System TTS by default (free, offline). Pick a voice. Optional bring-your-own-key premium voices. | **v0.1** |
| C3 | **Talk over it** | Start talking and Belay stops speaking (heyclicky's "interrupt me anytime"). | v0.2 |
| C4 | **Command phrases** | "Pause music", "what's playing", "start a 25-minute timer", "how many falls today", "mute Belay for an hour". | v0.2 |
| C5 | ★ **Hand a prompt to a climber** | "Tell Claude in billing to also add tests." Belay queues it as that session's next prompt (needs Belay-launched sessions or a documented input path; see `feasibility.md` §4. **Verify before promising.**) | v0.3 |
| C6 | **Ask about your screen** | Hotkey + a question about what's on screen, like heyclicky. **Bring-your-own-key only** (vision costs money), clearly labelled as cloud. | v0.3+ |

### D. Drawing and pointing (our take on heyclicky's best idea)

| # | Feature | Detail | Phase |
|---|---|---|---|
| D1 | ★ **Rope to the window** | See A8. Real window geometry; no AI. | v0.2 |
| D2 | ★ **Highlight the risky line** | On a catch, Belay overlays a glow on the terminal region showing the dangerous command. | v0.3 |
| D3 | ★ **Diff spotlight** | After a summit, an overlay card next to the editor lists the changed files; click one to open it. | v0.3 |
| D4 | **Freehand pointing (assistant)** | Arrows and rings drawn by a vision model on bring-your-own-key, as in heyclicky. Optional, later. | v0.3+ |

### E. Feel: Mac-native polish (see §7 for the haptics spec)

| # | Feature | Phase |
|---|---|---|
| E1 | **Haptic vocabulary**: rope drop, catch, summit, allow-confirm, each with its own trackpad pattern | **v0.1** (catch + allow), v0.2 (full set) |
| E2 | **Sound pack**: soft carabiner click, rope zip, "whoa" catch, summit chime. Auto-mute while the asking terminal is focused, during calls, or in Focus modes. | **v0.1** |
| E3 | **Spring-physics notch**: the notch grows and shrinks from itself, never flashes black (heyclicky shipped the same fix), runs at 120 Hz on ProMotion | **v0.1** |
| E4 | **Respect Focus / Do Not Disturb**: only catches break through, configurable | v0.2 |
| E5 | **Reduce Motion & accessibility**: VoiceOver labels, Reduce Motion swaps animations for fades, high-contrast ropes | v0.2 |
| E6 | **Multi-display**: the island follows the display you're on (heyclicky shipped this); "working glow" on external monitors | v0.2 |
| E7 | **Shortcuts app actions & menu bar fallback**: "Belay: status", "mute", "approve latest" via App Intents | v0.3 |
| E8 | **Battery-light**: event-driven, no polling. Target <1% CPU while idle. | **v0.1** |

### F. Side quests: what you do while agents climb ★

The idea is that waiting on agents is dead time. Belay offers **small, optional, never-nagging** things to fill it. Each quest is a card that slides out of the notch when a climber has been working for more than N minutes and nothing needs you.

| # | Quest type | Example | Phase |
|---|---|---|---|
| F1 | **Body** | "Climbers are mid-pitch. Stand and stretch for 60 s?" (posture, water, eyes 20-20-20). A countdown with haptic ticks. | v0.2 |
| F2 | **Review the last summit** | "Codex summited 6 min ago. Skim the 3 changed files?" Opens the diff spotlight. Turns review debt into a quest. | v0.2 |
| F3 | **Inbox zero for agents** | "2 sessions done but not closed. Wrap them up?" | v0.2 |
| F4 | **Learn a hold** | One keyboard shortcut or Claude Code / Codex tip per day, taken from their official docs | v0.2 |
| F5 | **Rule tuning** | "You allowed `npm test` 9 times today. Make it 'Always'?" (cuts approval fatigue safely) | v0.2 |
| F6 | **Micro-break games** | A 30-second notch mini-game (e.g. rope-swing timing). Strictly optional, off by default. | v0.3 |
| F7 | **Community quests** | Weekly challenge ("summit 10 pitches with 0 risky allows"), via plugins | v0.3+ |

**Quest rules:**
- At most one quest card per 30 minutes.
- Never while a rope is dropped.
- Never during calls or Focus.
- One click dismisses it for the day.
- Quests earn **grade XP** (§G).

### G. Logbook, progress and sharing (the growth loop)

| # | Feature | Detail | Phase |
|---|---|---|---|
| G1 | **Daily log card** | A beautiful PNG: hours belayed, approvals, **falls caught**, longest pitch, summits. Copy, or open X with prefilled text. | **v0.1** |
| G2 | **Grades** | Climb from 5.6 to 5.15 through summits, catches and completed quests. Each grade unlocks a cosmetic (helmet, rope colour, chalk trail). | v0.2 |
| G3 | **Streaks** | "Days in a row with a summit". Optional, and never guilt-trips. | v0.2 |
| G4 | **Weekly logbook** | A Sunday recap card with charts: busiest route, the scariest catch, agent split. | v0.2 |
| G5 | **Profile card (local)** | A shareable "climber card" image. No server: it's rendered locally from your stats. | v0.3 |
| G6 | **Crag (optional community)** | Opt-in public profiles, leaderboards for falls caught. Needs a server, so later, and only if the brand takes off. | v0.3+ |

### H. Trust and setup

| # | Feature | Phase |
|---|---|---|
| H1 | One-click hook install with a **diff preview**; clean uninstall that restores the original file | **v0.1** |
| H2 | No network port: 0600 Unix sockets only (ADR 0006) | **v0.1** |
| H3 | "What Belay reads" page (in-app and on the site), in plain words. Aria has one; ours links straight to the source code. | **v0.1** |
| H4 | Guided Codex hook-trust step | **v0.1** |
| H5 | Auto-update via signed GitHub Releases (Sparkle or similar) | v0.2 |
| H6 | Zero telemetry by default; optional anonymous crash reports, opt-in | v0.2 |

### I. Ecosystem: what makes it a platform, not a feature

| # | Piece | Detail | Phase |
|---|---|---|---|
| I1 | ★ **Belay Plugins (TypeScript)** | The sidecar loads plugins that can add **holds** (widgets), **side quests**, **rule packs** (danger rules), and **voice commands**. Plugins declare permissions. A `create-belay-plugin` template. This is where the community joins in. | v0.3 |
| I2 | ★ **Rule packs** | Shareable YAML/TS danger-rule sets: "Postgres safety", "Kubernetes prod", "AWS no-delete". Community-curated in the repo. | v0.2 (format), v0.3 (marketplace = a GitHub folder) |
| I3 | **Skins** | Community character skins and sound packs (asset folders with a manifest) | v0.3 |
| I4 | **`belay` CLI** | `belay status`, `belay mute`, `belay log --today`, and a headless mode for Linux users without the app (no notch, terminal notifications) | v0.3 |
| I5 | **Docs site** | belay docs: install, agent support matrix, plugin API, rule-pack format, brand kit | v0.2 |

### J. Hands: Belay does tasks for you (see `oss-reuse.md` §2–3)

| # | Feature | Detail | Phase |
|---|---|---|---|
| J1 | **Engines, not logins** | Belay runs on what you already have: your installed `claude` CLI, your `codex` CLI (signed in with ChatGPT), a local model (Ollama/LM Studio), or your own API key. Belay never touches subscription credentials. | v0.2 |
| J2 | **Ask Belay to do it** | "Open my latest PR", "rename these screenshots", "summarise this repo". Belay hands the task to your agent engine, then supervises it with the rope + catch engine. | v0.2 |
| J3 | **Instant Mac actions (no AI)** | Open apps and URLs, browser tabs, Music/Spotify, Finder, timers, Shortcuts. Deterministic and free. | v0.2 |
| J4 | **Edit-before-it-happens cards** | Anything that sends, creates, deletes, pays or posts shows an editable rope-drop card first (pattern from Avo) | v0.2 |
| J5 | **Accessibility-tree app control** | Drive apps without an API (pattern from Samuel) | v0.3 |
| J6 | **Sandboxed computer use** | Risky or long jobs in a Cua VM or sandbox | v0.3+ |
| J7 | **Opt-in cloud connectors** | Composio-style app integrations, off by default | v0.3+ |

---

## 4. What we deliberately don't build

| Not building | Why |
|---|---|
| Our own cloud computer-use agent (heyclicky "drive", "Clickys") | Expensive and cloud-dependent. Instead, Belay's **Hands** (section J) delegate tasks to the user's own `claude`/`codex` engines and supervise them, with sandboxed computer use only in v0.3+. |
| Connected apps (Gmail, Meta Ads…) | Needs OAuth and servers, and breaks "no account, no servers" |
| Paid tiers, usage resets, referral-for-credits | We're free. Referral is replaced by the share card. |
| Teams/rooms/multiplayer in v0.x | Needs servers. Revisit only if the community asks loudly. |
| Windows | Mac-native feel is the point |
| Prompt sentiment analysis (Notchi) | Sends prompts to an API, and feels invasive |

## 5. v0.1 launch scope (the 2-week cut)

Taken from the tables above:
- **Agents:** A1–A6
- **Notch life:** B1 (basic), B8 (island fallback)
- **Voice:** C1, C2
- **Feel:** E1 (catch + allow), E2, E3, E8
- **Logbook:** G1
- **Trust:** H1–H4

Everything else is v0.2 and later.

**Added since `build-plan.md`:** B1 (basic now playing), E1 (two haptics) and E2 (sounds). They're cheap, demo well, and make the clip *feel* native. Budget half a day for them on Day 8 (alongside voice lines/sounds). If Day 8 slips, drop B1 first.

## 6. Side-quest design notes

- Quests are **context-aware**: they're generated from what your climbers are doing (summits waiting for review, repeated approvals, long sessions). Random wellness nags aren't the point.
- The tone is a friend at the crag, not a fitness app. Example: *"Long pitch. Shake out your arms?"*
- Every quest has a **skip forever** for its category.
- Measure success by quests completed per day per user (local count only). If it's under 0.3, cut the feature.

## 7. Haptics, sound and motion spec

**Haptics:**
- macOS exposes trackpad haptics through `NSHapticFeedbackManager`. Its patterns are generic, alignment and level-change.
- It only works on Force Touch trackpads, and is **only felt while a finger is on the trackpad**.
- **Design for that:** haptics confirm and accent. They never carry information alone, so every haptic has a sound and visual twin.
- Richer custom patterns are **UNVERIFIED**; prototype on Day 1 of the haptic work.

| Moment | Motion | Sound | Haptic |
|---|---|---|---|
| Rope drop (needs you) | Rope falls, the island widens 40% | Soft rope zip | 1× generic |
| **Catch** (danger) | Character braces and slides 6 px down, island flashes amber | "Whoa" + carabiner clank | **3× level-change in quick succession** |
| Allow | Rope pulls up, a green tick | Carabiner click | 1× alignment |
| Deny / steer | Rope slack, blue "sent back" | Low thunk | 1× generic |
| Summit | Flag pops, confetti of 4 pixels | Short chime | none (don't interrupt) |
| Quest card | Slides out at 60% opacity | None | None |

**Motion:**
- Springs only, no linear easing.
- Under 250 ms for everything except the catch (450 ms, because it's the moment).
- Respect Reduce Motion.

## 8. Free-by-design technology choices

| Need | Free/local option | Optional upgrade |
|---|---|---|
| Speech-to-text | Apple on-device speech recognition (`SFSpeechRecognizer`; the newer `SpeechAnalyzer` on macOS 26) | — |
| Voice out | `AVSpeechSynthesizer` system voices | Bring-your-own-key premium TTS |
| Summaries / "what's it doing" | Templates from hook data. Apple's on-device **Foundation Models** framework where available (macOS 26 + Apple Intelligence Macs). **UNVERIFIED on our target hardware; test before promising.** | Bring-your-own-key Claude or OpenAI |
| Now playing | AppleScript/ScriptingBridge for Music and Spotify (needs an Automation permission prompt). Apple's private MediaRemote route is unreliable on recent macOS (**UNVERIFIED**), so avoid it. | — |
| Share cards | satori (TS) in the sidecar | — |
| Agent hooks | Command hooks running the `belay-hook` shim to a 0600 Unix socket, for both agents (ADR 0006) | — |

**Licensing:**
- Fork Clicky (MIT) for scaffolding.
- **Don't copy Boring Notch or Notchi code (GPL-3).** Reimplement ideas, don't paste code.
- Belay ships under MIT.

## 9. Open questions to settle in week 1

1. Haptic pattern range on current Force Touch trackpads (prototype).
2. Whether the Apple Foundation Models framework is good enough for one-line summit summaries. If not, templates only.
3. Spotify AppleScript reliability on the current Spotify build.
4. Whether any documented path exists to send a *new prompt* into a running Claude Code or Codex TUI session (needed for C5). If not, C5 is limited to Belay-launched sessions.
5. Name and handle availability for "Belay" (GitHub, X, domain).
