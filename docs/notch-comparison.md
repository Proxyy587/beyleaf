# Dynamic Island vs Boring Notch vs Belay: UI comparison

**Written:** 2026-11-25. **Sources:**
- Apple HIG, *Live Activities* (developer.apple.com/design/human-interface-guidelines/live-activities, read 2026-11-25).
- Boring Notch's README (github.com/TheBoredTeam/boring.notch @ main, read 2026-11-25; GPL-3.0, ~11.5k stars, pushed 2026-11-25).
- Belay at `feat/notch-redesign`.
- Anything not stated in those sources is marked **UNVERIFIED**.
- Boring Notch is GPL-3.0, so this is a product comparison only. No code is read or copied (ADR 0003).

## 1. At a glance

| | **Dynamic Island** (iPhone) | **Boring Notch** (macOS) | **Belay** (macOS) |
|---|---|---|---|
| What it's for | System + any app's Live Activities | A richer notch: music, calendar, shelf, HUD replacement | **Supervising coding agents**; music, screenshots and a timer are side jobs |
| At rest | Pill around the camera; empty unless something is live | Notch-sized; music activity while playing (README) | Exactly the hardware notch: invisible until something is live |
| Live, one thing | **Compact:** leading + trailing views beside the camera | "Playback live activity", charging indicator (README) | **Wings:** leading + trailing beside the camera (music art + beat bars, timer ring + minutes) |
| Live, several things | **Minimal:** up to 3; one attached, others detached circles/ovals | UNVERIFIED | One at a time by priority (agent > alert > music > timer); hover shows all |
| A moment that needs words | Expanded on alerts (system) | UNVERIFIED | **Drop:** the shape grows down one line ("Screenshot copied · ⌘V to paste") |
| Full view | **Expanded:** touch and hold; height follows content | Hover to expand (README) | Hover (or menu) opens the panel; **height hugs content** |
| Layout of the full view | App-designed regions: leading, trailing, center, bottom | Fixed views; "Customizable Layout options" is still an open roadmap item (README) | **User-arranged widgets**: drag into slots, tiles pair, nothing leaves a hole (ADR 0019) |
| Customization | None for users | Notch sizing, gestures (README) | Widgets, order, themes (fonts, colours, glass, roundness, width, density, motion), import/export |
| Haptics | Touch feedback on iPhone | UNVERIFIED | One tick when the notch opens under your finger; **never on click** |
| Extras | — | Calendar, reminders, camera mirror, AirDrop shelf, volume/brightness HUD | Screenshot auto-copy, timer; agents next (rope drops, catches) |

## 2. Apple's rules we follow (from the HIG)
- **Compact = leading + trailing around the camera.** Our wings are the same idea, sized per activity.
- **Height follows content:** "reduce the height … to only use the space needed". This is our "no dead space" rule, and the panel and drops measure their own height.
- **Concentric margins:** keep content inside a margin concentric to the outer edge, and don't draw content to the edge. Cards sit 8 pt inside the panel at radius 14, inside the panel's 24.
- **Separate blocks with an inset container,** not hairlines. These are our tonal cards.
- **Focus on what's needed at a glance,** with detail one step away. Wings show one fact; the panel shows controls.
- **Don't show sensitive content on a glanceable surface.** For agents (A2), cards show the command, never secrets or file contents. Already a design rule.

## 3. Where each one is better

**Dynamic Island**
- **Several activities at once** (minimal presentation).
  - Belay shows one wing at a time.
  - Worth copying for agents: two sessions waiting should both be visible. Planned with A1.
- **Shape-first motion.** Content morphs with the shape, never just appearing inside it.
  - Belay's jelly spring and blur-swap aim for this.
  - Our drop line still fades in after the shape moves, rather than morphing with it.

**Boring Notch**
- **Breadth:** calendar, reminders, mirror, AirDrop shelf, HUD replacement.
  - Belay deliberately skips anything that duplicates the menu bar or Control Center (`docs/ui-inventory.md` §5, the purpose test).
- **Distribution:** Homebrew cask, an established community, 11k+ stars.

**Belay**
- **User-arranged layout with a no-hole guarantee.**
  - Neither of the others lets users arrange the expanded view.
  - Boring Notch lists it as not done yet.
- **A real job beyond media:** agent approvals and catches (A1–A3) are the product. Everything else has to pass the purpose test.
- **Calm by rule:**
  - nothing moves at rest;
  - placeholder lines are banned;
  - every element has a written purpose;
  - idle CPU is measured at 0.0% closed.
- **Theme system:** every visual token is user-editable and shareable as JSON (ADR 0015).

## 4. What Belay should take next
1. **Minimal presentation for agents:** when two or more agents need you, show detached dots or ovals beside the wings, like iPhone's minimal style.
2. **Morph, don't fade:** the drop line should grow out of the shape's bottom edge with the jelly spring, not fade in after it.
3. **Limited-width fallback:** on an external display without a notch, use a single leading view (Apple's 28 pt circle guidance), never truncated text.
4. **Not taking:** HUD replacement, calendar, camera mirror. They duplicate the system or need permissions without a notch-only job.

## 5. Open checks
- Boring Notch's look in detail (spacing, type, motion) is **UNVERIFIED** here. Capture its app or site with `agent-browser` before making visual claims.
- Its behaviour with several activities at once and its haptics are **UNVERIFIED**.
