# Notch widgets: customizable, never empty

**Status:** v1 is being built on `feat/notch-redesign` (2026-11-25). Decision record: ADR 0019. Look and feel: `dusk-feel`, `docs/design.md`.

> **In one line:** the open notch is a set of widgets the user picks and orders. The layout packs them so there's
> never a hole, a placeholder or a dead strip. A widget with nothing real to show takes no space.

## 1. Problems with the current panel (screenshot, 2026-11-25)
1. **Dead band.** The strip beside the camera holds only a gear: 37 pt of black across the panel's full width.
2. **The status line does too much.** "PLAYING · ARTIST · MUSIC" is mono, uppercase and green. The artist is content, not machine status, and the player name repeats what the artwork already says.
3. **Controls on their own row.** Prev, play and next sit centred under the hero, adding 36 pt and leaving empty space either side.
4. **Floating content.** Rows sit straight on black with no surface, so they read as loose text (dusk's "notice tone" rule).
5. **"Not playing" and "Nothing shown" lines.** These are placeholders: they take a row to say there's nothing.

## 2. Principles
- **No dead space.** Every visible pixel row of the panel is either content or the one consistent inset.
- **Present or gone.** A widget is **live** (real content), **ready** (nothing live but one useful action, shown compact), or **gone** (takes no space). There's never an "empty" state on screen.
- **The user decides what and in what order.** We decide *how* it packs.
- **Alive, not busy.** Things move because something real changed: a countdown ticks, a track swaps, a tile arrives. Nothing loops at rest (`docs/design.md` §7).

## 3. Anatomy of the open panel

```
 ┌─ ear ─┐                                         ┌─ ear ─┐
 │ [mark]                ███ camera ███          [⊞] [⚙] │  ← band (the notch line's height)
 │ ┌─────────────────────────────────────────────────────┐ │
 │ │ [art]  Title                       ⏮  ⏯  ⏭          │ │  ← wide widget (Now playing)
 │ │        Artist                                       │ │
 │ │        0:41 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -3:12  │ │
 │ └─────────────────────────────────────────────────────┘ │
 │ ┌──────────────────────────┐ ┌────────────────────────┐ │
 │ │ ◔ 24:13                  │ │ [thumb] Copied         │ │  ← two tiles share a row
 │ │ TIMER          ⏸   ✕     │ │ 2 MIN · 1.2 MB  ⧉  ⌕   │ │
 │ └──────────────────────────┘ └────────────────────────┘ │
 ╰─────────────────────────────────────────────────────────╯
```

**The band** (beside the camera, the notch line's height):
- **Left: the brand slot.** `BrandSlot` shows the Belay mark in ink3. It's reserved for the logo (being designed separately) and, from A1, it becomes the agents' status light: the mark's point turns live green while an agent works.
  - The slot has a fixed size (16 pt glyph in a 28 pt box), so a new logo drops in without a layout change.
- **Right:** "Edit widgets" (`square.grid.2x2`) and Settings (`gearshape`), both bare 28 pt icon buttons.
- **No notch** (external display): the band becomes the panel's first line, with the same contents.

**Widgets** sit on tonal cards (`Tok.raised`, radius `Tok.rCard` 14). There's no border or shadow, a 12 pt inset, and an 8 pt gap.

## 4. Widget sizes and the packing rule

Each widget, in its current state, is **wide** (full row) or a **tile** (half row).

```
rows = []
for w in user order, keeping only live or ready widgets:
    if w is wide:                                 rows.append([w])
    elif the last row is one tile waiting:        that row gets w as its second tile
    else:                                         rows.append([w])   (a tile waiting)
any row left with one tile: that tile is promoted to wide (its wide layout), so no half-row hole is ever drawn
```

- **Order is the user's.** Packing never reorders. A wide widget between two tiles stays between them, and each lone tile is promoted.
- **Promotion is a real layout,** not a stretched tile. Every widget designs both its tile and its wide form.
- The function is pure (`WidgetLayout.rows`) with a `swiftc` self-test (`scripts/widgets-selftest.sh`), like the beat analyzer.

## 5. Widget catalogue (v1)

| Widget | Live | Ready (nothing live) | Gone | Tile form | Wide form |
|---|---|---|---|---|---|
| **Now playing** | A track is known | A player is running but nothing is known or it's stopped: "Spotify" + Play | No player running | Art 36, title, play/pause | Art 56, title, artist, progress + times, prev/play/next on the right |
| **Timer** (new, **off by default**: a side option) | Counting down or done | − [25m] + ▶: any length 1–180 min (1-min steps to 10, then 5, then 15); drag the number to scrub; the last length is remembered | Never (it always has an action) | Ring + mono countdown, pause, stop | Same, with the end time ("ends 14:32") |
| **Last screenshot** | Copied within the last 30 min | — | Otherwise | Thumbnail, "Copied", age · size, copy again, show in Finder | Same, with a larger thumbnail |
| **Agents** | planned A1 | — | — | sessions list (planned) | — |

Defaults: Now playing and Last screenshot on, Timer off (it's a convenience, not the product), in that order.

**Why Timer passes the purpose test:** it's a real job (time-boxing a task while agents run). It's live (a ticking countdown and a done moment). The menu bar doesn't do it. It has designed ready, running, paused and done states. It isn't a readout. A Calendar "next event" widget is a candidate for v2: it needs the Calendar permission and has to be verified first.

**Timer in the closed notch:**
- **While it runs** (and music isn't playing), the wings show a small progress ring and the minutes left. Music outranks the timer when both run, and hovering shows both.
- **When it ends,** it flashes "Done" with a `.levelChange` haptic for 4 s.

## 6. Customization UX
1. **In the notch:** "Edit widgets" in the band turns the panel into its edit state, in place, with the same width.
   - Every widget in the catalogue becomes one compact line: [symbol] name … [↑][↓][switch].
   - Changes apply instantly and the panel resizes as you go. "Done" (same spot as the edit button) returns.
   - Edit mode keeps the panel open until "Done" or the pointer leaves.
   - Right-clicking any widget gives **Move up · Move down · Hide · Edit widgets…**
2. **In Settings → Widgets** (an essential, not advanced): a native `List` with drag to reorder, a switch per widget, a footer that names the packing rule in one line, and a Reset.
3. **Persistence:** `AppSettings.widgets: [WidgetSetting(kind, enabled)]` in UserDefaults.
   - The rows' old home, `Theme.rows`, is migrated once and then ignored.
   - Unknown kinds are dropped and new kinds are appended (disabled if they need a permission).
   - Widgets are *what* the notch shows. A theme is *how* it looks. So applying or importing a theme never changes widgets (ADR 0019).

## 7. Motion (one per kind, `dusk-feel` §4)
| Change | Motion |
|---|---|
| Panel opens | `Tok.open`; cards blur-reveal, staggered 25 ms |
| A widget arrives or leaves, or rows repack | `Tok.open` on the panel height. Cards use `blurReplace` and move to their new frame (`matchedGeometryEffect` by kind) |
| Countdown digit | `.contentTransition(.numericText(countsDown: true))` |
| Press | Scale 0.94 down in 120 ms, then release with the dusk overshoot (`Tok.press`) |
| Enter or leave edit mode | Blur-swap of the panel body, `Tok.reveal` |
| Reduced motion | Fades only, digits swap without rolling |

## 8. States to verify (screenshots)
- Open: playing only; playing + timer running + screenshot; timer ready only; no player and no screenshot (timer presets only); every widget off (the edit button is the only content, as one line: "No widgets. Edit widgets").
- Long title, paused, timer done, edit mode, no-notch display, reduced motion, glass theme.
- Closed: timer wing, timer done flash, music outranking the timer.

## 9. Not now
- Drag-to-reorder inside the notch itself. The panel is non-activating, and SwiftUI drag and drop there is UNVERIFIED. Settings has native drag; the notch has ↑/↓ and the context menu.
- Calendar, clipboard history, file shelf (conversions), weather. Each needs its own purpose-test row first.
