# Belay: product design

**Written:** 2026-11-24.

**Builds on:** `landscape.md`, `feasibility.md` and `market.md`.

**Goal:** fame and spread, not revenue. Ship in **2 weeks**.

## Why this exists despite `verdict.md`

`verdict.md` said KILL **as a business**: the space is crowded and nobody pays. That still stands. For a **launch-for-attention** project the bar is different. You don't need a moat. You need one moment people want to share, built on a free, open-source app that is polished enough to install. Everything below is designed around that.

---

## 1. The concept in one line

> **Belay is a little climber who lives in your Mac's notch and holds the rope for your coding agents.** When Claude Code or Codex needs you, the rope drops. When an agent tries something dangerous, Belay *catches the fall*, out loud. You answer by voice and the agent keeps climbing.

**Why the name works:** in climbing, the belayer is the person who holds the rope and catches the climber's falls. That gives the product its metaphor, its character, its animations and its tweet copy. It also means you don't borrow Clicky's cursor-buddy look or any agent vendor's branding.

## 2. Combining heyclicky and the notch tools: what to take from each

| From | Take | Leave |
|---|---|---|
| **heyclicky / Clicky** | A **character with a voice**: push-to-talk, it talks back, it feels alive. Its OSS code is **MIT**, so it can be forked. | General screen tutoring, drawing on screen, cloud voice stack (AssemblyAI, ElevenLabs, Cloudflare Worker). That's a different product with running costs. |
| **Aria / notch tools** | Agent awareness from the notch: approve, deny and steer Claude Code and Codex through documented hooks. | Teams, rooms, replay, profiles, community, 66 features. |
| **Notchi** | Proof that a **mascot with emotions and sound** earns stars (1,051 vs Perch's 31). | Sentiment analysis of your prompts (needs API keys, creepy). Its code is **GPL-3**, so don't copy it. |

**Be honest with yourself:** Aria already supports voice approvals ("Approve a class V request by saying 'allow'", in 0.2.5) and steering. Belay's difference is **not capability**. It is:

1. **The character and the catch-a-fall moment:** emotional and filmable.
2. **Voice-first steering as the headline**, not a buried feature.
3. **A shareable daily card** that turns each user into a poster.
4. **Free and open source on GitHub**, so stars become your scoreboard.

## 3. The target user

- **Primary:** developers on a MacBook running **1–4 Claude Code or Codex sessions** in terminals who tab back and forth to answer prompts. Many have **turned on auto mode or "don't ask again"** and feel slightly uneasy about it (`pain.md` §1).
- **Secondary (the amplifiers):** AI-tooling people on X who repost delightful dev tools. They don't need to install it. They need to *share the clip*.
- **Not the target:**
  - Teams or enterprises (they have Aria, Conductor, Anthropic's own tools).
  - Windows or Linux users.
  - People using only Cursor or Copilot. Those are observe-only even for Aria.

## 4. The hero moment (design everything backwards from this clip)

A 20-second screen recording, with sound on:

1. A terminal shows Claude Code working. In the notch, Belay is calmly holding a rope. It is the size of a dot.
2. The agent proposes `rm -rf ./data` or `psql production -f migrate.sql`.
3. **The rope snaps taut.** Belay slides down out of the notch, braces, and *catches*. A short "whoa!" sound plays.
4. Belay says aloud (TTS): *"Hold up, Claude wants to run a migration on **production**."*
5. You say: **"No, use staging instead."**
6. Belay replies: *"Got it, sending it back."* The terminal shows Claude receiving the denial with your message and rerunning against staging.
7. Belay climbs back into the notch. A small counter ticks up: **"Falls caught today: 1."**

Why this works technically, using documented interfaces only:

- Step 3 is a Claude Code `PermissionRequest` HTTP hook. Codex has the same event through a command hook.
- Step 6 is the deny decision's documented **`message`** field: "For 'deny' only: tells Claude why the permission was denied". Codex's deny also takes a `message`.
- No hidden or terminal-injection tricks.

## 5. Feature set

> The full ecosystem spec (holds, music, side quests, haptics, plugins, phases v0.1–v0.3+) lives in **`features.md`**. The list below is the v0.1 launch core.

### Must ship (MVP, 2 weeks)

| # | Feature | What it does | Why it's in |
|---|---|---|---|
| F1 | **Notch home** | A tiny animated Belay sits in the notch. One small dot per live session, coloured by state: climbing (working), rope dropped (needs you), summit flag (done), dangling (error). Hover to expand into a list of sessions with repo name and current action. | Ambient presence is the reason to be native at all |
| F2 | **Rope-drop approval card** | When any session asks permission, the card drops from the notch. It shows the agent, the repo, the **exact command**, and a one-line plain-English risk note. Buttons: **Allow ↵ · Deny ⎋ · Always ⇧↵**. | Core job. "Always" uses the documented `updatedPermissions` (`addRules`). |
| F3 | **Catch a fall** | A local rules engine flags dangerous calls: `rm -rf`, `git push --force`, `git reset --hard`, `DROP`/`TRUNCATE`, prod-looking hosts and env names, `curl … \| sh`, writes outside the repo, `.env`/ssh/key paths, `chmod 777`. A flagged call gets the dramatic catch animation, a sound and a spoken warning. | The shareable, emotional moment |
| F4 | **Voice answer + steer** | Push-to-talk (e.g. hold `fn` or `⌥Space`). Belay reads the request aloud. Say "yes", "no", "always", or **"no, … instead"**, which denies with your words as `message` so the agent adapts. **"Stop"** sends `interrupt: true`. | The differentiator in the clip |
| F5 | **"What are my agents doing?"** | Ask aloud and get a spoken status: *"Two climbing. Claude in billing is running tests, Codex in web finished 3 minutes ago."* Built from hook events with templates. **No LLM needed.** | Demo line #2; zero running cost |
| F6 | **Daily Belay log card** | A beautiful image to share: *"Today Belay held the rope for 6 h 12 m · 47 approvals · **3 falls caught** · longest climb 1 h 40 m"*, with the character. One click to copy it or open X with prefilled text and the image. | **The viral loop.** Each user becomes a poster. |
| F7 | **Safe one-click setup** | On first launch it detects Claude Code and Codex, **previews the exact hook config it will add**, writes it, and offers clean uninstall. If Belay isn't running, hooks fail open to the normal terminal prompt and **never auto-allow**. | Trust. The install is the biggest drop-off point. |
| F8 | **Works without a notch** | On Macs without a notch (and external displays) it shows the same pill at top centre. | Doesn't cut out half the Mac audience |

### Should, only if ahead of schedule

- **Sound pack and mute rules:** stay silent while the terminal that's asking is focused (Notchi does this).
- **"Jump to terminal":** click a session to focus its iTerm2 or Terminal.app window via AppleScript.
- **Auto-mode watch:** when auto mode silently blocks something (`PermissionDenied` hook), Belay shrugs and says so. This connects to the one unserved slice in `verdict.md`.

### Won't (explicitly cut, so the 2 weeks hold)

- Screen reading or pointing like Clicky.
- Replay and timelines.
- Teams and multiplayer.
- Phone approvals (Anthropic Remote Control covers that).
- Cost tracking (ccusage does it).
- Gemini, Cursor, Copilot.
- Accounts, a backend, telemetry, payments.
- Cloud TTS or STT.
- Windows.

## 6. Experience details that make it feel premium

- **Under 1 second from hook to rope drop.** Latency kills the magic.
- **Keyboard-first:** every voice action has a key. The card is focusable without stealing focus from your editor until it appears.
- **One voice, one personality:** calm, dry, short sentences. Write the lines yourself, about 30 of them, as a sprite sheet of words: "Rope's yours." "Caught one." "Summit." "Hold on."
- **Never block when Belay is down.** Fail open to the normal prompt, never to allow.
- **Privacy line on the homepage:** "Everything runs on your Mac. No account. No servers. Speech recognised on-device." That's true by design (§7) and is a selling point against cloud buddies.
- **Character constraints:** 5 states (idle, climbing, rope dropped, catch, summit), about 4 frames each, pixel art at 2× and 3×. **Don't use Claude or Codex logos or mascots** for agents. Use neutral coloured dots and labels.

## 7. Technology choices (detail in `build-plan.md`)

- **Shell:**
  - A **Swift/SwiftUI** macOS app, started by **forking Clicky (MIT)**, for its overlay windows, push-to-talk and app scaffolding.
  - Replace its cloud voice stack with **Apple on-device speech recognition and system TTS**: no keys, no costs, no backend.
  - Write the notch panel fresh. **Boring Notch and Notchi are GPL-3**: learn from them, but don't copy their code if Belay stays MIT.
- **Brain:**
  - A **TypeScript sidecar (`belayd`)**, compiled to a single binary with Bun and bundled inside the `.app`.
  - It receives the hooks, holds pending approvals, runs the risk rules, tracks session state and renders the share card.
  - You're strongest in TypeScript, so most of the logic lives there. Swift only draws and listens.

## 8. Success measures for launch week

| Metric | Floor | Good | Great |
|---|---|---|---|
| GitHub stars (week 1) | 50 | 300 | 1,000+ (Notchi level) |
| Hero clip views on X | 2k | 20k | 100k+ |
| DMG downloads (GitHub release counter) | 50 | 500 | 2,000+ |
| Shared Belay log cards seen in the wild | 1 | 10 | 50+ |

These targets are my judgment, anchored on `market.md` §2–3, not measured benchmarks.
