# Belay: open-source code we can reuse, and how to use the AI subscriptions people already pay for

**Researched:** 2026-11-24.

**How it was checked:** every repo below was opened on GitHub. Licences come from the repo's `LICENSE` file or GitHub's licence metadata. Stars come from the repo page. Last-commit dates come from the repo's `commits.atom` feed. Anything not confirmed this way is marked **UNVERIFIED**.

**Scope:** what to borrow (with credit and licence compliance), and what users can legally plug in. **Tech stack and architecture are the next doc.** §7 only flags the Rust question.

---

## 1. MausBot (OpenMausBot): the "Grok Bot alternative"

| | |
|---|---|
| Repo | https://github.com/milind-soni/OpenMausBot (formerly OpenGrokBot; also called MausBot). Site: openmausbot.com |
| Licence | **Apache-2.0, except the `enterprise/` folder**, which is "source-available under its own license; delete that folder and what remains is the open-source edition" |
| Traction | **27,158 stars**; last commit **2026-11-23** |
| Stack | TypeScript (strict), React 19, **Electron**; ships for macOS (signed and notarized), Windows, Ubuntu and Fedora |
| What it is | "Your own team of AI bots, in a chat app." Every bot is "a real agent — Claude or Codex running locally", with its own personality, model, computer and connected apps. "Talk to them like contacts. Watch them work. Approve what matters." |

**How it uses existing subscriptions.** This is the key pattern. In MausBot's words:

> "Bots run on the `claude`, `codex`, and `grok` CLIs installed on your own machine — your existing logins and subscriptions, no new accounts, no proxy in the middle."

**How it works:**
- "One small harness server on `127.0.0.1` owns every agent process. Transcripts, keys, and events live in `~/.openmausbot`."
- **Hands:** "a cloud Linux desktop, an isolated Local VM, or… your own computer, plus 500+ apps through Composio." Host control on macOS is opt-in. It bundles "Cua Driver components" (§3).

**What to take for Belay:**
- **The engine layer.** Spawning and supervising the user's own `claude` and `codex` CLIs, with a configurable binary path. This is exactly how Belay gets "use the subscription you already pay for" without violating terms (§2).
- **The harness-server idea.** One local process owns all agent processes. Belay's sidecar plays the same role.
- **Approval-card UX ideas.**

**What not to take:**
- Anything under `enterprise/`.
- Its Composio cloud integration as a default. It breaks Belay's "no servers" promise; offer it only as an opt-in.
- Its chat-app shape. Belay is a notch companion, not a messenger.

**Apache-2.0 obligations if we copy code:**
- Keep the licence and any `NOTICE` text.
- Mark modified files as changed.
- Include the Apache licence text for those files. Apache-2.0 code can live inside an MIT-licensed project as long as those files keep their Apache terms.
- Also honour its upstream dependency licences (it lists MIT, SIL OFL 1.1 and MPL-2.0 components).
- The README notes it is "not affiliated with… xAI; 'Grok' is a trademark". We'd say the same.

## 2. Using the user's existing AI subscription (the legal reality)

This decides the architecture, so it comes first.

### Claude (Anthropic)

Source: Claude Code "Legal and compliance", https://code.claude.com/docs/en/legal-and-compliance.md, read 2026-11-24.

- **Not allowed:**
  > "Anthropic does not permit third-party developers to offer Claude.ai login into their own applications, or to route requests through Free, Pro, Max, or Ultra plan credentials on behalf of their users. Moreover, developers may not collect, store, or intermediate Claude.ai credentials or session tokens."

  Also: developers "including those using the Agent SDK, should use API key authentication".
- **Allowed:**
  > "Nor does it prevent an end user from signing in to the unmodified Claude Code binary with their own Claude subscription."
- **Conditions for products that run Claude Code:** "preinstalling or running Claude Code in your products… requires agreeing to our Commercial Terms of Service". The binary "must not be modified", and "Each end user must authenticate with their own… Claude subscription plan credentials".
- **Branding:** you may say your product "runs Claude Code", but you "can't use the Claude Code or Anthropic names or logos as part of your own product… name… or logo".

**Rules for Belay:**
- ✅ **Drive the user's own installed, unmodified `claude` CLI.** They sign in through Anthropic's own flow, and Belay never sees tokens. This is MausBot's model.
- ❌ Never read `~/.claude` credentials. Never call the API with a plan token. Never build a "Sign in with Claude" button.
- ⚠️ **Gray area:** whether a free app that *launches* the user's own Claude Code install counts as "running Claude Code in your products", which would need the Commercial Terms. **Ask Anthropic or read the Commercial Terms before launch.** Supervising sessions the user starts themselves (v0.1) is clearly fine. Launching them (v0.2 "Hands") is where this applies.
- For anything Belay calls *directly* (e.g. a summary model): **bring your own API key** only.

### ChatGPT / Codex (OpenAI)

Source: https://learn.chatgpt.com/codex/sign-in-with-chatgpt, read 2026-11-24.

- **Sign in with ChatGPT is a partner program:**
  - "ChatGPT Go, Plus, Pro, and Business subscribers can also choose to use their ChatGPT plan for AI requests."
  - Developers must **request a client ID**.
  - Partners with plan usage, as listed: Amp Code, Conductor, Dactyl, Devin, Hermes Agent, Hyperagent, Kilo Code, Lovable (coming soon), Notion, Vercel, Vorflux, Warp.
  - Users set weekly caps per app: "An app's limit is a cap, not a separate allowance."
- **Rules for Belay:**
  - ✅ **Now:** drive the user's own `codex` CLI, which they signed into with ChatGPT. Use `codex exec` or the documented Codex app-server (`feasibility.md` §2c).
  - 🟡 **Later:** apply for a Sign in with ChatGPT client ID. If approved, Belay can make direct plan-billed requests (e.g. voice-assistant answers) with no API key. Approval criteria and timeline are **UNVERIFIED**.

### Grok, local models, everything else

- **Grok:** MausBot drives a `grok` CLI. Its install, auth and terms are **UNVERIFIED**; research them before supporting it.
- **Local and free:** Ollama, LM Studio, or any OpenAI-compatible server. Avo and OpenClicky both do this (§3), and it fits "free forever".
- **Bring your own key:** OpenAI, Anthropic, OpenRouter, Groq, xAI (Avo's provider table lists these).

**Product rule:**
- Belay has **"engines", not logins**.
- Engine 1 is your `claude` CLI, engine 2 your `codex` CLI, engine 3 a local model, engine 4 your own API key.
- Belay never holds subscription credentials.

## 3. "Talk to me, open my apps and browser, do tasks": open-source pieces

| Project | Licence | Stars / last commit | What's reusable |
|---|---|---|---|
| **OpenClicky**: https://github.com/prasanthsasikumar/openclicky | **MIT** | 57 | The closest open-source match to heyclicky. "A pointer flies out of the notch and lands on the answer on your screen." **Draw-to-explain** (hand-drawn diagrams and 3D models drawn while it talks). On-device dictation via Apple's recogniser. Tasks handed to a **Codex agent**. A Linux client. Derived from Clicky. **Our best source for heyclicky-style drawing and pointing.** |
| **Clicky**: https://github.com/farzaa/clicky | **MIT** | 8,062 | Cursor-buddy overlay, push-to-talk, screen capture scaffolding (from `landscape.md`) |
| **Avo**: https://github.com/Stu1124/avo | **MIT** | 1 | Notch voice agent that "acts through your own apps: Messages, Gmail, Google Calendar, Reminders, Notes, Finder, Spotify, Google Drive, Claude Code and Codex, plus any MCP server". **"Anything that sends, creates or deletes something shows you an editable card first."** On-device speech; "Hey Avo" wake word on macOS 26; any OpenAI-compatible model. *Low stars, but well specified. A source of patterns, not proven code.* |
| **Samuel (screen-voice-agent)**: https://github.com/sambuild04/screen-voice-agent | **MIT** | 41 / 2026-10-22 | Wake word, sub-500 ms voice. "Drives any app" via the **Accessibility tree** with a visual fallback. Consent cards for sensitive permissions. Uses OpenAI models. |
| **Cua**: https://github.com/trycua/cua | **MIT** | **32,829** / 2026-11-23 | "Open-source drivers, cross-OS sandboxes" for computer use. MausBot packages its driver. **The serious option for computer use and VMs.** |
| **Codex CLI**: https://github.com/openai/codex | **Apache-2.0** | **136,245** / 2026-11-23 | The agent we supervise and also use as "hands". Reading its source shows exactly how hooks and app-server behave. |

**Recommended "hands" strategy (cheapest and safest first):**

1. **Delegate to the user's agents.** "Open my PR in the browser" or "rename these files" becomes a task for the user's `claude` or `codex` CLI, which already runs shell commands (`open -a Safari …`, AppleScript). **Belay supervises it with its own rope and catch engine.** Belay already does exactly this, which is a strong brand fit: *"Belay is the safety rope for anything your AI does on your Mac."*
2. **Direct Mac actions without AI:**
   - `open -a`, URL schemes, AppleScript or ScriptingBridge for Music, Spotify, Finder and Safari/Chrome tabs.
   - App Intents and Shortcuts.
   - Instant, free and deterministic. Avo's app list is the menu to copy.
3. **Accessibility-tree control** for apps with no API (Samuel's approach). v0.3.
4. **Cua sandboxes or VMs** for risky or long jobs. v0.3+.
5. **Composio or other cloud connectors:** opt-in only, never default.

**Safety rule borrowed from Avo:** every action that **sends, creates, deletes, pays or posts** shows an editable card first, and that card is Belay's rope-drop card. One approval UX for coding agents and computer use alike.

## 4. Notch and UI building blocks

| Project | Licence | Stars / last commit | Use it? |
|---|---|---|---|
| **DynamicNotchKit**: https://github.com/MrKai77/DynamicNotchKit | **MIT** | 485 / 2026-02-18 | **Yes.** A Swift package that shows SwiftUI content from the notch, with a floating-window style for Macs without a notch. Saves building the notch window from scratch. |
| **notchtransition**: https://github.com/kovs705/notchtransition | **MIT** | not captured | Maybe, for animation reference |
| **Perch**: https://github.com/asafofer/perch | **MIT** | 31 / 2026-11-16 | Yes, as a reference for notch + agent-prompt answering |
| Boring Notch: https://github.com/TheBoredTeam/boring.notch | **GPL-3.0** | 11,450 | **Don't copy code** (it would force Belay to become GPL). Study the UX only. |
| Notchi: https://github.com/sk-ruban/notchi | **GPL-3.0** | 1,051 | **Don't copy.** Mascot and sound ideas only. |
| DynamicNotch (jackson-storm): https://github.com/jackson-storm/DynamicNotch | **GPL-3.0** | 681 / 2026-11-22 | **Don't copy.** |
| Notchify (fr0sty1122) and NotchFlow (zzfadi) | — | **Repo pages returned 404** | **UNVERIFIED** (seen only in search results); skip |

## 5. Feature → source map

| Belay feature (`features.md`) | Borrow from | Licence |
|---|---|---|
| Notch window / island fallback (A1, B8) | DynamicNotchKit | MIT |
| Push-to-talk, overlay scaffolding (C1) | Clicky | MIT |
| Pointer from the notch, draw-to-explain (D1–D4) | OpenClicky's draw stage | MIT |
| On-device dictation (C1) | OpenClicky / Avo (Apple recogniser) | MIT |
| Engines: drive the user's `claude`/`codex`/`grok` CLIs | MausBot engine layer | Apache-2.0 |
| Local harness server owning agent processes | MausBot | Apache-2.0 |
| "Edit before send/delete" action cards | Avo (pattern) | MIT |
| App actions: Messages, Calendar, Spotify, Finder… | Avo (tool list) | MIT |
| Accessibility-tree app control (v0.3) | Samuel | MIT |
| Computer-use sandbox / VM (v0.3+) | Cua | MIT |
| Agent hook semantics | Codex source + docs; Claude Code docs | Apache-2.0 / docs |
| Mascot, sound, notch UX *ideas only* | Notchi, Boring Notch | GPL: **ideas only, no code** |

## 6. Licence and credit plan (do this from Day 1)

1. Belay is **MIT**. Apache-2.0 and MIT code can be included; **GPL code cannot**.
2. Add `THIRD_PARTY_NOTICES.md`: every borrowed project, its licence text, its copyright line and a link.
3. Keep original copyright headers in copied files and add "Modified by Belay contributors" lines.
4. Add an in-app **Credits** screen (Settings → About → Credits) and a README "Built on" section.
5. Copy **specific modules with clear boundaries**, not whole apps. Record the source commit hash for each one in `THIRD_PARTY_NOTICES.md`.
6. Trademarks: plain text like "works with Claude Code and Codex" is allowed; no vendor names or logos in Belay's branding (Anthropic's rule above).
7. Don't use the Apache-licensed code's project names or marks ("MausBot") for Belay features.

## 7. Two things to settle in the tech-stack doc (next)

**Rust: not settled here.**
- **For it:** performance, small binaries, one core for Mac/Windows/Linux, and Tauri for cross-platform shells.
- **Against it:**
  - It's a language you don't know, in a 2-week window.
  - The best reusable code is **TypeScript** (MausBot, Electron) and **Swift** (Clicky, OpenClicky, DynamicNotchKit, Avo), not Rust.
  - Notch-level polish (haptics, island, on-device speech) needs native Swift on the Mac regardless.
- **Codex itself is the Rust reference** to study. Its language mix was **not captured on its repo page this pass (UNVERIFIED)**.
- The next doc will weigh: a **Swift shell + TS core** now, with a **Rust core** later behind the same local protocol. Versus Tauri from day one.

**Scope warning:**
- "Do all the tasks for me" (computer use) is a second product on top of agent supervision. MausBot has 27k stars and a whole team-of-bots app around it.
- **Keep v0.1 as planned** (supervision + voice + notch life).
- Phase "Hands" in as v0.2, using **strategy 1 only**: delegate to the user's own agents, supervised by Belay. Cua and Accessibility control come in v0.3+.
