---
name: swiftui-macos
description: How Belay's Mac app (apps/mac) is built, run, tested and verified with SwiftPM and the Command Line Tools only, and the SwiftUI/AppKit/Core Audio patterns it uses. Use whenever editing Swift in apps/mac, adding a view, setting or system integration, debugging Swift 6 concurrency errors, or screenshotting and measuring the app.
---

# SwiftUI on macOS, the Belay way

Pair with `belay-design` and `dusk-feel` (what it should look and feel like) and `belay` (commits, ADRs, verify-repo). This skill is how to build it.

## Build and run (no Xcode)
- `cd apps/mac && swift build` must end with **0 warnings**. Swift 6 language mode (tools 6.0): strict concurrency is on.
- `scripts/run.sh [args…]` builds, bundles, ad-hoc signs and launches; every argument is forwarded to the app.
  - `--expand` opens the notch; `--settings` opens Settings.
  - Debug-only: `--settings-pane <name>` (open a pane), `--no-player` (ignore Music/Spotify, to see the empty state
    while music plays), `--beat-probe <bundle id>` (start the audio tap for 5 s, logs only).
- `scripts/beat-selftest.sh`: compiles `BeatAnalyzer.swift` with a synthetic-signal test (`Tests/BeatSelfTest`) via
  `swiftc`. XCTest isn't available with the CLT alone, so pure logic gets a `swiftc` self-test like this one.
- Check an API exists before using it: grep the SDK headers (`xcrun --show-sdk-path`), e.g.
  `…/CoreAudio.framework/Headers/AudioHardwareTapping.h`. Mark anything you couldn't exercise UNVERIFIED.

## Verify visually and for cost
- Notch: `screencapture -x -R x,y,w,h out.png` (display 1920×1243 pt; notch x 856–1064, 37 pt tall). Look at the PNG.
- Settings may be covered by other windows: capture it by window id with `screencapture -x -o -l <id>`; find the id
  with `CGWindowListCopyWindowInfo` filtered on owner "Belay" and width 760.
- CPU: `top -l 8 -s 1 -pid $(pgrep -x Belay) -stats cpu`. Budget < 1% closed/idle.
- Logs: `/usr/bin/log show --last 2m --predicate 'subsystem == "app.belay.mac"' --info` (zsh has a `log` builtin;
  use the full path). Log with `os.Logger`, `.notice` for lifecycle events, never user content.
- Never start playback, change volume or the clipboard, or click system permission prompts.

## Patterns that hold this app together
- **Tokens only.** Every colour, size, radius, font and animation comes from `Tok` (`Design/Tokens.swift`), resolved
  from the user's `Theme` (ADR 0015). Views that read tokens sit under `.id(settings.themeRevision)`.
- **Optical alignment.** Icon buttons are 28 pt hit areas around a 15 pt glyph; at a row's edge pull them out by
  `Tok.buttonInset` so the glyph lines up with text. Rows: [20 pt gutter] 12 [title / status] … [value].
- **Settings components** (`Settings/SettingsWindow.swift`): `SliderRow` (slider + right-aligned value with units,
  snapping in the binding, not `step:`), `SegmentedRow`, `ResetHeader` (per-section reset that shows only when
  changed), `NotchPreview`, menu pickers, switch toggles. Theme writes go through `bind(_:)` / `colour(_:)`, which
  skip no-op writes (echoing controls otherwise loop, ADR 0015). New defaults live once in `AppSettings`.
- **Progressive disclosure.** New features default off or quiet; advanced options go behind "Show advanced settings".
- **Concurrency.** UI types are `@MainActor`. Callbacks from AppKit/Combine/Core Audio hop back with
  `DispatchQueue.main.async { MainActor.assumeIsolated { … } }`. Real-time work (IOProcs) lives in a
  `final class …: @unchecked Sendable` confined to its own serial queue; publish to SwiftUI at ≤ 30 Hz.
- **Availability.** The app targets macOS 14.0. Gate newer APIs with `@available` / `#available`, and store such
  objects as `AnyObject?` if a stored property's type would need the newer OS.
- **Glass and materials** (the CLT SDK is macOS 26.2, so Liquid Glass compiles, but the app targets 14):
  - **The notch stays pure black.** Glass belongs to floating things off the notch: Settings sidebars, popovers, cards.
  - Gate macOS 26 APIs with `#available(macOS 26, *)`: `.glassEffect(.regular, in: shape)`, `GlassEffectContainer`, `.buttonStyle(.glass)`, `NSGlassEffectView`.
  - On 14–15, fall back to `.background(.regularMaterial)` or `NSVisualEffectView`.
  - **One material per surface.** Never stack glass on glass. Never add a border and a shadow on top of glass.
  - Honour Reduce Transparency: `@Environment(\.accessibilityReduceTransparency)` switches glass to a solid `Tok` surface.
  - Text on glass must still clear 4.5:1. Check it on a light and a dark wallpaper.
- **Lifecycles cost battery.** Anything that polls, taps or animates runs only while visible and useful, and stops
  otherwise (see `NotchController.updateBeat`, `status.setActive`, `music.setProgressActive`).
- **Brand.** `BelayMark` / `BelayMarkView` draw the logo from `brand/README.md` geometry. No brand text on the notch.

## Before you commit
`swift build` (0 warnings) → run and screenshot the changed state(s) → CPU check → `beat-selftest.sh` if audio
changed → `.claude/skills/belay/scripts/verify-repo.sh` → CHANGELOG `[Unreleased]` → one commit per task.
