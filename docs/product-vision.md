# Belay: what we are selling, how it works, how it scales

**Status:** recommendation for the owner to accept or change (2026-11-27). Becomes ADR 0024 once accepted.
**Builds on:** `verdict.md` (the supervision slice is crowded), `landscape.md`, `crew.md`, `buddies.md`, `buddy-pointers.md`, ADR 0004 (subscriptions), ADR 0022.
**Competitor facts** come from `landscape.md` (read 2026-11-23) and the dusk bot README in `refs/`. Re-check every one before launch; anything not re-read is UNVERIFIED.

## 1. The product in one sentence

> **Belay is the control tower for every AI on your Mac.** Whatever agent you run (Claude Code, Codex, Cursor, Antigravity,
> your own buddies) shows up in the notch. Your buddies do your Mac chores. And nothing risky happens without your yes.

Short form for the website: **"One rope for every AI on your Mac."**

### Who it is for
Developers and power users who already pay for one or more AI subscriptions, run two or more AI tools at once, and are tired of
tab-hopping, approval fatigue, and a pile of bots that each live in their own app. Not teams, not Windows, not people who want
a hosted cloud assistant.

### The problem, in their words
1. "I have Claude Code in one terminal, Cursor in an editor, Codex in another. I don't know which one is waiting for me."
2. "Every tool asks permission differently, or I turned permissions off and feel uneasy."
3. "I pay for Claude/ChatGPT/Cursor already. I don't want another subscription for an assistant."
4. "I want my Mac to just do the boring stuff, but I don't trust an agent with my mouse and files."

## 2. Why this is not a copy (and what is honest about it)

| Competitor | What it is | Where Belay differs |
|---|---|---|
| Aria, NotchNook, AgentPeek, Runnock, Perch, Notchi | Watch and approve Claude Code and Codex from the notch | They stop at supervision. Belay adds buddies that *do* things, and covers more agents through one protocol. |
| dusk bot | Bots with routines and their own computers; a notch view on Mac; source-available, cross-platform | Its bots work on a computer of their own. Belay's buddies work on **your** Mac, under a rope, and Belay also supervises agents you start yourself. |
| heyclicky | Voice and screen buddy that runs agents; paid tier ($16/mo yearly, from `landscape.md`) | Cloud and subscription. Belay is local, free, runs on the AI you already pay for. |
| Conductor, Superset, Vibe Kanban | Run many coding agents in parallel | Developer workspaces, not a Mac-wide layer. |
| First-party (Anthropic Remote Control, auto mode) | The vendor's own approval and phone features | They only cover their own agent. Belay is the neutral layer across vendors. |

**The honest read:** no single piece below is unique. The *combination* is. Verify before launch that nobody ships all of it (UNVERIFIED).

## 3. The USP: five things, one of them the headline

| # | USP | Why it matters | Hard to copy because |
|---|---|---|---|
| 1 | **The rope (headline).** One approval and audit layer over *every* agent, buddy and Mac action | You answer once, in one place, however many AIs are running | Needs the session bus, the risk engine and the Mac actions built as one system; vendors only cover themselves |
| 2 | **Every AI shows up.** One notch, one inbox, any agent | Ends tab-hopping | Per-agent adapters plus an open protocol (§5) keep growing |
| 3 | **Bring your own subscription.** $0 extra | No new bill, no key paste for most users | Needs the CLI-driving design and the legal care in §6 |
| 4 | **Buddies with hands.** Characters that run errands on your Mac with visible, human-like pointers | The "my Mac runs itself" feeling, with a face | Tier model, pointer overlay, character art; see `buddy-pointers.md` |
| 5 | **Fast and tiny.** Local, MIT, 0% CPU closed, under 40 MB open | Trust, battery, and a clear contrast with Electron apps | Native Swift, a discipline most competitors lack |

Lead with 1 in every pitch. Use 5 as the proof line ("19 MB, no cloud, no account").

## 4. How it works: the model

Everything in Belay is one of four things. Keep this vocabulary everywhere (code, UI, docs).

| Concept | Meaning | Example |
|---|---|---|
| **Session** | One running piece of AI work, from anywhere | A Claude Code run in a terminal; a Cursor chat; a buddy's task |
| **Buddy** | A character with a job, memory and an engine. Works on tasks, can start sessions | pip (errands), sprout (code), willo (research) |
| **Rope event** | Anything that needs a decision | "Run `psql prod`?", "Send this email?", "Take control of Mail?" |
| **Routine** | A trigger plus a buddy plus a goal | Weekdays 08:30, otto summarises mail and calendar |

Two flows share the same pipe:

1. **Outside in:** agents you start yourself report to Belay (hooks, logs, process watch). Belay shows them and holds their risky steps.
2. **Inside out:** buddies start sessions on your own CLI (a headless `claude`, `codex`, `cursor-agent`, a local model) and act on your Mac. Their steps pass through the same rope.

Because both flows use one session model, a buddy-started Claude run appears in the notch exactly like one you started in a terminal.

## 5. Architecture

```
┌─────────────── Belay.app (Swift: renders and touches macOS) ────────────────┐
│ Notch: wings · pages (Now, Notes, Day, Agents) · inbox card · summon bar     │
│ Base camp window · pointer overlay · voice · haptics                         │
│ MacBridge: apps, files, Shortcuts, screen, accessibility, music, calendar    │
└──────────────▲───────────────────────────────────────────────────────────────┘
               │ protocol v1 over a 0600 Unix socket (no TCP ports)
┌──────────────┴─────────────── belayd (TypeScript: decides) ─────────────────┐
│ SESSION BUS      adapters turn every agent into Sessions                     │
│ ROPE             RiskEngine · ApprovalBroker · taint (ADR 0011) · audit log  │
│ CREW             Router · tasks · memory notes · engines · ToolHost          │
│ ROUTINES         scheduler (built) · triggers · missed runs                  │
│ CONNECTORS       calendar · mail · files · web · MCP servers                 │
│ BELAY MCP        exposes notch and Mac tools to ANY agent                    │
└──────▲──────────────────────▲─────────────────────────▲─────────────────────┘
       │ hooks / logs / ACP   │ spawns your CLI         │ MCP (stdio proxy)
  Claude Code, Codex,     claude · codex · cursor-agent  Any MCP-capable agent can
  Cursor, Antigravity…    · gemini/antigravity · local   ask the notch, notify, or
                          model · your API key           call a buddy
```

### 5.1 Adapters: how "any agent shows up"

Honest tiers, because agents expose very different things. The UI shows the tier so users know what to expect.

| Tier | What Belay can do | Agents (status) |
|---|---|---|
| **A · Control** | Show, approve, deny, steer | Claude Code and Codex through documented hooks (A0 spike passed, `spikes/a0-hooks.md`) |
| **B · Observe plus ask** | Show state and ask you questions; approval only where the agent has a hook or protocol | Gemini/Antigravity CLI (hooks documented for Gemini CLI, which Antigravity CLI replaced: Antigravity's own hooks are UNVERIFIED); Cursor CLI and others that speak the Agent Client Protocol (the dusk bot docs describe `cursor-agent acp`: UNVERIFIED); OpenCode (UNVERIFIED) |
| **C · Presence** | Know it is running and which app owns it; click to jump there | Cursor and Copilot inside an IDE, any other AI app. Process and window detection only; no approvals (Aria labels these "observe-only" too) |
| **Universal** | Any agent that supports MCP can call Belay's tools | See 5.2 |

Adding an agent means writing one adapter file that maps its events to Sessions. That is the scalable seam: community adapters, one folder each, tested with recorded transcripts (the Fake runtime pattern in `crew.md` §13).

### 5.2 Belay as an MCP server: the cheap way to reach every agent

`belay mcp` is a small stdio proxy that exposes a few tools to any MCP-capable agent:

| Tool | What the agent gets |
|---|---|
| `belay.ask_user` | A card in the notch with choices; the answer comes back (works even when the agent has no hook support) |
| `belay.notify` | A status line or wing in the notch ("Cursor: tests green") |
| `belay.delegate` | "Ask pip to open the PR", "ask willo to find the docs": the agent uses a buddy as a **subagent** |
| `belay.mac.*` | Mac errands (open, reveal, Shortcuts, screenshot), always behind the rope |

This is how buddies become subagents of *your* agents: Claude Code or Cursor calls `belay.delegate`, a buddy does the work with its own engine, and the result returns. It needs a capability token per call and the taint rules of ADR 0011 so untrusted content can't ride the channel. How well each agent surfaces MCP tools in its UI is UNVERIFIED.

### 5.3 Engines: your subscription, not ours

| Engine | How | Cost to the user | Status |
|---|---|---|---|
| **Claude Code CLI** | Run the user's installed, unmodified `claude`; they sign in with their own plan | Their existing Claude plan | Needs the Commercial Terms check first (§6) |
| **Codex CLI** | Run the user's `codex`, signed in with ChatGPT | Their ChatGPT plan | Fine as a user-run CLI; "Sign in with ChatGPT" for direct use needs OpenAI's partner client ID |
| **Cursor CLI** | Run `cursor-agent` with their Cursor plan | Their Cursor plan | UNVERIFIED flags |
| **Gemini / Antigravity CLI** | Same pattern | Their Google plan | UNVERIFIED |
| **Local model** | Ollama or LM Studio | Free, private | Planned |
| **API key** | The user's own key | Pay as you go | Planned |

**What "use my chat subscription" really means:** the claude.ai and chatgpt.com chat *websites* cannot be wired in (Anthropic forbids routing requests through plan credentials). The same plans do include the command-line agents, and Belay drives those. For almost every user that is the whole story: install the CLI, sign in once in their own terminal, Belay finds it. Belay never sees a token (ADR 0004).

Each buddy picks an engine and can switch any time; its thread and notes stay.

## 6. The decisions and risks to settle before building further

| # | Risk or decision | Recommendation |
|---|---|---|
| 1 | Claude: does launching the user's own `claude` from Belay count as "running Claude Code in your products" (Commercial Terms)? | Ask Anthropic before shipping any buddy that launches `claude`. Supervising sessions the user starts is clearly fine and can ship first. |
| 2 | Crowded market; `verdict.md` said KILL as a business | Goal stays reach, free and open source. Ship the sharpest slice first and watch for pull (§9). Revisit if nobody installs. |
| 3 | Vendors can absorb single features | The cross-vendor rope is the defence; a vendor will not supervise a rival. |
| 4 | Mac control scares people | Tier model, a visible "buddy is controlling" state, Esc aborts, nothing outward without a card. Default everything off. |
| 5 | Accessibility and screen recording permissions on a free, ad-hoc-signed app | Needs the Apple Developer Program for signing and notarization before any public build. |
| 6 | Scope: this is a lot | Build in the order in §8. Each phase must be demoable alone. |

## 7. The experience (flows)

**First run (under 2 minutes).** Belay finds installed CLIs and agents → shows "Found Claude Code, Codex, Cursor" with each one's tier → one click installs hooks with a diff preview (clean uninstall) → pick a first buddy (beepo) → done. Nothing runs until asked.

**A normal day.**
1. 08:30: otto's routine runs. The notch wing shows a small buddy; a card says "Your day: 3 meetings, 2 emails need a reply". You tap one; otto drafts it; a card asks "Send?" You say yes.
2. You start Claude Code in a terminal. A session appears in the notch within a second. In Cursor, another appears as presence.
3. Claude asks to run a database migration. The rope drops: one card, "Allow / Deny / Always". You say "no, use staging" and Claude continues.
4. From Cursor, an agent calls `belay.delegate`: willo researches an API and returns sources.
5. You hold ⌥Space: "pip, open the PR in Safari when sprout is done". pip waits, then asks, then opens it, its pointer visibly moving.
6. 18:00: a daily card shows what ran, what was blocked and what you approved.

**The inbox.** One queue called **Needs you**: approvals, questions, finished work, missed routines. The closed notch shows only a count and the most urgent wing. This is the screen to design best.

## 8. Feature list and build order

Reuses the IDs in `features-final.md`. Order changes from my last message: **the session bus and the rope come first**, because they are both the headline USP and the approval path every buddy needs. Build it once.

| Phase | Name | Ships | Demo that proves it | Maps to |
|---|---|---|---|---|
| **0** | Shell (done) | Notch, widgets, themes, pages, Agents layout on demo data | The notch itself | Built |
| **1** | See everything | Socket and `belayd`; session store; Claude Code and Codex hooks with installer; presence detection for other agents; real Agents page and wings; jump to terminal | Three agents running, correct states in under 150 ms | A1, H1, H2, A7 |
| **2** | Hold the rope | Approval card and the Needs-you inbox; danger rules and the catch; voice yes/no; audit log | "No, use staging" works on a real command | A2–A5, I2 |
| **3** | Buddies think | Engines (claude, codex, local, key); chat; name routing; memory notes; Belay MCP server so any agent can ask the notch and delegate | A buddy answers; Cursor calls a buddy | J1, K1–K3, K5, K6 |
| **4** | Buddies act | Mac hands tiers 0–2; pointer overlay; routines and triggers; connectors (calendar, mail, files, web) | pip opens things with human-like pointers; a morning routine runs | J2–J4, K7, K8, `buddy-pointers.md` |
| **5** | Ecosystem | Adapter and connector SDK; shareable buddy packs and rule packs; skills; docs site; CLI for scripting | Someone else's adapter works | I1–I5 |
| **6** | Reach | Daily and weekly cards, summon bar polish, Shortcuts and App Intents, sandboxed computer (Cua) | The 20-second hero clip | G1–G4, E7, J7 |

**Never (unchanged):** paid tiers, accounts, our own cloud computer, prompt sentiment analysis, reading agent credentials, GPL code.

### The first public version (v0.1) is Phases 1 and 2
It is the part with the clearest story and proven feasibility (the A0 spike passed). Buddies as demo data are a teaser, not a feature (design rule: only real things). Ship the rope, then buddies, so the first impression is "this works".

## 9. How we know it is working (cheap signals, no accounts)

- GitHub stars and installs per week; clips shared on X (the daily card is built to be shared).
- Of the people who install: how many connect a second agent (the "every AI" claim) and how many let a buddy do a first task.
- Time from install to first approved rope event (target under 5 minutes).
- Kill or pivot trigger: if the supervision demo gets no pull after launch, the buddies-only path is weaker still, because dusk bot and heyclicky already own that story. Decide then, with data.

## 10. What I need decided

1. Accept the headline "one rope for every AI on your Mac" and the five USPs (or edit them).
2. Accept the build order in §8, with Phases 1 and 2 first.
3. Ask Anthropic about the Commercial Terms point before Phase 3 (you, or I draft the question).
4. Apple Developer Program for signing, before any public build.
