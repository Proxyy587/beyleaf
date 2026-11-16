# Belay: market growth and what goes viral

**Data pulled:** 2026-11-24.

**Sources:**
- npm downloads: `api.npmjs.org/downloads/range`. Monthly totals are sums of the daily figures.
- Hacker News: the Algolia API (`tags=show_hn`, posts since 2025-06-01).
- Other figures: GitHub repo pages and vendor pages read for `landscape.md` (2026-11-23).

**Goal of this doc:** the objective has changed from "a business" (see `verdict.md`) to **"fame + a product that spreads"**. This doc asks whether the market is growing, and what kind of Mac/notch/agent tool actually gets attention.

---

## 1. Is the market growing? Yes, fast

Monthly npm downloads:

| Month | Claude Code (`@anthropic-ai/claude-code`) | Codex (`@openai/codex`) | Gemini CLI | ccusage (a companion tool) |
|---|---|---|---|---|
| 2025-05 | 1.52M | 135k | — | 1k |
| 2025-10 | 23.99M | 1.12M | 1.15M | 75k |
| 2026-03 | 44.45M | 14.53M | 3.20M | 201k |
| 2026-08 | 85.65M | 76.95M | 1.69M | 396k |
| 2026-10 | 49.60M | 97.60M | 1.65M | **1.03M** |
| 2026-11 (to the 23rd) | 55.07M | 82.63M | 1.55M | 818k |

**Year over year (Oct 2025 → Oct 2026):**
- Claude Code: **about 2.1×**
- Codex: **about 87×**
- ccusage: **about 14×**
- Gemini CLI: flat to falling. It peaked at 3.47M in April 2026. Its own docs say it was replaced by Antigravity CLI for free and Google One users on 2026-06-18.

**What this means for Belay:**
- **Claude Code and Codex are the two agents to support.** Gemini can wait.
- **Companion tools grow faster than the agents.** ccusage grew about 14× while Claude Code grew about 2×, so the pool of people who install add-on tools is growing faster than the base.
- **Codex is now the bigger audience by downloads.** Supporting it on day one matters more than it did six months ago.

⚠️ **Caveats:**
- npm downloads are **not users**. They include CI runs, auto-updates and mirrors.
- Codex's 2026-05 figure (**239.38M**) is a one-month spike roughly 5× its neighbours. It is almost certainly an artifact (CI, a mirror, or a packaging change), so don't quote it.
- Treat these as trend lines, not head counts.

## 2. What actually gets attention: evidence from Show HN

Show HN posts about tools similar to Belay:

| Post | Date | Points | Comments |
|---|---|---|---|
| "I turned my MacBook notch into a live Claude Code dashboard" | 2026-04-17 | **9** | 1 |
| "Crest – Answer Claude Code approvals from your MacBook's notch" | 2026-09-23 | **6** | 0 |
| "CoIsland – Your whole engineering stack in a notch" | 2026-10-01 | 5 | 1 |
| "Mac menu bar app for Claude Code rate limits" | 2026-04-15 | 5 | 0 |
| "macOS menu bar gauges for your Claude Code quota" | 2026-06-10 | **69** | 40 |
| "Claude Code Plugin to play music when waiting on user input" | 2025-12-20 | **56** | 15 |
| "A Claude Code plugin that catch destructive Git and filesystem commands" | 2025-12-26 | **61** | 69 |
| "Claude Code Usage Monitor – real-time tracker to dodge usage cut-offs" | 2025-06-19 | **245** | 135 |
| "Rudel – Claude Code Session Analytics" | 2026-03-12 | 144 | 86 |
| "Ski – Voice Coding for Claude Code, Codex and More – On-Device – Free" | 2026-07-30 | 15 | 14 |

Links:
- https://news.ycombinator.com/item?id=47807159
- https://news.ycombinator.com/item?id=49819868
- https://news.ycombinator.com/item?id=49922772
- https://news.ycombinator.com/item?id=47781940
- https://news.ycombinator.com/item?id=48473845
- https://news.ycombinator.com/item?id=46337118
- https://news.ycombinator.com/item?id=46388882
- https://news.ycombinator.com/item?id=44317012
- https://news.ycombinator.com/item?id=47350416
- https://news.ycombinator.com/item?id=49113559

**What the table shows:**
1. **"Notch dashboard for agents" is a dead pitch on HN, at 5–9 points.** Too many exist, so the concept alone earns nothing.
2. **Posts did better when they did one specific thing with a hook:** "dodge usage cut-offs" (245), "catch destructive commands" (61), "play music while waiting" (56). Being specific and a bit playful beat being comprehensive.
3. **Voice alone (Ski, 15 points) didn't land on HN.** HN is a weak channel for voice demos, which travel better as video on X.

## 3. What made the viral Mac tools spread

- **heyclicky / Clicky (Farza):**
  - The open-source README says the "original tweet … kinda blew up for a demo".
  - The OSS repo has **8,062 stars**. heyclicky.com claims **"80,000+ happy users"** (vendor claim).
  - The site shows tweets from Greg Brockman (2.7k likes) and Lenny Rachitsky (526 likes) about it.
  - What spread was **a demo clip of a character that talks and points at your screen**. Nobody shared a feature list.
  - ⚠️ Farza already had a large audience (he founded buildspace). His follower count is **UNVERIFIED**, but you are not starting from the same place.
- **Notchi vs Perch:** a natural comparison of two free OSS notch apps for Claude Code and Codex.
  - **Notchi has mascots** ("each with its own mascot", emotions, sound effects). It has **1,051 stars**.
  - **Perch is utilitarian** (answer prompts from the notch). It has **31 stars**.
  - ⚠️ This is a sample of two, so it's an anecdote, not proof. But it is the best signal available that **personality is what earns stars in this niche**.
- **Aria:** the most feature-complete product, with no visible public traction metric. Features alone haven't made it famous (as far as I can see).

## 4. Implications

- The audience is large and growing (tens of millions of monthly installs across Claude Code and Codex).
- The *category* (agent supervision in the notch) is crowded and gets no attention on its own.
- **Belay can't win on features.** Aria already has approve, steer, replay and voice approvals.
- **Belay can win on one memorable, filmable moment and a character people want to share.**
- That moment needs to show up in a 15–25-second video with sound.

## 5. Honest odds

- From 120 followers, your own audience will not carry this. Reach has to come from the **clip being reposted by bigger accounts**, plus HN, Product Hunt and Reddit (posted by you; I couldn't research Reddit).
- Base rates are poor: most comparable Show HN posts scored under 10 points.
- A good outcome for a first launch would be roughly **a few hundred GitHub stars and one clip that does well into the tens of thousands of views**. That is my estimate from the Notchi and Show HN numbers above, not a measured benchmark.
