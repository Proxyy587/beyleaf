# Performance: budgets, numbers, and how to measure

**Measured:** 2026-11-25 on a MacBook Air (M-series, 60 Hz display), debug build, `perf/smooth`.
Belay sits on screen all day, so it must cost nothing at rest and very little while moving. Every UI change is checked against these budgets (`docs/design.md` §12, the `swiftui-macos` skill).

## Budgets and where we are

| State | Budget | Measured | How |
|---|---|---|---|
| Closed, idle | **0.0–0.3% CPU** | 0.0% | `top` (see below), `--no-player` |
| Closed, timer wing | ≤ 0.3% | 0.0% | `--start-timer 25` |
| Closed, music bars moving | ≤ 3% | ~1.9% drawing (was 11–20%) | `--beat-demo` (synthetic levels, no audio) |
| Music analysis | ≤ 0.1% | 0.018% of real time (60 s of audio in 11 ms) | `scripts/beat-selftest.sh` |
| Real audio tap while music plays | ≤ 3% total | **UNVERIFIED** (needs music playing; the agent never starts playback) | play a song, then `top -pid $(pgrep -x Belay)` |
| Open, idle | ≤ 0.5% | ~0.1% | `--expand --no-player` |
| Open, timer ticking | ≤ 1% | ~0.7% (was ~10%) | `--expand --start-timer 25` |
| Open/close animation | ≤ 8.3 ms CPU per frame (120 Hz) | ~3 ms per frame (~70 ms per transition) | `--cycle-open` |
| Memory at rest | ≤ 40 MB | 17 MB physical footprint | `footprint $(pgrep -x Belay)` |
| Launch, warm | our setup ≤ 100 ms | ~60 ms ours + ~210 ms OS before `main()` | log `app.belay.mac:perf` "ready … ms" |

## How to measure
- **CPU:** `P=$(pgrep -x Belay); top -l 9 -s 1 -pid $P -stats pid,cpu | awk -v p=$P '$1==p {print $2}'`. Drop the first sample (it's always 0.0) and read 8 seconds.
- **Where time goes:** `sample Belay 4 -file out.txt`, then look under "Call graph". `NSDisplayCycleFlush` plus `NSHostingView.layout` means SwiftUI is re-laying out.
- **Memory:** `footprint <pid>`, the same number as Activity Monitor's Memory column.
- **Launch:** `/usr/bin/log show --last 1m --predicate 'subsystem == "app.belay.mac" AND category == "perf"'`.
- **Live in the app:** Settings → General → Performance shows Belay's own CPU and memory every 2 s.
- **Debug flags** (all `#if DEBUG`, via `apps/mac/scripts/run.sh`): `--no-player`, `--expand`, `--start-timer <min>`, `--beat-demo`, `--cycle-open`, `--flash-copied`, `--edit-widgets`, `--beat-probe <bundle id>`.

## Rules that keep it fast (each one was a measured fix)
1. **Nothing continuous goes through `@Published`.**
   - 30 SwiftUI updates a second re-lay out the whole notch window (11–20% CPU).
   - Continuous visuals are `CALayer`s moved by a display link, fed through a lock (`BeatBarsLayer.swift`).
2. **Display links park themselves.** Once the motion settles with no new data, the link pauses, and the next write wakes it.
3. **Never `TimelineView(.periodic(from: .now, …))`.**
   - The schedule restarts on every re-render and fires at once, so a 1 s tick became a continuous redraw (12%).
   - Use `Ticking`, which has a fixed anchor and only ticks while visible.
4. **No per-tick transitions.** A rolling-digit `.numericText()` plus a ring animation every second cost about 10%, for motion too small to see.
5. **Fixed-size hosting views:** `sizingOptions = []` on the notch's `NSHostingView`, since the canvas never resizes.
6. **Work only while visible:** music bars, timers and progress all stop when hidden (`setProgressActive`, `updateBeat`, `Ticking(active:)`).
7. **Never query the system while rendering.** The running player is cached and updated on app launch/quit notifications, not looked up via LaunchServices in `body`.
8. **Use Accelerate on audio threads:** strided `vDSP` calls, not scalar loops per sample.

## Performance modes (Settings → General → Performance)
| Mode | Animation cap | Blur | When |
|---|---|---|---|
| Automatic (default) | display max (60/120 Hz) | on | Switches to Save energy in Low Power Mode |
| Save energy | 30 fps | off | Always |
| Smoothest | display max | on | Always |

## Open
- Measure the real tap with music playing and record it here.
- Launch: about 210 ms happens before `main()` (frameworks). It could shrink by deferring CoreWLAN and Network until first use. UNVERIFIED gain.
