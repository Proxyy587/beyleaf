# Belay: launch and marketing plan (from 120 followers)

**Written:** 2026-11-24.

**Starting point:** an X account with about 120 followers and almost no reach.

**Goal:** attention and GitHub stars for an open-source Mac app.

## The core truth

**Your audience won't make this spread. The clip will.** Reach comes from three things:
1. A 20-second video good enough that bigger accounts repost it.
2. Platforms that don't care about follower count: HN, Product Hunt, Reddit, GitHub trending.
3. Every user's share card (F6).

Plan for all three. Expect each one to mostly fail, and need only one to work.

## Days 1–13: build in public (inside the 2-week build)

- **Post every day you have something visual.** That's about 8 posts. Each one gets a 5–15-second screen recording with sound, never just text.
  - Day 1: "Claude Code just accepted a 'no, do this instead' I typed into my own app." Show the raw terminal.
  - Day 4: first rope drop from the notch.
  - Day 6: the first ugly voice steer ("I said 'use staging' out loud and Claude listened").
  - Day 9: the character reveal (sprites, the catch animation).
  - Day 10: the first share card.
- **Reply, don't broadcast.** Your 120 followers won't see much. The people posting about Claude Code and Codex releases, agent fails and `rm -rf` horror stories will. Reply with a **relevant clip** only when it actually fits the conversation. One good reply clip beats ten posts. Don't spam the same reply.
- **Collect people:** keep a list of about 30 accounts that post about Claude Code, Codex, Mac tools or dev tools. On launch day, DM the 10 who engaged with your build-in-public clips. Send no cold mass DMs.
- **Waitlist:** a Next.js landing page with one email field: "Get the DMG on launch day". Even 50 emails is a launch-day spike you control.

## Launch day (Day 14)

| Time (US Eastern, for US-heavy reach) | Action |
|---|---|
| ~08:00 | GitHub repo public, release DMG, README with GIF at the top |
| ~08:15 | **X launch post**: the 20-second hero video natively uploaded (not a YouTube link), one line, and the link in the first reply. Example: *"I built a tiny climber that lives in my MacBook notch and catches my coding agents before they fall. Talk to it. It's free and open source."* |
| ~08:30 | **Show HN**: "Show HN: Belay – voice-steer Claude Code and Codex from your Mac's notch". Lead the text with *how it works* (documented hooks, deny-with-message, localhost only, fail-open). HN rewards mechanism and punishes hype. Reply to every comment for 6 hours. |
| ~09:00 | Email the waitlist. DM the 10 engaged accounts with the post link. |
| Same day or next | **Product Hunt** (the video is the gallery's first item) |
| Same day | **Reddit**: post the video natively in the relevant communities, if their rules allow self-promotion. **I could not research Reddit (access blocked)**, so read each subreddit's rules first. |

## Week after launch

- **Share-card loop:** retweet or quote every user who posts their Belay log. Make the "falls caught" count something people want to show off.
- **Ship one visible update in 72 hours**, for example a new sound pack or "jump to terminal". Post it as a reply to your launch post to revive it.
- **Write one honest technical thread:** "How Belay steers Claude Code with a single hook field". Developers share mechanism threads, and this one keeps working weeks later.

## Messaging rules

- Lead with **the catch moment and voice**, never with "dashboard" or "monitor". `market.md` §2 shows that framing gets 5–9 points.
- **Be honest about the alternatives** in the README FAQ: "Aria and NotchNook also approve agents from the notch; Belay is the free, open-source, voice-first one with a climber." HN respects this. Hiding them gets you called out.
- **Lead with privacy**: on-device speech, no account, no servers.
- **No vendor logos or mascots** in the visuals.

## What I could not verify

- Best posting times on X, and X algorithm behaviour. X was not reachable for research, so the timing above is a **convention, not data**.
- Rules for self-promotion on Reddit and Product Hunt.
- Whether any specific large account would repost. Don't plan around one person.
