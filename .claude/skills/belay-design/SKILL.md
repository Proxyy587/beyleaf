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
