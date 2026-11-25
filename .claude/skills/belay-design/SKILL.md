---
name: belay-design
description: Belay's design system and anti-slop review. Use whenever creating or changing ANY Belay UI - the notch (apps/mac/Sources/Belay/Notch), cards, the Settings window, share cards, or the website - or when the user asks to make something look better, cleaner, less "AI slop", or more like Aria or dusk bot.
---

# Belay design

The rules are in `docs/design.md`. **Read it before touching UI.** What exists and why is in `docs/ui-inventory.md`: every new element needs a row there and must pass its purpose test ("what user job does this do that the notch is uniquely good for?"). Tokens are in `apps/mac/Sources/Belay/Design/Tokens.swift`; never hard-code a colour, size, radius, font or animation in a view.

## The feel we're after
- **Aria-like notch:** pure black. Rows are [app icon] title, with a quiet uppercase **mono status line** under it and a mono value on the right. One green, only for "live". Lots of air.
- **dusk-like brand:** a clean sans for UI, a pixel face only for brand moments (the climber), warm off-white ink.
- **Calm:** still at rest. Motion explains a change in ≤ 300 ms.
- Inspiration only: never copy their code, assets or text (ADR 0008).

## What the references share (studied 2026-11-25, in our words)
unfair.so, dusk.bot and joinariapp.com, captured with `agent-browser` at 1440×900. dusk bot's app was read from the local study clone in `refs/duskbot`.
- **One clean sans plus one pixel moment.**
  - unfair.so: Inter body, with a bitmap serif only for the giant headline.
  - dusk bot: General Sans and Geist, with a pixel mascot as the only colour.
  - Aria: Geist, with a dithered pixel-cloud hero.
  - For Belay: SF for UI, and the pixel climber plus the mark are the one brand moment.
- **Display type is tight.** Headlines run -4 to -5.5% tracking at 100–220 px. UI text is never tracked.
- **Pills and tones, not boxes.**
  - Primary action: a solid ink (or one saturated accent) capsule. Secondary: a faint tonal capsule.
  - Segmented navigation is a pill track with one white selected pill.
- **Borderless tonal contrast** (dusk's own audit rule):
  - surfaces differ by tone, not lines or shadows;
  - a banner or notice gets a 6% ink tint so it never floats as bare words;
  - shadows only on things that truly float.
- **One motion per kind.** dusk keeps exactly one dialog motion (a 6 px rise from 98.5% over 240 ms) and one popover motion (120 ms grow from the trigger). Its duration steps are 100/150/200/300 ms on a quick ease-out, and a press springs back with a hair of overshoot.
  - For Belay: one open, one close, one swap, one press. Never a per-view curve.
- **Restraint.** Lowercase or sentence case, very few words, one accent, and plenty of empty space.

## Tools
- **`agent-browser`**: look at a reference or our website (screenshots, computed fonts and colours). Setup is in its `SOURCE.md`.
- **Hallmark** (plugin, `/hallmark:hallmark`): only for new web pages (`apps/web`, the landing page, share cards) or when asked for a Hallmark `audit`.
  - It doesn't know SwiftUI.
  - Where it conflicts with `docs/design.md` (mono uppercase status lines, `A · B` meta), `docs/design.md` wins and the waiver goes in the stamp.

## Anti-slop gate (fail the change if any is true)
1. A decorative gradient anywhere
2. An icon sitting in a tinted plate (album art and app icons excepted)
3. A surface with fill + border + shadow (pick one; shadows only on floating things)
4. A card inside a card
5. Text colour outside ink / ink2 / ink3 / live / warning / danger / accent
6. A font size or weight outside the scale, or a rounded face
7. Emoji or unicode glyphs as UI
8. Taglines, filler copy, exclamation marks, Title Case
9. A "coming soon" or fake-data surface
10. An idle loop animation, or motion over 300 ms
11. Missing states: empty, long text, offline, no battery, no notch, reduced motion

## How to work
1. Sketch the states first (closed, open, empty, error, long text).
2. Build with `Tok.*` and the shared row and chip components. Add a component once, in `Design/`, if it's missing.
3. Run `apps/mac/scripts/run.sh --expand`. **Screenshot the real notch** (`screencapture -x -R <x,y,w,h> out.png`) and look at it. Check closed and open.
4. Check idle CPU (`ps -o %cpu= -p $(pgrep -x Belay)` over a few seconds): under 1%.
5. Paste the review checklist from `docs/design.md` §12 into the commit body.
