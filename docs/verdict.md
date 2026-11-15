# Belay: verdict

**Date:** 2026-11-23

**Inputs:** `landscape.md`, `pain.md`, `feasibility.md` (same folder).

## Call: **KILL** Belay as conceived

The brief's own rule: *"If 3+ maintained tools already cover this, say KILL plainly."*

**KILL.** More than three maintained tools already let a developer watch, approve and steer Claude Code and Codex from outside the terminal. Each of these had a release or update in the last few weeks, or is a first-party feature:

1. **Aria** (joinariapp.com). Notch app. Watch, approve, steer, replay, undo, review with risk flags, team audit, budget guard. Free beta; Pro $15/mo. Release 0.2.5 on 2026-11-22. **It is essentially Belay, already built, already free.**
2. **NotchNook Pro**. An established paid notch app that now advertises "Approve Claude Code and Codex from the notch". $19 lifetime ($9.50 on Black Friday).
3. **AgentPeek**. Notch/menu-bar "Agent Command Center", 26 agents, answers prompts. From $14.99 one-time.
4. **Runnock**. Notch status island that answers permission prompts. One-time purchase.
5. **Perch** (free OSS, 0.5.6 on 2026-11-16) and **Notchi** (free OSS, 1,051 stars, v1.3.1 on 2026-11-22).
6. **Anthropic Remote Control**. First-party: approve Claude Code permission prompts from the phone, with push notifications.

Replay and audit has its own set: Agent Flow (1,811★), Agents Observe (737★), claude-trace-replay (265★), Claudoscope, Aria laps.

## Why the market itself argues against it, beyond the competition

- **The platform is removing the job.** Since 2026-08-07, auto mode is the **default** in Claude Code for Pro, Max, Ultra and Team. Anthropic's stated reason is that humans approve 97% of prompts and caught 13.6% of dangerous commands in its tester study. That is vendor data, but it is the vendor's strategy, and the vendor controls the surface. Approval UIs are becoming a niche for people who opt out of auto mode.
- **Monetisation has failed for better-funded teams in this exact space:**
  - **Vibe Kanban**, about 29k stars, shut its company on 2026-04-10: "the vast majority are free users and we couldn't find a business model".
  - **Terragon** shut down on 2026-02-09.
  - **Charlie** shut down in October 2026.
  - **Conductor** (claims 100k+ builders) is "joining Meta".
- **The pain is real but cheap to self-solve.** Most dated complaints come from developers who then built their own free tool. The GitHub issues asking for this have 0–3 reactions. No evidence of willingness to pay was found (`pain.md`).
- **Your constraints point the wrong way.**
  - The surviving paid products win on **native macOS presence** (notch, menu bar, hotkeys, notarized install).
  - You have no Swift experience and 2–4 weeks.
  - A TypeScript web version lands in the free-OSS tier (claude-code-monitor, claude-view, Agents Observe, CloudCLI), where no one makes money (`feasibility.md` §4).
- **Critics in the target audience reject the premise.** The top reply on a 317-point HN thread: the fix for supervising too many agents is "do less parallel stuff (and provide stronger attention)", not more tooling.

## Is there a narrowest unserved slice?

I looked for one honestly. The only candidate that survived the search:

### Candidate: an "auto-mode audit" CLI for Claude Code

**What it is:**

- A TypeScript CLI that answers one question after the fact: *"What did auto mode let my agent do this week, and what did it block?"*
- It would be built on the **documented** OTel `tool_decision` event (`classifier_verdict`) and `safety_event`, with the transcript's `permissionDecision` field (undocumented) as a fallback.
- Output is a short risk-ranked digest: destructive commands, network calls, writes outside the repo, secrets-like paths, blocked attempts, and per-session counts.
- A local static HTML report, with no daemon and no approval loop.

**Why it might be unserved:**

- Auto mode became the default only on 2026-08-07.
- The official surface is raw OTel events that most solo developers will never wire up.
- In this pass I found **no tool whose main job is auditing auto-mode decisions.** Aria's review card and Claudoscope's secret detection are adjacent but per-session and not classifier-centric.

**Why I still would not call it a business:**

- **Demand evidence is essentially zero.** I found no complaint asking for it. The closest is an HN commenter (2026-11-08, https://news.ycombinator.com/item?id=50411010) suggesting Claude Code "run auto mode classification in manual mode and tell the user the result". That is one comment, and it asks the **vendor** to build it.
- **Anthropic owns the data and can ship this as a `/` command.** The same happened to "approve from phone", which became Remote Control.
- **Aria is moving fast** (six releases in four days) and already has review, risk flags and a team audit log. Adding classifier-verdict audit is a small step for them.
- **Codex has no equivalent documented verdict stream**, so the tool is Claude-Code-only.
- **Searches for this specific gap were thin:** one web search plus three HN searches. Treat "unserved" as **UNVERIFIED-leaning-plausible**, not established.

**Fits 2–4 weeks for one TypeScript developer?** Yes, comfortably:

- Week 1: OTel receiver and transcript parser.
- Week 2: risk rules and HTML report.
- Weeks 3–4: Codex rollout support (zstd) and polish.

The problem is not buildability. It is that nobody has asked for it and the platform can absorb it.

## Final answer

- **Belay (supervise / approve / steer / replay agents): KILL.** The space is covered by 7+ maintained tools, including one that is near-identical (Aria) and one first-party feature. The platform is automating approvals away, and better-funded teams in the adjacent space have already died or been absorbed.
- **The only unserved slice is the auto-mode audit CLI.** Buildable in 2–4 weeks, but **not a validated product**. Build it only as a learning or portfolio project, or as a two-day experiment: publish it, post a Show HN, and kill it if it doesn't clearly beat Agent Flow's and claude-trace-replay's star velocity within a month. Do **not** start a company around it.
- **If you want to stay in this area at all,** the stronger move is to contribute to an existing OSS tool such as Perch, Notchi or Agents Observe. Then use what you learn to find a pain point that isn't already a free afternoon project.

## Known gaps in this research

- **Reddit and X were not reached** (403 / blocked). That pain evidence is missing, and it could change the strength of the demand signal in either direction.
- **Product Hunt and the VS Code Marketplace were not loaded directly.**
- **GitHub API was rate-limited.** Stars come from repo HTML pages; dates come from the Atom feeds.
- **Closed-source competitors (Aria, NotchNook, AgentPeek, Runnock, Conductor) have no verifiable usage numbers.**
- **Unread sources:** the Harvard study behind the 331-point HN thread could not be read (Cloudflare block). Several tools seen only in search snippets are listed as UNVERIFIED in `landscape.md` §6.
