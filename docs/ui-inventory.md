# Belay UI inventory

The source of truth for **what is on screen and why**. Every element Belay shows is listed here with the user job it
does. If an element isn't here, it doesn't ship. If it can't pass the purpose test (§6), it's cut. How things look is
in `docs/design.md`; this doc covers what exists and why.

**Belay's job:** supervise your coding agents from the notch. Rope-drop approvals (A2) and catches (A3) are the
product. Music and screenshots are secondary conveniences that earn their place only because the notch is a good home
for them. Statuses: **built**, **planned** (feature ID from `docs/features-final.md`), **cut** (see §5).

Last audit: 2026-11-24.

## 1. Surfaces and elements

### 1.1 Closed notch (at rest)

| Element | Purpose (user job) | Appears | Default | Interactions | States | A11y label | Status |
|---|---|---|---|---|---|---|---|
| Black shape, exact hardware-notch fit | Stay invisible until something needs you | Always | On | Hover opens the panel after the open delay | No notch: a 190×26 pill at the top centre | none (decorative) | built |
| Agent climbers / rope state | See at a glance whether agents are working, waiting for you or done | While agent sessions run | On | Hover opens; click a rope (A7) | Many sessions, all idle, belayd offline | "Claude Code: needs approval" etc. | planned A1 |
| Mark / battery / time wings ("With info beside") | (none: the menu bar shows all three next to the notch) | Never | — | — | — | — | **cut** |

### 1.2 Live activities (wings that grow out of the closed notch)

| Element | Purpose (user job) | Appears | Default | Interactions | States | A11y label | Status |
|---|---|---|---|---|---|---|---|
| Music: artwork (left) | Know what's playing without switching apps | While music plays | On ("Keep showing"; "Show briefly", "Don't show") | Hover opens the hero | No artwork: note glyph on a raised plate | combined with the bars | built |
| Music: beat bars (right) | Confirm the music is really playing, and feel the beat | While music plays and the wing shows | On ("Music bars follow the beat") | none | Paused: pause glyph. Capture denied, no buffers or reduced motion: still waveform glyph | "Playing" | built (live bars UNVERIFIED, ADR 0017) |
| Screenshot copied: thumbnail + check | Trust that the screenshot is on the clipboard without looking | 2 s after each auto-copy | On with auto-copy | none | Thumbnail unreadable: camera glyph | "Screenshot copied" | built |
| Low battery: icon + % | Plug in before a long agent run dies with the laptop | Crossing 20% and 10% on battery | On | none | 10% and under: danger colour; desktop Macs: never | "Battery 18%" | built |
| Internet lost / back | Know why an agent or download stalled | When connectivity changes | On ("Internet lost or back") | none | Online (live green), offline (warning) | "Online" / "Offline" | built |
| Charging: bolt + % | (none: macOS chimes and shows it in the menu bar) | Never | — | — | — | — | **cut** |
| Rope drop (approval needed) | Answer an agent's approval without leaving your work | When an agent asks | On | Click, ↵ / ⎋ / ⇧↵, voice | Timeout hands back to the terminal (ADR 0005) | "Approval needed: <command>" | planned A2 |
| Catch (dangerous action stopped) | Be told, loudly, that something risky was stopped | On a danger-rule hit | On | Same as rope drop | Reduced motion: no shake | "Belay caught: <rule>" | planned A3 |

### 1.3 Open notch

| Element | Purpose (user job) | Appears | Default | Interactions | States | A11y label | Status |
|---|---|---|---|---|---|---|---|
| Settings gear (right of the camera) | Get to Settings from where you are | Always when open | On | Click; tooltip | — | "Open Settings" | built |
| Clock in the header | (none: the menu bar clock stays visible beside the open panel) | Never | — | — | — | — | **cut** |
| Now playing hero: artwork, title, status line | Control the music without switching apps | A track is known | Row on | — | Long title: tail-truncated, one line; paused: ink3 status | title text | built |
| Progress bar + times | See and set where you are in the track | Track has a duration | With the hero | Hover thickens; click or drag to seek | Unknown duration: hidden | "Playback position" | built |
| Previous / play-pause / next | Skip or pause from the notch | With the hero | With the hero | Click | Player quit: state clears, nothing relaunches (3a95508) | "Previous track", "Play"/"Pause", "Next track" | built |
| "Not playing" line (+ Play if a player is paused) | Say plainly there's nothing to control | No track known | With the row | Play button | One line, no "coming soon" | "Not playing" / "Spotify is paused" | built |
| Last screenshot row: thumbnail, "Screenshot copied", age · size | Re-copy or find the screenshot you just took | After the first auto-copy this session | Row on | Copy again, Show in Finder | Old copies: "N min ago" | "Copy again", "Show in Finder" | built |
| "Nothing shown" line | Explain an empty panel and where to fix it | Every row turned off | — | — | — | text | built |
| Wi-Fi row | (none: duplicates the menu bar Wi-Fi item) | Never | — | — | — | — | **cut** |
| Battery row | (none: duplicates the menu bar battery item) | Never | — | — | — | — | **cut** |
| Volume row | (none: the volume keys, menu bar and Control Center already do it; Belay has no audio job) | Never | — | — | — | — | **cut** |
| Agent session list, rope cards, quests | Supervise agents: approve, steer, see progress | While sessions exist | On | Click, keys, voice | Offline core, no agents installed | per card | planned A1–A5, F* |

### 1.4 Menu bar item

| Element | Purpose (user job) | Appears | Default | Interactions | States | A11y label | Status |
|---|---|---|---|---|---|---|---|
| Belay mark (template image) | Find, configure and quit a dock-less app | Always | On | Click opens the menu | Light and dark menu bars (template tint) | "Belay" | built (light UNVERIFIED) |
| Open notch | Open the panel without hovering (trackpad-less, external display) | In the menu | — | Click; stays open until the pointer visits and leaves | — | item title | built |
| Settings… (⌘,) | Configure | In the menu | — | Click / ⌘, | — | item title | built |
| Quit Belay (⌘Q) | Quit | In the menu | — | Click / ⌘Q | — | item title | built |

### 1.5 Settings window

Essentials are always listed; the Appearance group shows with "Show advanced settings".

| Pane · section · element | Purpose (user job) | Default | Interactions | States | Status |
|---|---|---|---|---|---|
| General · Hover · Open after hovering / Close after leaving | Stop the notch opening when the pointer just passes the menu bar | Instant / Instant | Slider + value | Reset when changed | built |
| General · Feel · Haptics | Feel the notch open under your finger on a Force Touch trackpad (hover only, never on click) | On | Switch | — | built |
| General · Settings · Keep the notch open while Settings is open | See changes live | On | Switch | — | built |
| General · Settings · Show advanced settings | Keep Settings short for most people | Off | Switch | Remembered | built |
| Layout · Open notch · Width, Density | Fit the panel to your screen and taste | 440 pt, Regular | Slider, segmented | Reset | built |
| Layout · Rows · Now playing, Last screenshot | Choose and order what the panel shows | Both on | Switch, move up/down | Old themes with retired rows load without them | built |
| Layout · Live activities · While music plays, Music bars follow the beat, Low battery, Internet lost or back | Choose which moments may take over the closed notch | Keep showing, on, on, on | Menu, switches | Reset | built |
| Layout · Closed notch · Size, wings | (cut with the wings) | — | — | — | **cut** |
| Screenshots · Auto-copy | Have every screenshot on the clipboard, wherever macOS saves it | On | Switch | — | built |
| AI accounts · Command-line agents | Know Belay found your `claude` / `codex` (never credentials, ADR 0004) | — | Check again | Checking, version, Installed, Not found | built |
| About | Version, licence and credits | — | — | — | built |
| Theme / Typography / Colours / Surface and shape / Motion (advanced) | Make it yours (ADR 0015) | Midnight | Live preview, per-section reset | Fonts shown in their own face | built |
| Sounds | Hear rope drops and catches when you're away from the screen | Off | Switch, per-sound | Muted while the asking terminal is focused | planned E2 |
| Voice (push-to-talk key, voice) | Answer agents by voice | — | Shortcut recorder, picker | Mic permission denied | planned C1, C2 |

### 1.6 First run and permissions

| Moment | Purpose (user job) | When | Handling | Status |
|---|---|---|---|---|
| Automation (Music, Spotify) | Read the track and control playback | First time Belay talks to a running player | Never launches a player; denied: track info from notifications only, controls do nothing | built |
| Audio capture (`NSAudioCaptureUsageDescription`) | Let the bars follow the real music | First time the music wing shows while playing | Denied, or no buffers: still glyph, retried on the next track | built (prompt text UNVERIFIED on device) |
| Files and Folders (screenshot folder) | Read the new screenshot to copy it | First copy from a protected folder | UNVERIFIED | built |
| Onboarding: hook install with diff preview, "What Belay reads" | Connect Belay to your agents safely | First launch | — | planned H1, H3, H4 |

### 1.7 Empty, error and denied states (summary)

- **Nothing playing:** one line, "Not playing", with Play only when a player is paused.
- **No rows:** "Nothing shown. Choose rows in Settings."
- **No notch:** a pill at the top centre; the header sits below the notch line.
- **No battery (desktop):** no battery alerts.
- **Audio capture denied:** a still glyph; no retry loop.
- **Player quit:** state clears; nothing relaunches it.
- **Reduced motion:** springs become fades, blur is off, and the bars are a still glyph.

## 2. Information hierarchy

1. **First (and, soon, always):** whether any agent needs you: the rope drop or catch in the closed notch (A1–A3).
2. **Second:** a live moment that's really happening: music playing, a screenshot copied, low battery, internet lost.
3. **Third, on hover:** controls for what's live (the now-playing hero), then the last screenshot.
4. **In Settings only:** layout, appearance and behaviour. Never on the notch.
5. **Never:** anything the menu bar already shows (clock, Wi-Fi, battery level, volume), brand text, taglines, roadmap
   teasers, or idle animation.

## 3. Interaction rules

- **Open:** hover the notch for the open delay (default instant). Or use "Open notch" in the menu: it stays open until the
  pointer visits and leaves.
- **Close:** the pointer leaves the open panel, after the close delay. The gear also closes the notch as Settings opens.
- **Focus:** the notch never takes focus (`nonactivatingPanel`, first click works). Only Settings, which the user asked
  for, activates Belay.
- **Shortcuts:** ⌘, (Settings) and ⌘Q (Quit) in the menu. Planned: ↵ / ⎋ / ⇧↵ on rope cards (A2) and a push-to-talk key (C1).
- **Pointer:** icon buttons have 28 pt hit areas, hover and pressed fills, tooltips and labels.
- **Never:** change volume, launch a player, start playback, or write the clipboard except to auto-copy a screenshot
  the user just took.

## 4. Motion and feel

| Moment | Motion | Feel | Reduced motion |
|---|---|---|---|
| Notch opens | `Tok.open`, spring ~300 ms; content blur-reveals +40 ms, staggered 25 ms | Haptic `.alignment` | 150 ms fade, no blur |
| Notch closes | `Tok.close`, critically damped spring | — | 150 ms fade |
| Live activity starts / new track | `Tok.jelly`, wings grow with a little bounce | — | Fade |
| Text changes (track, wing) | Blur swap, `Tok.reveal` 200 ms | — | Opacity only |
| Button press | Fill + scale 0.94, release with a slight overshoot (`Tok.pressUp`) | No haptic: the trackpad already clicks | No scale |
| Music bars | Real audio levels at ≤ 30 Hz; 12% lift on a beat | — | Still glyph, no capture |
| Rope drop / catch | Planned (A2, A3): one move, the point pulses once | No haptic unless the pointer is on the notch | Fade |
| At rest | Nothing moves | — | — |

## 5. Cut, and why

| Cut | Why | Instead |
|---|---|---|
| Volume row and slider | Belay has no audio job. Volume keys, the menu bar and Control Center already do it. The row also ran AppleScript on every open, and dragging it changed system volume | Nothing. Agent-aware ducking (B2) will set volume automatically, if it ships |
| Wi-Fi row | Duplicates the menu bar Wi-Fi item. Showing the network name also needs Location permission | "Internet lost or back" alert: the moment it matters (an agent stalls) |
| Battery row | Duplicates the menu bar battery item | Low-battery alert at 20% and 10% |
| Charging alert | macOS already chimes and shows it; nothing to decide | Nothing |
| Clock in the open header | The menu bar clock stays visible beside the open panel | Gear alone; agent status takes the left side (A1) |
| "With info beside" closed style and its wing options (Mark, Battery, Time) | Each duplicates the menu bar right next to the notch, and the mark at rest is branding on the notch | The closed notch fits the hardware exactly; wings appear only for live activities, and soon for agents (A1) |
| "Belay" title and climber in the header | No brand text on the notch | Recognised by feel |
| Looping green equalizer | Decoration that didn't match the music | Real-audio bars (ADR 0017) |

## 6. The purpose test

Before adding any element to the notch, a live activity or Settings, answer in one line:

> **What user job does this do that the notch is uniquely good for?**

It passes only if all of these are true:
1. It's a real job, not decoration or a feature list.
2. The menu bar, Control Center or the app itself doesn't already do it next to where the user is looking.
3. It's live or actionable now (a moment, a control, or a decision), not a permanent readout.
4. It doesn't pull attention from agent supervision, Belay's core job.
5. It has a designed empty, long, denied and reduced-motion state.

Elements that fail are cut and listed in §5. Settings-only options must still pass items 1, 2 and 4.
