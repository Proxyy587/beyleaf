# Belay UI inventory

The source of truth for **what is on screen and why**. Every element Belay shows is listed here with the user job it
does. If an element isn't here, it doesn't ship. If it can't pass the purpose test (§6), it's cut. How things look is
in `docs/design.md`; this doc covers what exists and why.

**Belay's job:** supervise your coding agents from the notch. Rope-drop approvals (A2) and catches (A3) are the
product. Music and screenshots are secondary conveniences that earn their place only because the notch is a good home
for them. Statuses: **built**, **planned** (feature ID from `docs/features-final.md`), **cut** (see §5).

Last audit: 2026-11-25 (widget hub: pages, ADR 0021, `docs/widget-hub.md`). Rows marked **spec** are designed and being built on `feat/widget-hub`; each flips to built in its own commit.

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
| Screenshot copied: copy icon (left), green check that draws in (right) | Know the screenshot is on the clipboard without looking away | 2.6 s after each auto-copy | On with auto-copy | none | Reduced motion: the check is simply there | "Copied" | built |
| Low battery: icon + % | Plug in before a long agent run dies with the laptop | Crossing 20% and 10% on battery | On | none | 10% and under: danger colour; desktop Macs: never | "Battery 18%" | built |
| Internet lost / back | Know why an agent or download stalled | When connectivity changes | On ("Internet lost or back") | none | Online (live green), offline (warning) | "Online" / "Offline" | built |
| Stopwatch: glyph (left), elapsed minutes (right) | See that something you're timing is still running, without opening the notch | While the stopwatch runs and nothing higher-priority is live | On ("Stopwatch") | Hover opens | "<1m", "12m", "1h 4m"; 5 s tick | "Stopwatch, 12 minutes" | **built** (widget; closed-notch wing UNVERIFIED by screenshot) |
| Meeting soon: calendar or video glyph (left), "5m" … "now" (right) | Don't miss the start of your next meeting | 5 min before a timed event until 1 min after it starts (Calendar access granted) | On ("Upcoming events") | Hover opens the Day page's Join | All-day events never; no access: never | "Design review in 5 minutes" | **built** (wing checked in demo; real events UNVERIFIED) |
| Charging: bolt + % | (none: macOS chimes and shows it in the menu bar) | Never | — | — | — | — | **cut** |
| Rope drop (approval needed) | Answer an agent's approval without leaving your work | When an agent asks | On | Click, ↵ / ⎋ / ⇧↵, voice | Timeout hands back to the terminal (ADR 0005) | "Approval needed: <command>" | planned A2 |
| Catch (dangerous action stopped) | Be told, loudly, that something risky was stopped | On a danger-rule hit | On | Same as rope drop | Reduced motion: no shake | "Belay caught: <rule>" | planned A3 |

### 1.3 Open notch

| Element | Purpose (user job) | Appears | Default | Interactions | States | A11y label | Status |
|---|---|---|---|---|---|---|---|
| Band beside the camera: brand slot (left); Expand/Compact, Edit widgets, Settings (right) | Reach sizing, editing and Settings where you are; the slot becomes the agents' status light (A1) | Always when open | Compact | Click; tooltips | No room beside the camera: the band is the first line | "Belay", "Expand"/"Compact", "Edit widgets", "Open Settings" | built |
| Page dots (in the band, right of the brand slot) | Know there are other pages and jump to one | Open notch, 2+ visible pages | — | Click a dot; ⌘[ ⌘] ⌘1–4 while key; VoiceOver adjustable | Current: ink; others: ink3; one page: hidden | "Page 2 of 3, Notes" | spec (widget-hub §1.4) |
| Pages: Now · Notes · Day, two-finger swipe | One job per page, so the notch never becomes a wall of widgets; only the visible page works | Open notch | Now, Notes, Day; remembered page | Swipe (follows the fingers, commits past 60 pt), dots, keys | Empty page skipped; one page: no swipe; reduced motion: cross-fade | page name | spec (widget-hub §1) |
| Clock in the header | (none: the menu bar clock stays visible beside the open panel) | Never | — | — | — | — | **cut** |
| Clock widget: large time and date, up to 3 other time zones | See the time in other places (team, servers, family) at a glance; the menu bar shows only local time, small (**owner override**, §7) | Now page | On | Right-click menu | Tile without zones, wide with zones; other day: "Tomorrow" | "14:32, Wednesday 25 November. London 19:32" | **built** (clock; checked by screenshot 2026-11-26) |
| Now playing hero: artwork, title, status line | Control the music without switching apps | A track is known | Row on | — | Long title: tail-truncated, one line; paused: ink3 status | title text | built |
| Progress bar + times | See and set where you are in the track | Track has a duration | With the hero | Hover thickens; click or drag to seek | Unknown duration: hidden | "Playback position" | built |
| Previous / play-pause / next | Skip or pause from the notch | With the hero | With the hero | Click | Player quit: state clears, nothing relaunches (3a95508) | "Previous track", "Play"/"Pause", "Next track" | built |
| "Not playing" line | (cut: a placeholder; Now playing now takes no space without a player, and shows a Play tile when one is open) | Never | — | — | — | — | **cut** |
| Last screenshot row: thumbnail, "Screenshot copied", age · size | Re-copy or find the screenshot you just took | After the first auto-copy this session | Row on | Copy again, Show in Finder | Old copies: "N min ago" | "Copy again", "Show in Finder" | built |
| Timer widget: − [length] + ▶, then ring + countdown, pause, stop, Done | Time-box work while agents run | Turned on by the user | **Off** (side option) | Drag the length, click to start | Paused, done (2 min), long timers (h:mm:ss) | "Timer length", "Start timer", "Pause timer" | built |
| Timer recent-length chips | Restart the lengths you actually use in one click | Timer ready, after you've used a second length | Learned | Click a chip starts it | Up to 3, most recent first | "Start 10 minute timer" | spec (widget-hub §3.2) |
| Stopwatch widget: elapsed, lap, pause, reset, last 3 laps | Time something open-ended (a build, a call) and mark laps without switching apps | Now page, turned on | **Off** (side option) | Click | Ready, running (1 s), paused, laps with hundredths; long: h:mm:ss | "Stopwatch, 12 minutes 4 seconds, running" | **built** (widget; closed-notch wing UNVERIFIED by screenshot) |
| System widget: CPU (and per core), memory and pressure, disk free, network up/down, battery, chip/cores/RAM line | See what the Mac is doing without opening Activity Monitor (a build chewing the CPU, tight memory, a full disk) | Now page, turned on | **Off** (side option) | Display only | First sample "–"; no battery on a desktop Mac (no BAT row); warning tone past 90% CPU, under memory pressure, ≤ 20% unplugged, ≥ 95% disk; samples only while visible (2 s) | "CPU 23%. Memory … Disk … Network … Battery …" | **built** (layout and sampler UNVERIFIED in the running app) |
| Keep awake widget: length chip (30m 1h 2h 4h ∞), start/stop, "Until 15:40" | Keep the Mac and its display awake through a long run or build, with an automatic stop (`caffeinate -d` without the terminal) | Now page, turned on | **Off** (side option) | Click the chip to cycle, ▶ to start, ■ to stop | Off; on until a time; on with no limit; the system drops it if Belay quits | "Keep awake, on. until 15:40." | **built** (assertion verified with `pmset -g assertions` outside the app; card layout UNVERIFIED) |
| Notes: one field that captures and searches, newest notes below, Copy / Delete on hover, Undo | Capture a thought instantly and find it again without opening an app | Notes page | On | Type filters; ↵ saves; Esc clears / closes; ⌃⌥N opens focused | No notes: just the field; no match: nothing below; write error: "NOT SAVED" in warning; long: one line + tooltip | "Capture a note"; per note Copy, Delete | **built** (render and save path checked; typing, hotkey press, Copy/Delete/Undo UNVERIFIED) |
| Weather: condition, temperature, H/L, rain hint, "Open-Meteo" link | Know whether you need a coat or umbrella before leaving the desk (**owner override**, §7) | Day page | On | Choose city (ready); link opens open-meteo.com | No city: ready "Choose city"; offline with cache: "· OFFLINE"; never fetched: "Couldn't reach Open-Meteo" + Retry; stale > 3 h and offline: gone | "Weather in London: 6 degrees…" | **built** (live fetch checked 2026-11-26) |
| Calendar: next events, countdown, Join | Be on time for the next thing and join it in one click | Day page | On | Show events (asks once), Join, Open Settings | Not asked: ready; write-only / denied: ready with Open Settings; nothing in 24 h: gone | per event "…, in 12 minutes. Join call" | **built** (layout checked with --calendar-demo; permission flow UNVERIFIED) |
| Edit widgets: cards to drag into slots, − to hide, + chips for hidden widgets | Put each widget exactly where you want it, without leaving holes (ADR 0019) | Edit widgets in the band, or right-click a card | — | Drag, click; right-click Move up/down/Hide | No enabled widgets: hint line | per card; "Move up/down" actions | built (drag UNVERIFIED by hand) |
| "No widgets" line + Edit widgets | Explain an empty panel and fix it in one click | Every widget off | — | Edit widgets pill | — | "No widgets" | built |
| Wi-Fi row | (none: duplicates the menu bar Wi-Fi item) | Never | — | — | — | — | **cut** |
| Battery row | (none: duplicates the menu bar battery item) | Never | — | — | — | — | **cut** |
| Volume row | (none: the volume keys, menu bar and Control Center already do it; Belay has no audio job) | Never | — | — | — | — | **cut** |
| Agent session list, rope cards, quests | Supervise agents: approve, steer, see progress | While sessions exist | On | Click, keys, voice | Offline core, no agents installed | per card | planned A1–A5, F* |
| Agents page: a card per session, composer for replies | See every session and answer the ones that need you; reply in your own words (ADR 0020) | belayd running with ≥ 1 session | On | Click, keys, voice | No session: page absent (never a placeholder); Stop-hook delivery UNVERIFIED | per card | planned A1–A2 (widget-hub §6) |
| Approval card pinned above any page | Never miss an approval because the notch was left on another page | A request is held | On | ↵ / ⎋ / ⇧↵ | Timeout hands back to the terminal | "Approval needed: <command>" | planned A2 (widget-hub §6.1) |

### 1.4 Menu bar item

| Element | Purpose (user job) | Appears | Default | Interactions | States | A11y label | Status |
|---|---|---|---|---|---|---|---|
| Belay mark (template image) | Find, configure and quit a dock-less app | Always | On | Click opens the menu | Light and dark menu bars (template tint) | "Belay" | built (light UNVERIFIED) |
| Open notch | Open the panel without hovering (trackpad-less, external display) | In the menu | — | Click; stays open until the pointer visits and leaves | — | item title | built |
| Settings… (⌘,) | Configure | In the menu | — | Click / ⌘, | — | item title | built |
| Quit Belay (⌘Q) | Quit | In the menu | — | Click / ⌘Q | — | item title | built |

### 1.5 Settings window

Five tabs in a pill bar (⌘1–⌘5). Nothing is hidden behind an "advanced" switch: Appearance keeps the depth one click
away instead.

| Tab · section · element | Purpose (user job) | Default | Interactions | States | Status |
|---|---|---|---|---|---|
| Pill tab bar: General · Widgets · Appearance · Agents · About | Find any setting in one click, without a long sidebar | General | Click, ⌘1–⌘5; the selected pill slides | — | built |
| General · Notch · Open with (Hover/Click), Open after hovering, Close after leaving, Haptic tick on open | Open the notch the way you like; stop accidental opens; feel it open (hover only) | Hover, Instant, Instant, On | Segmented, slider + value, switch | Click mode: only clicks on the notch itself are caught; the delay slider hides | built (click mode UNVERIFIED by hand) |
| General · Startup · Open Belay at login | Have the notch there after a restart | Off | Switch; "Open Login Items…" when macOS asks for approval | Approval needed, error line | built (UNVERIFIED: not toggled on the owner's Mac) |
| General · Live activities · While music plays, Music bars follow the beat, Low battery, Internet lost or back, Timer | Choose which moments may take over the closed notch | Keep showing, on, on, on, on | Menu, switches | Reset | built |
| General · Screenshots · Copy new screenshots to the clipboard | Have every screenshot on the clipboard, wherever macOS saves it | On | Switch | — | built |
| General · Settings · Keep the notch open while Settings is open | See changes live | On | Switch | — | built |
| Widgets · list | (replaced by Pages and per-page sections, ADR 0021) | — | — | — | replaced |
| Widgets · Pages: drag order, switch per page | Choose which pages exist and their order (ADR 0021) | Now, Notes, Day on | Drag, switch | Reset | spec |
| Widgets · one section per page: drag, switch, Page menu | Choose what each page shows and move widgets between pages | widget-hub §1.1 | Drag, switch, menu | — | spec |
| Widgets · Clock · Other time zones | Add the places you care about | None | Search a city, remove, reorder (max 3) | — | **built** (clock; checked by screenshot 2026-11-26) |
| Widgets · Weather · City, Units, attribution | Choose the city (never Location) and units; credit the data source (CC BY 4.0) | No city, Automatic | Search field + results, menu | Searching, no results, offline | **built** (live fetch and ready state checked 2026-11-26; Settings search, Retry and offline UNVERIFIED) |
| Widgets · Notes · Capture shortcut ⌃⌥N, Delete all notes… | Capture from anywhere; clear notes | On | Switch, confirm dialog | "⌃⌥N is taken by another app" | **built** (render and save path checked; typing, hotkey press, Copy/Delete/Undo UNVERIFIED) |
| Widgets · Calendar · Access | See and fix the calendar permission | — | Show events / Open Privacy Settings | Not asked, full, write-only, denied | spec (UNVERIFIED live) |
| General · Live activities · Stopwatch, Upcoming events | Choose whether these may take the closed notch | On, on | Switches | — | **built** |
| Appearance · live preview | See the change before you close Settings | — | Replay (Motion) | Stays pinned while the form scrolls | built |
| Appearance · Theme swatches, Save current as, Import/Export | Pick a look in one click; keep or share your own (ADR 0015) | Midnight | Click a swatch; right-click deletes your own | Swatches drawn in each theme's colours, face and surface | built |
| Appearance · Layout / Type / Colour / Surface / Motion | Fine-tune width, density, fonts, colours, surface, roundness, motion | Theme's values | Segmented switcher, per-section reset | Fonts shown in their own face | built |
| Agents · Command-line agents | Know Belay found your `claude` / `codex` (never credentials, ADR 0004) | — | Check again | Checking, version, Installed, Not found | built |
| About | Version, licence and credits | — | — | — | built |
| Show advanced settings | (cut: the tabs keep Settings short without hiding things) | — | — | — | **cut** |
| Sounds | Hear rope drops and catches when you're away from the screen | Off | Switch, per-sound | Muted while the asking terminal is focused | planned E2 |
| Voice (push-to-talk key, voice) | Answer agents by voice | — | Shortcut recorder, picker | Mic permission denied | planned C1, C2 |

### 1.6 First run and permissions

| Moment | Purpose (user job) | When | Handling | Status |
|---|---|---|---|---|
| Automation (Music, Spotify) | Read the track and control playback | First time Belay talks to a running player | Never launches a player; denied: track info from notifications only, controls do nothing | built |
| Audio capture (`NSAudioCaptureUsageDescription`) | Let the bars follow the real music | First time the music wing shows while playing | Denied, or no buffers: still glyph, retried on the next track | built (prompt text UNVERIFIED on device) |
| Files and Folders (screenshot folder) | Read the new screenshot to copy it | First copy from a protected folder | UNVERIFIED | built |
| Calendars (`NSCalendarsFullAccessUsageDescription`) | Show your next events and join calls | Only when you click Show events | Write-only or denied: the card says so and offers Open Settings; asked once | spec (UNVERIFIED live) |
| Network: Open-Meteo (no permission) | Weather for a city you typed | Only while Day is visible and the forecast is > 30 min old | Never Location; offline: cached + "OFFLINE" | spec |
| Global shortcut ⌃⌥N (Carbon hotkey, no permission) | Capture a note from anywhere | Registered at launch while on | Taken by another app: Settings says so | spec |
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
5. **Never:** anything the menu bar already shows without a reason of its own (a bare clock, Wi-Fi, battery level, volume), brand text, taglines, roadmap
   teasers, or idle animation.

## 3. Interaction rules

- **Open:** hover the notch for the open delay (default instant). Or use "Open notch" in the menu: it stays open until the
  pointer visits and leaves.
- **Close:** the pointer leaves the open panel, after the close delay. The gear also closes the notch as Settings opens.
- **Focus:** the notch never activates Belay (`nonactivatingPanel`, first click works). It becomes the key window only
  for a text field you clicked or the capture shortcut summoned, and gives the keyboard back when it closes (ADR 0021,
  widget-hub §1.5). Only Settings, which the user asked for, activates Belay.
- **Shortcuts:** ⌘, (Settings) and ⌘Q (Quit) in the menu; ⌃⌥N captures a note (global); ⌘[ ⌘] ⌘1–4 and Esc while the notch
  is key. Planned: ↵ / ⎋ / ⇧↵ on rope cards (A2) and a push-to-talk key (C1).
- **Pointer:** icon buttons have 28 pt hit areas, hover and pressed fills, tooltips and labels.
- **Never:** change volume, launch a player, start playback, or write the clipboard on Belay's own initiative (the one
  exception: auto-copying a screenshot the user just took). Copy buttons the user clicks are fine.

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
| Clock in the open header | The menu bar clock stays visible beside the open panel | Gear alone; agent status takes the left side (A1). A clock **widget** came back by owner override (§7) |
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

## 7. Owner overrides

Elements the purpose test alone wouldn't admit, kept because the owner asked for them. Each still gets a job the system
doesn't do, every designed state, and stays off the closed notch.

| Element | Override | The job we gave it | Date |
|---|---|---|---|
| Clock widget | Cut in §5 as a menu-bar duplicate; owner asked for a clock | Large glanceable time and date, plus up to 3 other time zones (the menu bar shows neither) | 2026-11-25 |
| Weather widget | A readout (test item 3); owner asked for weather | The rain hint ("Rain from 15:00"), on a page you choose to visit; never on the closed notch | 2026-11-25 |
