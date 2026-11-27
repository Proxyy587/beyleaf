# Buddy pointers: a buddy on your screen, moving like a person

**Status:** design for Phase 6 (Mac control) of `docs/jarvis-roadmap.md`. Nothing here is built. Written 2026-11-27.
**Builds on:** `docs/buddies.md` §3 (surfaces) and §6 (tiers, safety), `docs/design.md` §2/§7, ADR 0005/0011 (rope), ADR 0022.
**Clean room:** behaviour and numbers below are our own choices. `refs/duskbot` (PolyForm) was read for feel only, nothing copied.
`refs/clicky` and `refs/openclicky` are MIT and may be vendored (`scripts/vendor.sh`) with their notice (ADR 0003/0008).

> **In one line:** when a buddy works on your Mac, its small sprite leaves the notch wing, flies to the thing it means,
> points, clicks or types, and returns. It is a *pointer*, not a mascot parade: still at rest, absent when idle, gone the
> instant you touch the mouse.

## 1. Two modes, one pointer

| Mode | What moves | Tier (`buddies.md` §6) | Permission | Typical use |
|---|---|---|---|---|
| **Point** | Only the overlay sprite. The real cursor never moves. | 0 Observe | Screen Recording (already asked) | "where is the export button?", fig explains, willo cites a line |
| **Drive** | Overlay sprite **and** the real cursor and keys (CGEvent), same path, same timing | 2 Hands | Accessibility, plus a session start card | "pip, archive these emails" |

Point mode needs no Accessibility and is the default for any buddy that merely explains. A buddy asks for Drive only
when it must click or type; the planner marks every step `point`, `click`, `type` or `outward` (sends, posts, deletes).

## 2. Anatomy

### 2.1 Parts

| Part | Spec | Notes |
|---|---|---|
| **Sprite** | The buddy's own art (smooth or pixel, user's choice), rendered once to a bitmap per state. **22 pt** default, **28 pt** "large pointer" setting, never below 20. Hotspot (the exact target) is the sprite's top-left corner; the body sits 10 pt down-right of the hotspot so it never covers the target | One bitmap each for eyes open, closed, happy at @2x and @3x, cached. No per-frame SwiftUI |
| **Hotspot mark** | 2 pt ring, 12 pt diameter, centred on the target, only while *pointing* or *clicking*. Ink with a 1 pt black underline so it reads on any background | Shows exactly where, even when the sprite is a few px off |
| **Trail / tail** | **None.** No streak, no glow, no comet. The arc itself is the feedback | OpenClicky's streak is cut (anti-slop: decoration) |
| **Name chip** | Capsule, black 90%, SF Pro 11 medium, ink, 8 pt side padding, 20 pt tall, 6 pt dot in the buddy's main colour. Sits right of the sprite (flips left at a screen edge) | Shown: first 1.5 s of a task, whenever more than one buddy is visible, and always in a state with a word (§2.2). Hidden otherwise |
| **Control ring** | 1.5 pt `Tok.live` ring hugging the sprite, **Drive mode only, for the whole task** | The "buddy is controlling" mark (§6) |
| **Ripple** | One ring, 6 → 28 pt, opacity 0.5 → 0, 280 ms ease-out, buddy colour | Click only; never loops |

Layer budget: at most **6 CALayers per pointer** (sprite, hotspot, ripple, chip bg, chip text, ring). No shadow layers, no blur
filters (off-screen passes cost GPU). Chip text is a CATextLayer set only when it changes.

### 2.2 States

| State | Where | Look | Chip text (sentence case) | Motion | Ends when |
|---|---|---|---|---|---|
| **Docked** | In the notch wing (existing `BuddyView`, `buddies.md` §3). **No overlay window exists** | Mood `idle`, still | none | none (design.md §7) | a task starts |
| **Flying** | Along the path | Mood `hover`, eyes look along travel (`lookLeft`/`lookRight`, one switch at take-off) | name | §3 | arrives |
| **Pointing** | At target, hotspot ring on | Mood `hover` (4% lift, existing) | name + what ("export button") | ring fades in 120 ms; then still | step done, or dwell over |
| **Clicking** | At target | Press scale 1 → 0.92 (70 ms), ripple | none | §3.4 | release + 60 ms |
| **Typing** | At the focused field, sprite 14 pt below-right of the caret so it never covers text | Mood `hover`; no ring on the field | "typing" | none on the sprite; keys are the motion | last key |
| **Thinking / waiting** | Holds still beside its last target | Mood `hover`, eyes forward, **no animation** | "thinking" (waiting on the engine) or "waiting for you" (rope card open) | none. No dots, no bob: OpenClicky's dots and bob are cut as idle loops | engine replies, or card answered |
| **Handing back** | Slides 24 pt away from the cursor, 180 ms ease-out, then fades 150 ms | Control ring off, mood `idle` | "paused. tap to continue" | one slide | user acts, or docks after 6 s |
| **Error / blocked** | At the failed target | Ring in `Tok.warning`; mood `idle` | "can't find it" / "blocked: needs you" | one 2 pt horizontal nudge, two cycles, 240 ms total | user dismisses, or auto-dock after 8 s. Detail goes to a notch card, not the pointer |
| **Returning** | Back to the wing | as Flying | none | flight, then wing sprite appears in the same frame the overlay sprite is removed | docked |

Hand-off between wing and pointer must be pixel-identical (same bitmap, same size at take-off): UNVERIFIED until built.
At take-off the wing slot shows nothing (the buddy is "out") and a blink-once on return signals done (`happy` 600 ms if the task succeeded).

## 3. Human-like motion

All motion is computed by a **pure planner** (§8), then played by Core Animation. Randomness is seeded per task so tests are exact and replays identical.

### 3.1 Flight

| Parameter | Value | Why |
|---|---|---|
| Path | Cubic Bezier P0→P3. P1 = P0 + 0.30·v + n·k. P2 = P0 + 0.75·v + n·0.6k. `v` = P3−P0, `n` unit perpendicular, `k` = side × clamp(0.12·d, 6, 70) pt × seeded 0.7–1.3 | Hands arc, they don't ruler-line. Bow is up unless that leaves the display, then flips |
| Short hop (d < 24 pt) | Straight line, 160 ms, ease-out | An arc on a tiny move reads as a wobble |
| Duration `T(d)` | `clamp(200 + 150·log2(1 + d/40), 260, 1100)` ms | Fitts-like: near targets are quick, far ones don't take forever. d=40 → 350, 100 → 471, 300 → 664, 800 → 859, 1900 → 1040 |
| Easing | `cubic-bezier(0.30, 0, 0.15, 1)`: peak speed at ~38% of the time, long gentle landing | People accelerate fast and brake slow |
| Overshoot (d ≥ 240) | Seeded coin: **overshoot** by clamp(0.012·d, 3, 9) pt along the end tangent, settle back over the last 22% of T (140–220 ms, ease-in-out); or **undershoot**: stop 5–9 pt short and correct in 110 ms | One correction, never two. Skipped for d < 240 |
| Jitter | Perpendicular offset = 0.8 pt·sin(2π·3Hz·t+φ1) + 0.7 pt·sin(2π·7Hz·t+φ2), times envelope sin(π·t). Max 1.5 pt, **zero at both ends** | Hand tremor, so the end point is exact |
| Mid-flight size | ×1.00 constant (OpenClicky swells 30%: too big for a 22 pt sprite). Landing: 0.96 for 80 ms | Subtle |
| Rotation | None. The sprite stays upright | A face that tumbles is cartoonish |
| Speed setting | None in v1 | Fewer options; revisit if users ask |

### 3.2 Rhythm around an action

| Moment | Duration | Notes |
|---|---|---|
| Pause before a click (hover dwell) | 90–180 ms seeded, +40 ms if the flight was ≥ 600 ms | Human "aim, then press" |
| Reading dwell (point to explain) | `clamp(400 + 35·words, 600, 2500)` ms, +300 ms in reduced motion | Time to read the caption the buddy says or shows |
| Between steps with no flight | 120–260 ms | Never back-to-back like a script |
| After a page or window change | wait for the screen to settle (no pixel change > 2% for 250 ms), max 3 s | Avoids clicking a stale layout. UNVERIFIED how the settle check is best measured |
| Thinking gap | none added; real engine latency is the gap | Do not fake delay |

### 3.3 Typing

| Parameter | Value |
|---|---|
| Inter-key delay | Lognormal, median 55 ms, σ 0.35, clamped 28–190 ms |
| After a space | +20 ms |
| After `.` `,` `;` `:` `?` `!` or newline | +90–160 ms |
| Hesitation | 2% of keys get +250–400 ms |
| Key down to key up | 35–70 ms |
| Long text (> 120 chars) | Median 22 ms, clamp 12–45, no hesitation. Still real key events, so the clipboard is **never** used or touched |
| Sprite while typing | Still. Typing needs no extra animation |
| Secure fields | Never typed into. Buddy stops and hands back ("password field: yours") |

### 3.4 Click

`pause (90–180) → move done → mouseDown at t0 → sprite scale 0.92 and ripple start at t0 → mouseUp at t0 + 60–110 ms → scale back 70 ms`.
Double click: second down 80–120 ms after the first up. Drag: down, path flight (`T(d)`), up after a 90–150 ms hold.

### 3.5 Alive, but never looping

- **At rest the pointer does not move**: no bob, no breathing, no cursor wiggle. A hovering buddy is a still image.
- Motion appears only because something real happened: a flight, a click, a keystroke, a state change. One blink when a task completes.
- Every animation is finite and ≤ 300 ms except flights (travel, ≤ 1100 ms) and the reading dwell (a wait, not motion).

### 3.6 Yielding to you

| Signal | Detection | Response | Budget |
|---|---|---|---|
| **Esc** | global key monitor, keyCode 53 | Abort the whole task, release any held button or key, dock | **≤ 50 ms** to stop, ≤ 300 ms to dock |
| **Any real mouse move > 3 pt, click, scroll, key, trackpad gesture** | global monitors plus a check that the cursor is still where we left it (> 3 pt away = you moved it). Our own events carry a tag in `eventSourceUserData` and are ignored | **Hand back** (§2.2): stop sampling, release everything, keep the task paused | ≤ 50 ms |
| User on the keyboard in another app | typing in any key event we did not post | Same as above | ≤ 50 ms |
| User stays idle after hand-back | none | Task stays paused until they tap "continue" in the notch; it never resumes by itself | - |

Synthetic-event visibility to monitors and whether Input Monitoring is needed: UNVERIFIED. Fallback is polling
`CGEventSource.secondsSinceLastEventType` at 30 Hz during a task, which needs no permission.

## 4. Several buddies at once

| Rule | Value |
|---|---|
| Pointers on screen, total | **3** max. A 4th buddy waits in the wing with state "queued" |
| Drive actors | **1** at a time, globally (there is one real cursor). Others may only Point |
| Chip | Shown on every pointer when 2+ are visible. Name is the primary cue; the dot colour is secondary (never colour alone) |
| Same-hue buddies | If two main colours are within ΔE 15, the later one's chip dot becomes a ring (shape cue) |
| Hover slots | Around a target: 8 slots on a 28 pt radius, order lower-right, lower-left, upper-right, upper-left, then sides. A pointer takes the first free slot; another's slot is free once it has docked |
| Minimum separation at rest | 36 pt between sprites; chips flip sides if they overlap |
| In-flight avoidance | If a path comes within 24 pt of another pointer's rest point, bend `k` away from it (up to 1.6x). No dodging mid-air, to stay cheap and calm |
| Same target | The second buddy waits; two buddies never act on one control at once (also a correctness rule, not just visual) |
| Order | Arrival is FIFO. A new pointer takes off only after the previous finishes its take-off (150 ms gap) so they don't launch as a flock |

## 5. Overlay window engineering

### 5.1 Lifecycle and shape

| Item | Spec |
|---|---|
| Window | `NSPanel`, `.borderless` + `.nonactivatingPanel`; `ignoresMouseEvents = true`; `isOpaque = false`; `backgroundColor = .clear`; `hasShadow = false`; never key, never main |
| Level and Spaces | `.screenSaver` level; `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]` so it shows over full-screen apps and every Space |
| One per display | Created when a pointer first needs that display. **Destroyed 1 s after the last pointer there docks.** No buddy acting means **no window at all** (cost zero, docked buddies live in the notch wing) |
| Size | **Option A:** the full display frame, layer-hosted, so a flight never resizes the window. **Option B (fallback):** a panel hugging the flight's bounding box + 80 pt margin, resized between legs. Choose A unless `footprint` shows the full-size backing store costing > 8 MB. UNVERIFIED which is cheaper; measure first |
| Content | A plain `NSView` with `wantsLayer = true`. **No SwiftUI in the overlay.** Sprite bitmaps are rendered once with `ImageRenderer` from `BuddyView` and set as `layer.contents` |
| Drawing | Core Animation only. Flights are one `CAKeyframeAnimation` on `position`: the planner samples the curve, jitter and easing into one point per ~16 ms (at most 70 points per flight), `calculationMode = .linear`. The render server plays it, so the main thread does **0 work per frame** during Point flights |
| Drive mode | The real cursor needs events, so a 60 Hz `DispatchSourceTimer` (only during a flight, ≤ 1.1 s) posts `mouseMoved` from the same samples, and the layer follows with implicit animations off. Not used in Point mode |
| Capture | `sharingType = .none` by default so screen share and recordings do not show the pointer. Hide the overlay for one frame (`alphaValue = 0`) before every Belay screenshot so the model never sees its own pointer. Setting "show pointer to viewers" is off. macOS 15+ ScreenCaptureKit may ignore `sharingType`: UNVERIFIED, test with a real capture |
| Screen share | When a share is detected (or the user pauses Belay), Drive tasks still show the local pointer. Viewers seeing a cursor jump with no pointer is a known, documented side effect |
| Full-screen / Mission Control | Level and behaviour above; on entering Mission Control or Exposé the pointer **hides** and the task pauses (a click there would hit the wrong thing). UNVERIFIED notification names |
| Displays changing | On `NSApplication.didChangeScreenParametersNotification` mid-task: abort the task (hand back), rebuild windows lazily. Never retarget by guesswork |

### 5.2 Budgets (add to `docs/performance.md` when built)

| Metric | Budget | Measured by |
|---|---|---|
| Closed, idle, no task | 0.0–0.3% CPU, **0 overlay windows** (same as today) | `top -l 8 -s 1 -pid $(pgrep -x Belay)` |
| Point flight | main-thread CPU ≤ 2% average over the flight; render at the display rate (60 or 120 Hz), because the compositor plays it | `top`, Instruments Core Animation |
| Drive flight (sampler) | ≤ 5% over the 1.1 s flight; 60 events per second | `top` while `--pointer-demo` drive fixture is mocked |
| Pointer at rest (pointing, thinking) | **0.0% CPU**, no timers, no CADisplayLink | `top` |
| Memory while active | ≤ 8 MB above baseline per display; sprite bitmaps ≤ 1 MB each buddy | `footprint $(pgrep -x Belay)` |
| Take-off latency | ≤ 100 ms from step start to first movement (window creation included; pre-warm the panel once at task start) | log timestamps |
| Abort latency | ≤ 50 ms input to everything stopped | timestamp in the guard test |
| Planner | ≤ 1 ms per flight | self-test timing |

### 5.3 Multi-display flights

Each display has its own overlay, so a flight to another display is split into two legs: to the nearest edge point of the current
display, then from the matching edge point of the destination display to the target. Pointers cross displays at the shared edge.

| Piece in `refs/openclicky/macos/OpenClicky/OpenClicky/` | Verdict |
|---|---|
| `CursorFlightPlanner.swift`: `nearestPoint(to:in:)`, `firstLeg`, `finalLeg`, the two-leg split, `sequence` for observers (91 lines, pure) | **Reuse as is** (vendor, keep the MIT notice). Extend `Purpose` with `toTarget` and `dock` (today only `toMouse`) |
| `CursorBuddyMotion.swift` `CursorFlightPath`: the `Pose`/`progress(afterSeconds:)` idea (position from the clock, so a busy thread drops frames rather than stretching a flight), `calm` flag, `landingScale` | **Reuse the idea, rewrite the code**: cubic, Fitts duration, overshoot, jitter, no rotation, planner returns samples for Core Animation |
| Constants: 800 pt/s, 0.4–1.4 s, lift 20% ≤ 80 pt, swell 30%, resting rotation -35° | **Replace** (§3.1). A linear speed makes far flights too slow; swell and rotation suit a triangle cursor, not a sprite |
| `CursorTravelStreak` (6-piece fading tail) | **Drop** (no trail) |
| `CursorWaveform`, `CursorThinkingDots` (1.2 s loop), `CursorIdleBob` (rounds of bobbing) | **Drop**: voice-bars could return for push-to-talk in Phase 7 and only while really listening; dots and bob are idle loops |
| `OverlayWindow.swift` (the drawing, not read in full for this spec) | UNVERIFIED. Likely SwiftUI per frame: do not vendor |

## 6. Safety UX (non-negotiable)

| # | Rule | How it shows |
|---|---|---|
| 1 | **Visible "buddy is controlling" state** whenever Drive is live | Control ring on the pointer (§2.1), the wing's sprite slot shows the live-green eyes, and a one-line status in the wing: `CONTROLLING · PIP · ESC TO STOP` (SF Mono 10 status line, design.md §4). All three, for the whole task |
| 2 | **Esc or any user input aborts instantly** | §3.6. ≤ 50 ms. The notch also has a Stop button on the same status line. Held keys and buttons are always released on any exit path (a `defer`, plus a watchdog that releases on crash restart) |
| 3 | **Rope card before outward actions** | The step is marked `outward` in the plan. The pointer flies to the control and **holds without pressing**; the card (ADR 0005 drop) shows the exact action and buddy; chip says "waiting for you". Allow ↵ presses; Deny ⎋, no decision, or timeout = no click. A tainted chain (ADR 0011) always asks |
| 4 | **Session start card** | "Pip wants to control Mail" before the first Drive flight (`buddies.md` §6). "Always for this app" is a user rule, never inferred |
| 5 | **Never take the mouse from you** | Before a Drive task starts, the cursor must have been idle ≥ 1.5 s (`secondsSinceLastEventType`). If you are active, the buddy waits ("waiting for you to pause") up to 30 s, then asks. **Exception:** you started the task (summon bar, hotkey, a button): input guard begins 800 ms after the start, to let your hand leave the keys. After that, rule 2 applies |
| 6 | **Never type into** secure fields, password managers or another app than the one on the card | Checked per step; mismatch = blocked state |
| 7 | **One actor, scoped** | Drive is limited to the app on the start card. If the front app changes (you switched), hand back |
| 8 | **Fail closed** | Engine crash, display change, sleep, lock, fast user switch: abort, release everything, dock |
| 9 | **Never touch the clipboard** | Typing is real key events. If a future step must paste, it needs its own card and restores the prior value |

## 7. Reduced motion and accessibility

| Area | Behaviour |
|---|---|
| **Reduce Motion** (`accessibilityDisplayShouldReduceMotion`) | No arc, no overshoot, no jitter, no ripple scale. Pointer fades out at its origin (100 ms) and fades in at the target (150 ms). The ripple becomes a static ring that fades over 150 ms. Drive: the real cursor jumps once at the end of the fade. Reading dwell +300 ms. Typing cadence unchanged (it is input, not motion) |
| **Size** | 22 pt default, 28 pt large, 36 pt "extra large" if the system cursor size is raised (read from universal access prefs: UNVERIFIED key) |
| **Contrast** | Chip text ≥ 4.5:1 (ink on 90% black). Hotspot ring and control ring carry a 1 pt black underline so they are ≥ 3:1 on any background. Increase Contrast: ring 2 pt |
| **Colour-blind** | State is never colour alone: ring present vs absent, chip words, wing status line |
| **VoiceOver** | The overlay is not an accessibility element. Each step posts a polite announcement ("Pip is clicking Send in Mail"), at most one per 1.5 s; a rope card and a hand-back are announced immediately |
| **Keyboard only** | Esc stops. Return/Esc on the card. Stop and Continue reachable by Tab in the notch |
| **Motion sickness** | Max flight 1.1 s, no zoom, no screen shake, no full-screen effect |
| **No notch / external-only Mac** | Wing is absent: the buddy docks to the menu-bar status item position; the status line appears in the Belay menu bar popover. UNVERIFIED layout |
| **Light and dark wallpapers** | The pointer is pixel-art or flat with its own outline; chip is dark in both |

## 8. Test plan

### 8.1 Pure logic (no UI, no CGEvent)

New files in `apps/mac/Sources/Belay/Pointer/`: `PointerPlanner.swift` (flight, samples, legs, slots), `PointerTiming.swift`
(dwell, typing, click), `PointerGuard.swift` (hand-back and abort state machine, takes events as values and a clock closure).
Every random call takes a seeded `SplitMix64`; the clock is injected.

Self-test: `apps/mac/Tests/PointerSelfTest/main.swift` + `apps/mac/scripts/pointer-selftest.sh`, the same shape as
`Tests/WidgetsSelfTest` (`check(_ ok:, _ what:)`, `swiftc` of the logic files plus `main.swift`, prints `ok`/`FAIL`, exit non-zero on any failure).

| Group | Checks |
|---|---|
| Duration | `T(40)=350±1`, `T(300)=664±1`, `T(1900)≈1040`, never < 260 or > 1100 for any d in 0…10 000; monotonic |
| Path | Starts exactly at P0 and ends exactly at P3 (jitter zero at ends); curve stays within 70 pt of the chord; bow flips when it would leave the display; d < 24 gives a straight 160 ms path |
| Overshoot | d < 240 never overshoots; d ≥ 240 overshoot is 3–9 pt and ends exactly on target; at most one correction; seed picks over/undershoot 50/50 across 1000 seeds (40–60%) |
| Jitter | Max offset ≤ 1.5 pt over 10 000 seeds; zero at t=0 and t=1 |
| Determinism | Same seed gives byte-identical samples; different seeds differ |
| Samples | ≤ 70 points for 1100 ms; spacing ≈ 16 ms; first sample = start, last = target |
| Easing | Peak speed is at 30–45% of the time; speed at the end < 15% of peak |
| Legs | Same-display = one leg; cross-display = two, first ends on the shared edge, `sequence` increments; three displays in a row |
| Slots | 8 slots on the 28 pt ring; first free slot lower-right; a taken slot is skipped; 4th pointer is queued; sprites never closer than 36 pt |
| Collision | Path within 24 pt of a rest point gets `k` ×1.6 away from it |
| Dwell | `600 ≤ dwell ≤ 2500`; 0 words gives 600; reduced motion adds 300 |
| Typing | Median over 5000 keys 50–60 ms; all within 28–190; punctuation adds ≥ 90 ms; text > 120 chars uses the fast profile; deterministic per seed |
| Click | Down→up gap 60–110 ms; pre-click pause 90–180 ms (+40 after long flight) |
| Guard | Esc aborts within the same event; input after an 800 ms grace hands back; input inside the grace does not; our tagged events are ignored; cursor 3 pt off the expected spot = user; start refused until 1.5 s idle; held keys always released on abort (recorded by a fake driver) |
| Limits | 4th pointer queued; second Drive actor refused |
| Reduced motion | Plan has no arc, no overshoot, fade timings 100/150 ms |

### 8.2 Driver seam

`PointerDriver` protocol: `OverlayDriver` (Core Animation only) and `EventDriver` (CGEvent). The demo target can only construct
`OverlayDriver`; a CI check (`grep -L CGEvent` over the demo files in `verify-repo.sh`) enforces it. Tests use a `FakeDriver`
that records calls.

### 8.3 Debug flags (overlay only, never the real cursor)

| Flag | Behaviour |
|---|---|
| `--pointer-demo` | A scripted run: take off from the wing, fly to five fixture points (near, far, a corner, below the notch, another display if present), point, click ripple, "typing" chip with no keys sent, think, error nudge, dock. Posts **no** CGEvent, never moves the cursor, never starts audio, does not touch the clipboard |
| `--pointer-buddy <id>` | Which buddy flies (default `beepo`) |
| `--pointer-count <1-4>` | Several buddies, to see slots, chips and the cap of 3 |
| `--pointer-reduced` | Force the Reduce Motion plan |
| `--pointer-seed <n>` | Replay a motion exactly |
| `--pointer-slow <x>` | Multiply durations by x (1–4) so a screenshot can catch mid-flight |

Verify visually with `apps/mac/scripts/run.sh --pointer-demo`, `screencapture -x -R x,y,w,h` into the scratchpad, and look at each state.
Cost: `top -l 8 -s 1 -pid $(pgrep -x Belay)` (flight, rest, and after dock, where it must return to the closed-idle number and show no overlay window).

## 9. Build order (inside Phase 6)

| Step | Ships | Verified by |
|---|---|---|
| 6a | `PointerPlanner`, `PointerTiming`, `PointerGuard` + `pointer-selftest.sh` | self-test (all checks above) |
| 6b | `OverlayDriver`, one pointer, Point mode, `--pointer-demo` | screenshots of every state; CPU and `footprint`; reduced motion |
| 6c | Multiple pointers, slots, chips, multi-display legs (vendor `CursorFlightPlanner`) | `--pointer-count`, second display if present |
| 6d | `EventDriver` + guard + control state in the wing; Tier 2 only | permission asked once, hand-back by real input, Esc test (manual, by the owner) |
| 6e | Rope card wired to `outward` steps | card shown for every send; denial = no click |

## 10. Open questions

1. Full-display panel or bounding-box panel (§5.1): needs `footprint` measurements. UNVERIFIED.
2. Do global monitors see our synthetic events, and is Input Monitoring needed (§3.6)? UNVERIFIED; polling fallback is ready.
3. Does `sharingType = .none` hide the overlay from macOS 15+ ScreenCaptureKit? UNVERIFIED.
4. Should viewers of a screen share see the pointer when a buddy drives? Default no (§5.1); owner's call.
5. Pixel-perfect wing-to-pointer hand-off at take-off (§2.2). UNVERIFIED.
6. Whether Tier 2 ships in a free open-source build before signing (`buddies.md` §10.5).
7. Typing numbers (55 ms median) and click gaps are our estimates of human behaviour, not measured data. Tune by feel.
