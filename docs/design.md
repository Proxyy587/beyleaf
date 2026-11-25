# Belay design rules

> **Sources and credit:**
> - Adapted from OpenMausBot's `DESIGN.md` (Apache-2.0, `third_party/OpenMausBot/DESIGN.md` @ 310e731e). Modified by Belay contributors for a native macOS notch app.
> - Feel references, from **public websites only** (no code, assets or text copied: ADR 0008):
>   - **Aria** (joinariapp.com): a pure-black notch list; app icon, title and a quiet mono status line per row; right-aligned mono durations; one green for "running"; generous air; a dithered pixel backdrop and frosted pill navigation on the site.
>   - **dusk bot** (dusk.bot): a clean sans paired with a pixel display face for brand moments; warm near-black and off-white neutrals; pill and 14–16 px radii.

**What exists and why** (every element, its user job, states and status, plus the purpose test and the cut list) is in `docs/ui-inventory.md`. Nothing ships on the notch without a row there.

These are rules, not suggestions. Every Belay surface follows them: the notch, cards, the Settings window and the website. If a rule stops you doing the right thing, change it in the same commit and say why.

**Tokens live in one file:** `apps/mac/Sources/Belay/Design/Tokens.swift`. No view hard-codes a colour, size, radius, font or animation.

**Everything is customizable (ADR 0015).** Tokens resolve from the user's theme: fonts, colours, surface (solid or glass), roundness, width, density, row order, and motion (speed, blur, bounce). The values below are the **Midnight** defaults. Every built-in preset must pass §2. What a user does with their own theme is up to them.

**Blur is part of the motion language:** content reveals with a subtle blur-in, and changing text (track names, wing contents) blur-swaps. Blur is 6–10 pt by default, ≤ 300 ms, and off under reduced motion.

## 1. Principles

1. **Calm by default.** The closed notch is almost invisible. Nothing blinks, counts or moves unless something real is happening. When in doubt, leave it out.
2. **Native first.** SF Pro, SF Mono, SF Symbols, real macOS controls and shortcuts. It should feel like Apple shipped it, with a personality.
3. **Name it, don't explain it.** A good label beats a sentence. No taglines, no filler subtitles.
4. **Only real things.** Never show a feature that doesn't work yet ("coming soon", greyed teasers, fake data). The roadmap lives in docs.
5. **Every state is designed:** nothing playing, offline, no battery (desktop Macs), long titles, no notch, external displays, reduced motion, and light and dark Settings.
6. **Everyone can use it:** keyboard, VoiceOver labels, reduced motion and contrast.
7. **Borrow the feel, never the form.** Our signature parts (the pixel climber, the rope, the catch) are ours.

## 2. Anti-slop list (instant review failures)

| ✗ Slop | ✓ Instead |
|---|---|
| Decorative gradients (icons, plates, text) | Flat surfaces. Colour only where it means something. |
| Icons in tinted squares or circles | Bare SF Symbols. Only album art or an app's own icon gets a plate. |
| A card with fill **and** border **and** shadow | One of: a tint *or* a hairline. Only floating things get shadows. |
| Cards inside cards | Space and a group label |
| A fourth text colour via random opacity | Three ink levels (§3) |
| Many font sizes; a rounded face "for friendliness" | The type scale (§4) |
| Emoji or unicode as UI (●●○, ✨) | SF Symbols, or a real control |
| Taglines and filler ("holding the rope", "Your AI buddy!") | Nothing, or a value |
| "Coming soon" placeholders | Ship it, or don't show it |
| Looping or bouncing idle animation | Still at rest (§7) |
| Exclamation marks, Title Case | Sentence case, calm, short |
| Several accent colours | One accent, used rarely |

## 3. Colour

**Notch surfaces are pure black (`#000`)** so the open panel merges with the hardware notch.

| Job | Token | Midnight (default) |
|---|---|---|
| Notch ground | `Tok.notch` | `#000000` |
| Raised row / card | `Tok.raised` | ink at 6% |
| Hover / pressed fill | `Tok.hoverFill` / `Tok.pressedFill` | ink at 8% / 12% |
| Hairline | `Tok.hairline` | ink at 10% |
| Primary text | `Tok.ink` | `#F5F5F3` (warm off-white) |
| Secondary text | `Tok.ink2` | ink at 62% |
| Tertiary text | `Tok.ink3` | ink at 48% (4.6:1 on black; 40% was 3.4:1) |
| Accent | `Tok.accent` | user-selectable, default `#2F7BF2` |
| Live / running | `Tok.live` | soft green `#5BD08A`, **only** for "running / playing / connected" status text and dots |
| Warning / danger | `Tok.warning` / `Tok.danger` | amber / red, only for real warnings and errors |

**Rules:**
- **Hierarchy comes from ink level and size, never colour.**
- **Accent is rare:** the selected state, focus and the one primary action.
- **Status colours mean status.** Low battery is warning; under 10% is danger.
- The notch is always dark. Settings follows the system appearance.
- Text clears 4.5:1 on its surface.

## 4. Type

| Use | Face / size | Weight | Ink | Notes |
|---|---|---|---|---|
| Panel title, big value (time) | SF Pro 15 | semibold | ink | |
| Row title, track name | SF Pro 13 | medium | ink | 1 line, truncate tail |
| Body, labels | SF Pro 13 | regular | ink / ink2 | |
| Meta, artist, hints | SF Pro 12 | regular | ink2 / ink3 | |
| **Status line** | **SF Mono 10, uppercase, tracking +0.08em** | regular | ink3, or `live` when running | *Only* machine status ("RUNNING · EDITING CHECKOUT.TS", "PLAYING · SPOTIFY"). Never for prose. |
| Durations, %, clock digits | SF Mono 12, `monospacedDigit` | medium | ink2 | right-aligned |
| Keycaps | SF Mono 11 | regular | ink2 | |
| Brand moments (climber tag, share card) | pixel display face | regular | ink | Candidate: Pixelify Sans (OFL; **UNVERIFIED**, check licence before bundling). Never UI text. |

**Rules:**
- Three weights only: regular, medium, semibold.
- Nothing below 10 (and only status lines at 10).
- Sentence case everywhere except status lines.
- Changing numbers use tabular digits.

## 5. Shape

| Element | Radius |
|---|---|
| Buttons, chips, pills, keycaps | full (capsule) |
| Small controls | 8 |
| Rows, cards, menus on the notch | 12 |
| App icons, album art | 6 (they are tiny) |
| Open notch bottom corners | 24 |
| Open notch ears | 12 |

- No in-between values.
- A nested shape is smaller than its container.

## 6. Space and layout

- **4 pt grid:** 4, 8, 12, 16, 20, 24 only.
- **One inset per surface:** the open notch content sits 16 pt inside the ears. Rows share one leading edge, and icons sit in a fixed 20 pt gutter.
- **A row is:** [20 pt icon] 12 [title over status line] … [right value]. Rows are 44 pt tall, with no dividers between them. Space separates.
- **Control heights:** 24, 28, 32, 36. Icon buttons are 28.
- **Open width** is the user's choice: Compact 400, Standard 440, Wide 500. Height hugs the content.
- **Group with space before lines.** Never a divider under a heading.

## 7. Motion

**Motion explains a change; it never decorates.**

| Token | Use | Value |
|---|---|---|
| `Tok.open` | notch opens | spring response 0.34, damping 0.86 (~300 ms) |
| `Tok.close` | notch closes | spring response 0.28, damping 1.0 |
| `Tok.reveal` | content after the shape opens | ease-out 180 ms, +40 ms after the shape |
| `Tok.hover` | hover / pressed fills | ease-out 120 ms, colour and opacity only |

- **300 ms ceiling.** Nothing scales from zero; content grows from 96% and fades.
- **No idle loops.** Only really-live status animates: the music bars while audio plays (driven by the real audio, ADR 0017; ink, with a small lift on each beat), a climber while an agent works.
- **The climber holds still at rest.**
- **Reduced motion:** springs become 150 ms fades, and the music bars become a static glyph (no audio capture).

## 8. Feel (haptics and sound)

- **Haptics are for hover only.** One `.alignment` tick when the notch opens under your finger. Never on a click
  (the trackpad already clicks, so a second buzz reads as a double tap) and never for an event you didn't touch.
- **Sounds are off by default.** Each has a visual twin.
- Both are toggleable in Settings.

## 9. Icons

- **SF Symbols**, weight `.medium`, 13–14 pt beside text, 15 pt in 28 pt buttons. **Bare.**
- A real **app icon** (from `NSWorkspace`) represents an app: the music player, an agent's terminal, a screenshot's source.
- One symbol, one meaning.
- Icon-only buttons have an accessibility label and a tooltip.

## 10. Words

A calm, competent climbing partner.
- Sentence case; no exclamation marks.
- **Buttons say what they do:** "Open Settings", "Copy", "Quit Belay".
- **Show values:** "Wi-Fi · Home", "61% · On battery", "Not playing".
- **Errors say what happened and what to do:** "Couldn't reach Spotify. Open it and try again."
- **Empty states are one line**, plus an action if there is one.

## 11. Settings

- **A real macOS window:** a sidebar of sections and grouped `Form`s with native controls. It follows the system appearance.
- Values, not paragraphs. A hint line only when the label can't carry it.
- **Changes apply live.** No Save button.
- **Accounts never collect credentials** (ADR 0004). An AI account is "your installed CLI, signed in its own way". Belay shows found/not found and the version, never tokens.

## 12. Review checklist (paste into UI commit bodies)

- [ ] `Tok` tokens only
- [ ] Passes the anti-slop list (§2)
- [ ] Type scale, three weights, sentence case (mono caps only for status lines)
- [ ] Every state designed (empty, long text, offline, no battery, no notch)
- [ ] Motion ≤ 300 ms, no idle loops, reduced motion
- [ ] Icons bare and labelled
- [ ] Screenshot checked in the real notch (`apps/mac/scripts/run.sh --expand`)
- [ ] Idle CPU < 1%
