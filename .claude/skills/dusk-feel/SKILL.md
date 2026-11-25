---
name: dusk-feel
description: Make a Belay surface feel like dusk bot (dusk.bot), the product whose look the owner wants. Tonal, borderless surfaces, neutral pill buttons, one motion per kind, quiet lowercase copy. Use with belay-design when designing or restyling the notch, cards, Settings or the website, or when the user says "like dusk bot", "cleaner", "less slop" or "more premium".
---

# The dusk feel, for Belay

Written in our own words from a study of dusk bot. The sources were its public site (captured 2026-11-25) and the local study clone in `refs/duskbot` @ `981d1a79`, which is PolyForm Noncommercial.
- **Never copy its code, CSS, skill text, assets or copy (ADR 0018).**
- The numbers below describe a feel, and we may reuse them. They are facts, not source.
- **Precedence:** `docs/design.md` and `docs/ui-inventory.md` decide what Belay is. This skill tunes how it feels. Where they differ, the doc wins (see "Where Belay differs").

## 1. Surfaces are tones, not boxes
dusk separates things by **shade**. Lines and shadows are almost never used. Its dark ladder steps up in small increments:

| Role | dusk dark value | Belay token |
|---|---|---|
| Deepest panel | `#0E0E0E` | the notch stays `#000` (`Tok.notch`) |
| App ground | `#121212` | Settings window background |
| Raised (row, card, menu) | `#1F1F1F`–`#202020` (≈ ink 6–8% over black) | `Tok.raised` |
| Raised hover | `#2C2C2C` (≈ ink 12%) | `Tok.hoverFill` → `Tok.pressedFill` |
| Control (field, track) | `#282828` | `Tok.hoverFill` |
| Notice / banner | ink 6% tint, so it never floats as bare words | `Tok.raised` |
| Frame at rest | ink 10%, **only** around an input or composer | `Tok.hairline` |

Rules:
- **One of tone *or* line, never both.** A dark menu or popover has no border and no shadow: its tone lifts it.
- **Shadows only in light skins, and only on things that float.** The notch never gets one.
- Ink is a warm off-white. Secondary text is ink at ≈ 66% and tertiary at ≈ 54%. Never invent a fourth level.

## 2. Pills and one primary action
- **Primary action:** a **neutral pill** that inverts the surface: an ink fill with dark text on a dark surface.
  - Hover or press darkens the fill to ≈ 88% ink. The text stays.
  - Disabled: ink 13% fill with ink 30% text. Don't use opacity on the whole button.
- **Secondary action:** a faint tonal pill (`Tok.raised`) with ink text.
- **Accent blue is for state, not decoration:** a switch that's on, focus, the one selected thing.
  - dusk's accent is `#116DD2` (text `#4D9BFF`); ours is `Tok.accent`.
- **Status colours mean status:**
  - success / live: dusk `#00BA69`, ours `Tok.live`;
  - danger: dusk `#FF6463`, ours `Tok.danger`;
  - warning: dusk `#E28600`, ours `Tok.warning`.
- **Chips** name a thing inline, like a model, an app or a file: a small tonal pill with a tiny icon and its name.
- **Segmented choice:** a pill track with the selected segment as a solid ink pill.

## 3. Shape
- **Radius ladder:** 6 / 8 / 12 / 14 / 16. Menus and dialogs are 14, rows and cards 12, small controls 8, thumbnails 6.
- Buttons and chips are capsules.
- A nested shape is always rounder-inside-smaller: the inner radius equals the outer radius minus the inset.
- Belay's tokens: `Tok.rRow` 12, `Tok.rThumb` 6, the open notch 24 bottom and 12 ears.

## 4. Motion: exactly one per kind
dusk's rule: **one dialog motion, one popover motion, one press, one swap.** Every surface uses the shared one, and none rolls its own.

| Kind | dusk feel | SwiftUI for Belay |
|---|---|---|
| Durations | 50 / 100 / 150 / 200 / 300 ms, plus 500 for big drawers | pick from these only |
| Default ease | quick ease-out, `cubic-bezier(0.22, 1, 0.36, 1)` | `.timingCurve(0.22, 1, 0.36, 1, duration: 0.2)` |
| Dialog / sheet in | rise 6 px from 98.5% scale, fade, 240 ms. Scrim fades 160 ms. Leaving is a 120 ms fade only. | the notch open is our "dialog": `Tok.open` |
| Popover / menu in | 120 ms grow from the trigger, with a touch of blur | `Tok.reveal` + `.blur(Tok.blur)` from 0.96 scale |
| Pane swap | the new content rises a few px out of a slight blur | `AnyTransition(.blurReplace)` + `Tok.reveal` |
| Press | down in 120 ms, back up with a hair of overshoot (`cubic-bezier(0.28, 1.4, 0.36, 1)`, ≈ 200 ms) | scale 0.97 on press, `.timingCurve(0.28, 1.4, 0.36, 1, duration: 0.2)` on release |
| Switch thumb | spring with ≈ 5% overshoot, settled by ≈ 330 ms | native `Toggle(.switch)` already does this |

- Nothing animates `width`/`height` for layout jank. The notch shape is the one exception, and it's a spring.
- Reduced motion keeps only the fades.
- **No idle loops** (`docs/design.md` §7). dusk's one living thing is its working mascot. Ours is the climber, and only while an agent works.

## 5. Type and words
- dusk uses Geist / Geist Mono in the app and General Sans for display (≈ weight 450, tracking −5.5% at 100 px). **Belay stays on SF** (native first). The *feel* carries over:
  - UI text is untracked;
  - display or brand text is tight;
  - three weights.
- **Lowercase brand, sentence-case everything else, very few words.** A label names; it doesn't explain.
- Copy is calm and concrete: "sorted 63 emails, drafted 4 replies", not "Your AI assistant is hard at work!".
- One pixel-art moment carries the personality: dusk's mascot, our climber and mark. Everything else is plain.

## 6. How dusk checks itself (adopt this)
Its UI audit captured **every** surface in light and dark at the normal and smallest size, about 300 screenshots. It then ranked findings as *what is wrong → fix → status* with before and after images, and kept the "after" set as a visual baseline.

For Belay, the surfaces to capture are:
- the closed notch;
- the open notch: empty, playing, and with a long title;
- each live activity;
- each Settings pane in light and dark;
- reduced motion.

Use `screencapture` (see `swiftui-macos`). Judge each one against §1–5 and `belay-design`'s anti-slop gate.

## Where Belay differs, on purpose
- **The notch is pure black,** not `#121212`, so it merges with the hardware.
- **Status lines are mono uppercase** (`docs/design.md` §4). dusk avoids tracked capitals; we keep them for machine status only.
- **SF, not Geist.** Native first.
- **`A · B` meta** is allowed in status lines ("PLAYING · SPOTIFY").
