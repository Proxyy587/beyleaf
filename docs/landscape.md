# Belay: competitive landscape

**Question:** Which tools already let a developer watch, approve, steer, replay or audit a coding agent's session?

**Research date:** every page below was read on **2026-11-23** unless a different date is given. Prices are as shown on that date.

## How this was gathered

- **Methods:** pages were fetched directly with `curl` and stripped to text. GitHub star counts were read from each repo's own HTML page. Commit and release dates came from GitHub's public `commits.atom` and `releases.atom` feeds. Weekly npm downloads came from `api.npmjs.org` (week of 2026-11-16 to 2026-11-22).
- **GitHub REST API:** unreachable. It hit the unauthenticated rate limit (60/hour) on the first batch, and `gh` was not logged in, so stars come from the page HTML only.
- **Not reached:**
  - Product Hunt and X/Twitter were not loaded directly.
  - Reddit refused access: HTTP 403 on anonymous JSON, and the search tool blocks reddit.com.
  - The VS Code Marketplace was not loaded. The one VS Code tool listed below (Agent Flow) was verified through its GitHub repo instead.
  - Anything seen only in a search snippet is listed in the last section as **UNVERIFIED**, with no claims attached.
- **Reading star counts:**
  - Stars measure attention, not use.
  - Closed-source products (Aria, NotchNook, AgentPeek, Runnock, Conductor) have no comparable public figure.
  - Any user count quoted for them is the **vendor's own claim**.

---

## 1. Direct hits: watch + approve (+ steer/replay) from outside the agent

These overlap with the core Belay idea almost one for one.

| Tool | Link | What it actually does (from its own page) | Platform | Price | Traction | Last release / activity |
|---|---|---|---|---|---|---|
| **Aria** | https://joinariapp.com | A notch app. Shows every agent session live. **Approve or deny** Claude Code and Codex requests, **steer mid-run** ("the instruction goes straight back to the session that asked"), **replay every step** as a "lap". Also a review card with risk flags (auth code, secrets-like files, lockfiles, CI config, big deletions, new network calls), undo, overlap warnings between agents, a team budget guard, a team audit log, and approval by text message. Gemini CLI, Cursor and Copilot are observe-only. | macOS 14+, Apple Silicon, native | Free beta. Pro $15/mo ($12/mo annual). Team $25/seat/mo ($20 annual), minimum 2 seats. Max planned at $30, not on sale. Paid plans "open soon". Approve/undo/review/stop are "free forever". (https://joinariapp.com/pricing) | No public metric. Solo developer ("Written by Arush, the developer"). | 0.2.5 on **2026-11-22**; six releases between Nov 19 and Nov 22 (https://joinariapp.com/updates) |
| **NotchNook Pro** (lo.cafe) | https://lo.cafe/notchnook | A general notch utility (music, calendar, files) that now advertises **"Approve Claude Code and Codex from the notch, without switching windows."** | macOS 14.6+, Apple Silicon (Pro) | $19 lifetime, **$9.50 Black Friday** until Nov 30, or $3/mo. 48-hour trial. | No public metric | Not stated on page |
| **AgentPeek** | https://agentpeek.app | "Monitor supported coding agents from the Mac notch and menu bar. View sessions, answer supported prompts, track available usage, and manage local dev servers." Claims to recognise 26 coding agents. | macOS, native | 3-day trial, then one-time license **from $14.99** | No public metric | Not stated on page read |
| **Runnock** | https://runnock.com | "Your notch, now a status island." Shows working, needs-you, done and failed states. "When Claude Code, Codex and others ask for permission, the prompt…" can be answered from the notch. | macOS 26+, Apple Silicon | One-time purchase (amount not on the page I read) | No public metric | Not stated |
| **Perch** | https://github.com/asafofer/perch | "See when Claude Code, Codex, OpenCode or pi need you, and answer from the Mac notch. Free, open source, local-only." | macOS, native, OSS | Free | **31 stars** | Perch 0.5.6, **2026-11-16** |
| **Notchi** | https://github.com/sk-ruban/notchi | "notch app for claude code & codex" | macOS, native, OSS | Free | **1,051 stars** | v1.3.1, **2026-11-22** |
| **Claude Control** | https://github.com/sverrirsig/claude-control | "macOS desktop dashboard for monitoring and managing multiple Claude Code sessions" | macOS desktop | Free, OSS | **139 stars** | v0.19.0, 2026-09-07 |
| **claude-code-monitor** (bruceyxli) | https://github.com/bruceyxli/claude-code-monitor | "Real-time dashboard for monitoring Claude Code sessions with remote approval" | Web | Free, OSS | 13 stars | v1.7.0-beta.3, 2026-05-05; last commit 2026-04-11 (likely stale) |
| **claude-code-monitor** (onikan27) | https://github.com/onikan27/claude-code-monitor | "CLI + Mobile Web UI with QR code access, terminal focus switching (iTerm2, Terminal.app, Ghostty). macOS only." | CLI + web, macOS | Free, OSS | **315 stars** | v1.3.1, 2026-01-29 (stale) |
| **claude-view** | https://claudeview.ai | "The observability layer for Claude Code. Monitor agents, track spend, approve actions — from your browser or phone." Installs with `npx` or a curl script, and also ships as a Claude Code plugin. | Local web app | "Get Started Free"; there is a pricing page I did not open | npm `claude-view`: **376 downloads/week**. I could not identify the GitHub repo, so stars are **UNVERIFIED**. | "Now in public beta" |
| **Anthropic Remote Control** (official) | https://code.claude.com/docs/en/remote-control.md | Connects claude.ai/code or the Claude iOS/Android app to a **local** Claude Code session. Has an option to "Push when actions required" "for permission prompts and questions". "Claude Code keeps permission prompts and `AskUserQuestion` questions open until you answer them." | Any device; Claude Code only | Included in Claude plans; research preview | Ships with Claude Code (npm `@anthropic-ai/claude-code`: **22,171,378 downloads/week**) | Current docs |

**Reading of this table:**

- At least **seven maintained products** already approve Claude Code and Codex prompts from outside the terminal: Aria, NotchNook Pro, AgentPeek, Runnock, Perch, Notchi, and Anthropic's own Remote Control.
- Four of them sit in the macOS notch specifically.
- One of them (Aria) also covers steering, replay, team rooms, budget guards and an audit log.
- Aria's own homepage reads like a feature-complete version of the Belay pitch.

## 2. Status, notification and menu-bar tools (watch only, or notify only)

| Tool | Link | What it does | Price | Stars | Last activity |
|---|---|---|---|---|---|
| Claude Status Bar | https://github.com/m1ckc3s/claude-status-bar | Menu bar status indicator for Claude Code | Free | **738** | v0.4.5, 2026-09-18 |
| Nudgy | https://github.com/Hamma111/nudgy | Menu bar app that "notifies you when AI coding agents (Claude Code) finish tasks, need permissions, or ask questions" | Free | 12 | v0.6.3, 2026-09-03 |
| ClaudeDot | https://github.com/poorfish/ClaudeDot | Menu bar status monitor for Claude Code | Free | 13 | v2.0.0, 2026-04-10 |
| AgentPulse | https://github.com/fanook/agentpulse | Menu bar: "see every session at a glance, get pinged when one needs you, jump to the right terminal" | Free | 0 | v0.1.2, 2026-04-14 |
| notch-agents | https://github.com/rob-balfre/notch-agents | "Native macOS notch overlay showing live Codex and Claude agent status" | Free | 2 | last commit 2026-03-30 |
| agentNotch | https://github.com/Kumario1/agentNotch | Notch app (no description on repo page) | Free | 2 | last commit 2026-07-10 |
| NotchPal | https://github.com/simonveprek/NotchPal | Notch app; what it does is **UNVERIFIED** (description not read) | Free | 0 | 1.1.1, 2026-07-29 |
| notchy | https://github.com/bones7456/notchy | Notch app; what it does is **UNVERIFIED** (description not read) | Free | 18 | v1.5.1, 2026-11-13 |
| Huginn | https://github.com/tohuw/huginn | "A local-only AI agent activity console", with a menu bar helper and a local web app (author's Show HN text, 2026-07-19, https://news.ycombinator.com/item?id=48970488) | Free | 1 | last commit 2026-09-10 |
| agenthud | https://github.com/neochoon/agenthud | Claude Code TUI dashboard for parallel sessions and subagents, with an LLM daily digest | Free | 19 | last commit 2026-10-30 |
| AI Agent Session Center | https://github.com/coding-by-feng/ai-agent-session-center | Dashboard for Claude Code + Codex: live terminals, status alerts, prompt queues | Free | 96 | last commit 2026-11-23 |

## 3. Replay, audit and observability (after the fact or live)

| Tool | Link | What it does | Price | Stars / downloads | Last activity |
|---|---|---|---|---|---|
| **Agent Flow** | https://github.com/patoles/agent-flow | "Real-time visualization of Claude Code agent orchestration." A VS Code extension, per its Show HN (2026-03-26, https://news.ycombinator.com/item?id=47528814). | Free | **1,811** | last commit 2026-11-20 |
| **Agents Observe** | https://github.com/simple10/agents-observe | "Real-time observability of claude code sessions & multi-agents" | Free | **737** | last commit 2026-09-04 |
| **claude-trace-replay** | https://github.com/harrylettering/claude-trace-replay | "An open-source trace viewer for Claude Code sessions" | Free | 265 | last commit 2026-08-29 |
| **claude-replay / agent-replay** | https://github.com/tanghong123/claude-replay | "read-only replay, live monitoring and search for coding-agent sessions (Claude Code, Codex, Qoder). Rust TUI + local web UI." | Free | 3 | last commit 2026-11-23 |
| **Claudoscope** | https://claudoscope.com | "Free, open-source Claude Code session viewer and visualizer for macOS. Browse every transcript with per-message cost, replay sessions on a timeline, catch leaked secrets. 100% local." | Free | GitHub repo not identified, so stars **UNVERIFIED** | Not stated |
| **Watchtower** | https://github.com/fahd09/watchtower | Local proxy that records all API traffic between Claude Code / Codex CLI and their APIs, with a web dashboard | Free | 69 | last commit 2026-10-17 |
| **ccusage** | https://github.com/ryoppippi/ccusage | Cost and token usage reporting from local logs | Free | **19,557**; npm **226,118/week** | v20.1.0, **2026-11-23** |
| Claude Code OpenTelemetry (official) | https://code.claude.com/docs/en/monitoring-usage.md | Built-in OTel events, including `tool_decision` with `classifier_verdict` (the auto-mode verdict) and `safety_event` | Free | — | Current docs |

## 4. Orchestrators: run many agents (the "run more" camp Belay is positioned against)

These matter because most of them also include watch, review and approve surfaces.

| Tool | Link | What it does | Price | Traction | Status |
|---|---|---|---|---|---|
| **Conductor** | https://conductor.build | Runs Claude Code, Codex, Cursor and OpenCode agents in parallel; cloud sandboxes; multiplayer; macOS, iOS and API | Not on the page read | "Trusted by 100k+ builders" (**vendor claim**) | **"Conductor is joining Meta"** (https://conductor.build/announcement, undated on page). The announcement says Conductor Cloud "will shut down over the next few weeks" and also says "Plans have changed! We'll still be developing Conductor"; the page contradicts itself. Changelog lists 0.98.0 on **2026-11-20**. |
| **Vibe Kanban** | https://vibekanban.com | Kanban board over parallel agents; diff review and commenting; worktrees | Free/OSS | **28,793 stars**; npm **11,180/week** | Company (bloop) **shut down 2026-04-10**. Project is now community-maintained (https://vibekanban.com/blog/shutdown). Release v0.1.46 on 2026-11-15. |
| **Crystal → Nimbalyst** | https://github.com/stravu/crystal, https://nimbalyst.com | Crystal ran parallel Claude Code/Codex sessions in worktrees. Repo now says "(Crystal is now Nimbalyst)". | Free | Crystal **3,128 stars** | Crystal's last release was 0.3.5 on 2026-02-26 (abandoned). Nimbalyst is live. |
| **Sculptor** (Imbue) | https://imbue.com/sculptor | "Run multiple coding agents in safe containers and instantly see their changes" | Not stated on page read: **UNVERIFIED** | **285 stars** | sculptor-v0.50.0, **2026-11-17** |
| **Superset → Paradev** | https://superset.sh | "Open-source workspace for Claude Code, Codex, and any agent" | Not read | Site shows "16.5k" (GitHub counter **on vendor site**, not verified on GitHub). Site says "we raised an $11.5M seed". | Active |
| **opcode** (formerly Claudia) | https://github.com/getAsterisk/opcode (now under winfunc/opcode) | GUI for Claude Code: manage sessions, background agents | Free | **22,462 stars** | last commit 2026-11-06; last release v0.2.0 on 2025-09-02 |
| **CloudCLI / Claude Code UI** | https://github.com/siteboon/claudecodeui | Web and mobile UI for Claude Code, OpenCode, Cursor CLI and Codex | Free | **14,737 stars** (npm `@siteboon/claude-code-ui` only 677/week; it is mostly installed another way) | CloudCLI UI v1.37.9, 2026-11-16 |

## 5. Named items from the brief

| Name | Exists? | What it is | Relevant to Belay? |
|---|---|---|---|
| joinariapp.com | Yes | **Aria**. See section 1. | **The closest competitor found.** |
| heyclicky.com | Yes | "an ai buddy for your mac or windows pc. ask out loud and it sees your screen, teaches you any app and runs agents for you." By Farza. Claims "80,000+ happy users" (**vendor claim**). Free tier; Pro at **$16/mo** with the yearly toggle active (-20%). The monthly price was not captured: **UNVERIFIED**. OSS predecessor https://github.com/farzaa/clicky has **8,062 stars** (v2 released 2026-04-07; last commit 2026-10-28). | **No.** It is a voice/screen assistant, not an agent supervisor. Relevant only as proof that a Mac-native AI overlay can get distribution. |
| Conductor | Yes | Section 4 | Orchestrator; joining Meta |
| Vibe Kanban | Yes | Section 4 | Orchestrator; company dead, OSS alive |
| Crystal | Deprecated | Section 4 | Replaced by Nimbalyst |
| Sculptor | Yes | Section 4 | Orchestrator, active |
| Terragon | **Shut down** | terragonlabs.com's only content is the meta description "Information about the Terragon shutdown on February 9th, 2026." | Dead |
| Charlie (Charlie Labs) | **Shutting down** | Site banner: "Charlie is shutting down." Blog post dated 2026-09-20 says it "will remain available until October 5, 2026". It was "always-on AI processes" (daemons) across Slack, Linear and GitHub. | Dead |
| NotchNook | Yes | Section 1. **Now approves Claude Code and Codex.** | Direct competitor, with an existing paid user base |
| Boring Notch | Yes | https://github.com/TheBoredTeam/boring.notch: "Not so boring notch That Rocks". General notch utility. **11,450 stars**; nightly build 2026-11-23. I did not find agent features in the repo description. Whether it has any is **UNVERIFIED**. | Adjacent: a free OSS base someone could add agent features to |
| DynamicLake | Yes | https://www.dynamiclake.com: paid "Dynamic Island" for Mac, with a plugin marketplace. The homepage text I read mentions no coding-agent features. | Adjacent only |

## 6. UNVERIFIED leads (seen in search results only; not opened, not cited as fact)

- Vibe Notch (sourceforge mirror)
- Chimlo (Product Hunt)
- "Claude Pulse" (XDA article)
- "Skipper"
- Grith, syscall-level agent supervision. Known only from an author's HN comment, https://news.ycombinator.com/item?id=49610009; product page not opened.
- cc-audit-log (reported archived)
- Universal Session Viewer
- Session Lens (Open VSX)
- claude-devtools
- agent-monitor (CryoSkyd)
- agent-dashboard (bjornjee)
- agentsdash
- agentmap
- notch-mcp (from a dead HN post)
- SKI voice harness (dead HN post)
- Several dev.to "approve from your phone" write-ups

The pattern in this list matches the verified tables: a long tail of small free tools doing the same thing.

## Summary

- **The "watch + approve from outside the terminal" layer is saturated.** It has:
  - the agent vendor's own feature (Remote Control with push for permission prompts),
  - an established paid notch app (NotchNook Pro, $9.50–$19 one-time),
  - two paid notch-native specialists (AgentPeek from $14.99, Runnock),
  - a feature-maximal free beta (Aria), and
  - at least ten free OSS tools.
- **Replay/audit is also crowded but shallower.** Most tools are viewers. Aria (review card with risk flags) and Claudoscope (secret detection) go furthest toward risk-focused audit.
- **The business side is grim.** Vibe Kanban's company shut down while it had nearly 29k stars, saying "the vast majority are free users and we couldn't find a business model". Terragon and Charlie shut down. Conductor was absorbed by Meta.
