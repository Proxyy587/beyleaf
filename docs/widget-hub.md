# Widget hub: pages in the open notch

**Status:** spec accepted 2026-11-25 (owner request, refined). Built on `feat/widget-hub`, one commit per widget.
**Decision record:** ADR 0021 (pages and the hub data model; extends ADR 0019). **Look and feel:** `docs/design.md`,
`dusk-feel`. **What exists and why:** `docs/ui-inventory.md` (every element below has a row there).
**Budgets:** `docs/performance.md` (every number below is measured there).

> **In one line:** the open notch is a few **pages**, one job each, that you swipe between. Each page is the same
> packed widget grid as before (ADR 0019). Only the page you're looking at does any work, and the closed notch shows
> only what's live.

> **Update 2026-11-26 (ADR 0023):** the packing rule below (tiles pair, a lone tile is promoted, some widgets always
> wide) is superseded. Each widget has a user-chosen **span** (small 1, wide 2, full 3 columns) on a grid of 2 columns
> (3 when expanded); layout flows in the user's order and is never re-packed. Small draws the tile form, wide and full the
> wide form. **Expand** adds a third column of the same width, so more widgets fit and none grow. Edit mode: drag to
> reorder, tap to cycle size; also right-click → Size and Settings → Widgets → Size. Cells have a minimum height.
> Where this page says "tile", "wide", "promoted" or "expanded is 180 pt wider", read it through ADR 0023.
> A new widget kind declares `defaultSpan` (and optionally `minSpan`) in `WidgetLayout.swift` and designs a `.tile` and
> a `.wide` form.

## 1.7 Staying open while in use
The open notch closes only after a genuine leave: the pointer outside the panel plus 20 pt at the sides and 28 pt below
(the tallest recent height counts for 1.2 s), for at least 0.3 s (longer if Settings says so), and not within 1.5 s of
a scroll or key press, never while a mouse button is down (drag) or while the Notes field holds unsaved typing.
Pure rules in `HoverLogic.swift`, self-tested.

## 0. The owner's ask, and what we changed
- **Asked:** clock, smart timer, stopwatch, instant notes, chat with agents, music, weather, a calendar hub. "Don't make it
  feel like too much stuff, or let users put whatever they want. Slides you switch between." UI and performance are
  non-negotiable.
- **Refined from the proposal shown to the owner:**
  1. **Three pages ship, not four.** Now, Notes, Day. The Agents page is designed here (§6) and ships with A1, because
     the design rules forbid a page with nothing real on it (`docs/design.md` §1.4).
  2. **Dots live in the band, beside the brand slot,** not on a row of their own: a dot row would be 12–16 pt of dead
     strip on every page (ADR 0019's "no dead space").
  3. **Timer and stopwatch stay two widgets** (two tiles pack into one row), so you can run both, and each can be hidden.
  4. **Clock is wide only when it has other time zones to show;** alone it's a tile that pairs with the timer.
  5. **Notes is one field that both captures and searches** (type → matching notes show below; Return saves). No
     separate search box, no mode.
  6. **A page with nothing to show is skipped,** like a widget with nothing to show. Swiping never lands on an empty page.
  7. **Calendar earns its place with "join":** the next meeting's video link is one click from the notch, and the closed
     notch says "meeting in 5 min". That's a job the menu bar doesn't do.

## 1. Pages

### 1.1 Model
- A **page** is a named, ordered list of widgets. The open panel shows one page at a time.
- **Built-in pages** (v1): **Now**, **Notes**, **Day**. **Agents** joins at A1 (§6). Each page has a name and an
  SF Symbol, used in Settings, in VoiceOver and in the editor.
- **Every widget lives on exactly one page.** Users move widgets between pages, hide them, and hide or reorder whole
  pages (§4). Custom-named pages are not in v1 (§9).
- **Defaults:**

| Page | Widgets (in order) | On by default |
|---|---|---|
| Now | Clock, Now playing, Timer, Stopwatch, Last screenshot, System, Keep awake, Moon, Roll | Clock, Now playing, Last screenshot (Timer, Stopwatch, System, Keep awake, Moon and Roll are side options, as the Timer was in ADR 0019) |
| Notes | Notes | Notes |
| Day | Calendar, Weather | Both |

### 1.2 Which pages are shown
```
visible pages = enabled pages, in the user's order, that have at least one widget present (live or ready) right now
```
- A page whose widgets are all hidden or gone is **skipped** (not shown as empty, no dot).
- One visible page: no dots and no swiping, exactly like today's panel.
- No visible pages: the existing one-line empty state, "No widgets" + Edit widgets.

### 1.3 Navigation
| Input | Does | Notes |
|---|---|---|
| **Two-finger horizontal swipe** on the open panel | Fingers left → next page, right → previous | The page follows the fingers with resistance (≤ 40 pt), then commits past 60 pt of travel, or springs back. Momentum and vertical scrolls are ignored. Normalised for natural scrolling (`isDirectionInvertedFromDevice`). Rubber-bands at the first and last page; no wrap. |
| **Click a dot** | Go to that page | 28 pt tall hit area per dot. Tooltip: the page's name. |
| **⌘[ / ⌘]** | Previous / next page | Only while the panel is key (§1.5). |
| **⌘1 … ⌘4** | Go to page N | Same. |
| **Esc** | Notes field with text: clears it. Otherwise closes the notch | Same. |
| **Capture shortcut** (⌃⌥N, §3.4) | Opens the notch on Notes with the field focused | Global, no permission needed. |
| **VoiceOver** | The dots are one adjustable element: "Page 2 of 3, Notes"; swipe up/down to change | |

- **Remembered page:** the notch reopens on the page you last chose (`AppSettings.page`). If that page isn't visible
  now, it opens on the first visible page, and the remembered choice is kept for when it comes back.
- **Compact and expanded** (ADR 0019 §6b) are unchanged and apply to every page: expanded is 180 pt wider, and paired
  tiles draw their wide layouts.
- **Edit mode** works per page: the editor shows the current page; the dots still switch pages (§4).

### 1.4 The dots
- In the **band**, right of the brand slot: `[beepo] • • ○` … `[expand] [edit] [settings]`.
  - The band's left side has ~100 pt beside a 440 pt panel; the slot is 28 and three dots are ~36. No new row.
  - No-notch displays: the band is the first line, same contents.
- **Dot:** 6 pt circle. Current page: ink. Others: ink3. Hover: ink2. No pills, no labels, no animation at rest.
- **Hidden** when only one page is visible.

### 1.5 Typing in a non-activating panel (the focus approach)
The notch panel is a `nonactivatingPanel` that never steals focus (ADR 0014, ui-inventory §3). Notes needs typing, so:
- `NotchPanel.canBecomeKey` is **true only while the notch is open**, and `becomesKeyOnlyIfNeeded = true`: a click on a
  button never makes the panel key; a click in the **text field** does (the field needs keyboard input).
- A non-activating panel becomes the key window **without activating Belay**: the app you were in stays frontmost
  (its menu bar stays), and keystrokes go to the notch field.
- **Capture shortcut:** opens the notch pinned, switches to Notes, and makes the panel key with the field focused.
- **On close:** if the panel is key it resigns, and is ordered out and back in, so the window server hands key back to the
  frontmost app's window. Hover-opening never takes the keyboard.
- **Verification:** the panel becoming key and the field focusing is checked in logs and screenshots. Whether keystrokes
  return to the previous app after closing needs a person at the keyboard: **UNVERIFIED** until the owner checks it.

### 1.6 Motion (one per kind, `dusk-feel` §4)
| Change | Motion | Reduced motion |
|---|---|---|
| Page change (swipe commit, dot, key) | The new page slides in 24 pt from the side you're going to, out of a slight blur; the old one leaves 24 pt the other way. `Tok.open` (≤ 300 ms). The panel height springs to the new page's height with the same spring. | Cross-fade 150 ms |
| Swipe in progress | Content offset follows the fingers × 0.35, capped at 40 pt; released: springs (`Tok.open`) | No follow; commit only |
| Dot change | Fill colour, `Tok.hover` (120 ms) | Same |
| Everything else | As ADR 0019 / `notch-widgets.md` §7 | |

No page animates at rest. A page that isn't visible isn't in the view tree, so its widgets can't tick (§7).

## 2. Widget anatomy (unchanged, ADR 0019)
- Each widget, in its current state, is **live**, **ready** (nothing live, one useful action) or **gone** (no space), and
  **wide** or a **tile**. A lone tile is promoted to its wide layout. Every widget designs both forms.
- Cards: `Tok.raised`, radius `Tok.rCard`, 12 pt inset, 8 pt gaps. Type scale and three ink levels only.
- **One addition to the type scale:** `Tok.display`, SF Pro 28 medium with tabular digits, for the clock's time only. The
  owner asked for a large, glanceable time; 15 pt is a row value, not a glance. `docs/design.md` §4 is updated in the
  same commit.

## 3. Widgets

Each entry: job · states · forms · closed notch · settings · data and permissions · empty, denied and error · motion ·
accessibility · CPU budget.

### 3.1 Clock (Now)
- **Job:** a large, glanceable time and date while the notch is open, **plus the time in other places** (teammates,
  servers, family). The menu bar shows one small local time and no other zones: that gap is the clock's reason to exist.
  - It was cut in the purpose audit as a menu-bar duplicate (ui-inventory §5). **The owner asked for it explicitly
    (2026-11-25);** the override and the job are recorded in the inventory.
- **States:** always live while enabled (never gone, never ready).
- **Tile** (no other zones): time in `Tok.display` ("14:32"), the date as a status line under it ("WED 25 NOV").
- **Wide** (one or more zones, or promoted): local time and date on the left; up to **3 zones** on the right, one per line:
  `London  19:32  +5h` (city in ink2, time in mono digits ink, offset in ink3). A zone on a different day shows
  "Tomorrow"/"Yesterday" instead of the offset sign alone ("09:32 · Tomorrow").
- **Closed notch:** nothing (not live; the menu bar has the time).
- **Settings → Widgets → Clock:** other time zones (add by searching a city from the system's time zone list, remove,
  reorder; max 3), 24-hour follows the system.
- **Data:** the system clock and `TimeZone`. No network, no permission.
- **Empty/error:** none possible. Long city names truncate tail.
- **Motion:** minute changes swap digits with no transition (a minute roll isn't worth a frame budget).
- **A11y:** one element: "14:32, Wednesday 25 November. London 19:32."
- **CPU:** ticks **once a minute, on the minute** (`Ticking(seconds: 60, active: visible)`), only while its page is
  visible. Budget: open idle ≤ 0.3%.

### 3.2 Timer (Now), made smart
- **Job:** time-box work while agents run (unchanged).
- **Smart:** the picker starts at your last length (as today), and the **ready** state also offers your **last three
  other lengths** as chips, most recent first (e.g. `10m 45m 5m`). One click on a chip starts that timer. Learned from
  what you start; nothing is preset.
- **Tile (ready):** title row: [timer] Timer … [chips]; action row: − [25m] + ▶ (as today). No chips until you've
  used a second length.
- **Wide (ready):** one row: [timer] Timer, chips, then − [25m] + ▶.
- **Running / paused / done:** unchanged (ring, countdown, ends 14:32, pause, stop, Done for 2 min).
- **Closed notch:** unchanged (ring + minutes while running and music isn't playing; "Done" flash).
- **CPU:** 1 s tick only while visible and running (measured ~0.7% open). Closed wing 5 s tick.

### 3.3 Stopwatch (Now, new)
- **Job:** time something open-ended (a build, a call, a run) and mark laps, without switching apps.
- **States:** **ready** (start it), **running**, **paused** (both live). Reset returns it to ready.
- **Tile:** ready: [stopwatch] Stopwatch … ▶. Running: elapsed in mono 15 semibold ("12:04", "1:02:05" past an hour);
  status "RUNNING" (live) or "PAUSED"; actions: lap (flag) and pause, or reset and resume while paused.
- **Wide:** the same, plus the **last three laps** on the right, newest first: `Lap 3  0:41.37` (lap times show
  hundredths: they're fixed numbers, so precision costs nothing).
- **Why no running hundredths:** a 10–60 Hz digit would cost far more than the 1% open budget for motion nobody reads.
  The running display ticks once a second; laps and the paused value show hundredths.
- **Closed notch:** while running (and nothing higher-priority is live): stopwatch glyph on the left, elapsed minutes on
  the right ("12m", "<1m"), ticking every 5 s. Toggle: Settings → General → Live activities → Stopwatch.
- **Data:** in memory; survives closing the notch, not quitting Belay.
- **A11y:** "Stopwatch, 12 minutes 4 seconds, running"; buttons "Lap", "Pause stopwatch", "Resume", "Reset".
- **CPU:** as the timer: open ≤ 1% while running and visible; closed wing ≤ 0.3%.

### 3.4 Notes (Notes, new)
- **Job:** **capture a thought instantly** (a command to try, a name, a thing to tell the agent later) and find it again,
  without opening an app. The notch is always one hover or one shortcut away; no app does that.
- **One field captures and searches:**
  - Typing filters the notes below (case- and accent-insensitive, every word must match).
  - **Return saves** the field as a new note (trimmed; empty does nothing) and clears it. Opened by the shortcut, the
    notch closes after saving, so you're straight back where you were.
  - **Esc** clears the field; on an empty field it closes the notch.
- **Always ready** (the field), so the Notes page is never skipped while enabled.
- **Wide only** (it's a field and a list; it never pairs).
  - Field row: [square.and.pencil] field ("Capture a note") … count status ("12 NOTES", or "3 MATCH").
  - Below: up to **3 notes** (compact) or **5** (expanded), newest first, or the best matches while typing. Each is one
    line, tail-truncated (full text in the tooltip), with its age in mono on the right ("4 min", "2 d").
  - Hover a note: **Copy** and **Delete** replace the age. Copy is a user action, so it may write the clipboard (the
    "never write the clipboard" rule in ui-inventory §3 covers things Belay does on its own).
  - **Delete** is immediate, with **Undo** offered in the field row for 4 s.
- **Storage:** plain JSON at `~/Library/Application Support/Belay/notes.json`:
  `{"version":1,"notes":[{"id":"<uuid>","text":"…","created":"<ISO 8601>"}]}`. Written atomically on every change; read
  the first time the Notes page shows, not at launch. Nothing leaves the Mac. Max 5,000 notes kept (oldest dropped).
- **Capture shortcut:** **⌃⌥N** by default, toggle in Settings → Widgets → Notes.
  - Implemented with Carbon `RegisterEventHotKey`, which needs **no Accessibility or Input Monitoring permission**
    (verified 2026-11-25: registration returns `noErr` from an unprivileged process with no prompt).
  - macOS 15+ refuses hotkeys whose only modifiers are ⌥ or ⌥⇧, so the default includes ⌃.
  - If another app owns the combination, registration fails and Settings says so: "⌃⌥N is taken by another app."
- **Closed notch:** nothing. Notes are never live.
- **Empty:** no notes yet: just the field (it's the action). No matches: nothing under the field; Return still saves.
- **Error:** the file can't be written: field row status "NOT SAVED" in warning, and the text stays in the field.
- **Motion:** a saved note arrives at the top of the list with the standard arrive motion (`blurReplace` + `Tok.open`);
  a deleted one leaves the same way.
- **A11y:** field "Capture a note"; each note is one element with "Copy" and "Delete" actions.
- **CPU:** nothing ticks; ages refresh when the page is shown. Search runs on keystrokes over ≤ 5,000 short strings.
  Budget: open idle 0.0–0.3%.

### 3.5 Now playing (Now)
- Unchanged (ADR 0019): it moves onto the Now page. Its progress polling already runs only while the notch is open, and
  now only while the Now page is visible.

### 3.6 Last screenshot (Now)
- Unchanged. Lives on Now: it's a live moment, like music.

### 3.7 Weather (Day, new)
- **Job:** know whether to take a coat or an umbrella before you leave the desk: the temperature now, today's range, and
  **when rain starts** in the next hours. Glanceable in the notch you're already hovering, without opening an app.
  - It's mostly a readout, which the purpose test discourages (§6 item 3). **The owner asked for it explicitly;** it
    stays off the closed notch and earns its row with the rain hint.
- **States:**
  - **Live:** a forecast for the chosen city, no older than 3 h.
  - **Ready:** no city chosen yet: [cloud.sun] Weather … "Choose city" (opens Settings → Widgets → Weather).
  - **Gone:** never while enabled (it always has the action), except when the last forecast is older than 3 h **and** the
    Mac is offline: then it takes no space rather than showing stale numbers.
- **Tile:** condition symbol (bare SF Symbol, monochrome ink) + temperature in 15 semibold ("6°"); status
  "LONDON · H 8 L 3"; trailing: the source link "Open-Meteo" in ink3 (attribution, below).
- **Wide:** the same on the left; on the right the rain hint in body ink2: "Rain from 15:00" (first hour in the next 12
  with precipitation probability ≥ 50%), or "Dry until 02:00".
- **Settings → Widgets → Weather:** city search (type a name, pick from up to 5 results: "London, England, United
  Kingdom"), units (Automatic from the system locale, °C, °F).
- **Data source: Open-Meteo** (`api.open-meteo.com/v1/forecast`, geocoding `geocoding-api.open-meteo.com/v1/search`).
  - **Free, no API key, no account.** Terms (read 2026-11-25, open-meteo.com/en/terms): free use is for non-commercial
    purposes, defined as apps "that do not have subscriptions or advertising". Belay is free, MIT, with neither.
    Limits: 10,000 calls/day per IP, far above our ≤ 48/day.
  - **Licence: CC BY 4.0** (open-meteo.com/en/licence): "You must include a link next to any location Open-Meteo data are
    displayed." So the card carries a small "Open-Meteo" link to open-meteo.com, and Settings shows "Weather data by
    Open-Meteo.com (CC BY 4.0). Places from GeoNames (CC BY 4.0)."
  - The API's server code is AGPL; we only call the public HTTP API and copy no code (ADR 0003 unaffected).
  - **If Belay ever charges or shows ads,** this needs a paid Open-Meteo plan or another source.
- **Permissions: none.** Never Location: the city is typed, so there's no permission prompt and no location leaves the
  Mac except the chosen city's coordinates.
- **Network rule:** fetch **only while the Day page is visible and the forecast is older than 30 min**, one request,
  `URLSession` ephemeral, 10 s timeout. Settings search fetches only while you type (debounced 300 ms).
- **Error:** fetch fails with a cached forecast: keep it, status gains "· OFFLINE" (ink3). No forecast at all: the
  ready-style card says "Couldn't reach Open-Meteo" with Retry.
- **A11y:** "Weather in London: 6 degrees, partly cloudy, high 8, low 3. Rain from 15:00."
- **CPU:** no ticking; one decode per fetch. Open idle 0.0–0.3%; a fetch costs one short burst.

### 3.8 Calendar (Day, new)
- **Job:** **be on time for the next thing, and join it in one click.** The next events today, how long until the next
  one, and a Join button when the event has a video link. The closed notch says "in 5 min" before it starts. The menu
  bar shows none of this.
- **Data: EventKit,** all calendars the user has in Calendar.app, read-only. Today's remaining events (and, after the
  last one, tomorrow's first).
- **Permission:** `NSCalendarsFullAccessUsageDescription` (and the pre-14 key) in `Info.plist`:
  "Belay shows your next events in the notch, so you can see what's coming and join calls. Events stay on your Mac."
  - **Asked once, only when you click "Show events"** on the card or in Settings. Never at launch, never on hover.
  - The prompt is the system's. Agents never click it.
- **States:**
  | Authorization | What shows |
  |---|---|
  | Not determined | **Ready tile:** [calendar] Calendar … "Show events" (asks for access) |
  | Full access, events in the next 24 h | **Live, wide:** up to 3 events: colour dot (the calendar's own colour, like an app icon: content, not decoration), title, "14:00–14:30" mono, the next one's countdown "in 12 min" (live green when ≤ 5 min), Join (video glyph) when a link is found |
  | Full access, nothing in the next 24 h | **Gone** (a free day isn't news) |
  | Write-only ("limited" on macOS: can add, can't read) | **Ready tile:** "Calendar needs full access" … "Open Settings" (Privacy & Security → Calendars) |
  | Denied or restricted | **Ready tile:** "Calendar access is off" … "Open Settings" |
- **Join link:** the event's URL, else the first `https://` link in location or notes that points at a known meeting host
  (zoom.us, meet.google.com, teams.microsoft.com, webex.com, whereby.com, around.co). Opened with `NSWorkspace.open`.
- **Closed notch ("meeting soon"):** 5 min before an event with a start time, the wings show [calendar or video glyph]
  and "5m" … "now", until 1 min after it starts. Ranked above music (it's time-critical). Toggle: Settings → General →
  Live activities → Upcoming events. All-day events never trigger it.
- **Work:** events are fetched when the Day page shows, when `EKEventStoreChanged` fires, and at midnight. The
  meeting-soon moment is **one scheduled wake-up** for the next event's start − 5 min, not a poll.
- **A11y:** each event: "Design review, 14:00 to 14:30, in 12 minutes. Join call."
- **CPU:** countdown text ticks once a minute while visible. Open idle ≤ 0.3%; closed 0.0%.
- **UNVERIFIED:** the live permission flow (prompt text, grant, deny, write-only), real events and the Join button: the
  agent can't click the system prompt. Layout is checked with the DEBUG flag `--calendar-demo` (sample events, never
  written anywhere).

### 3.9 System (Now, new, off by default)
- **Job:** see what the Mac is doing (is the build chewing the CPU, is memory tight, is the disk nearly full, is the
  network busy, how long is the battery good for) without opening Activity Monitor. "PC specs and utilisation".
- **Forms:** **wide** always (it is a set of rows; it never pairs).
  - **Compact:** a title line, then CPU, MEM, NET and (laptops) BAT rows: `LABEL ▬▬▬▭▭ value`, a 4 pt bar in ink
    (warning past 90% CPU, under memory pressure, under 20% battery unplugged, over 95% disk), the value in mono.
  - **Expanded** (two columns): left CPU, one tiny bar per core (max 16), MEM; right DISK (free), NET `↓ 1.2 MB/s ↑ 40 KB/s`,
    BAT with a status line ("Charging · 1 h 20 min to full", "3 h 4 min left", "Plugged in", "Charged"). The title line
    carries "About this Mac" once: `Apple M4 · 10 cores · 16 GB` (chip from `machdep.cpu.brand_string`).
- **States:** always live while enabled. No battery (desktop Mac): no BAT row. First sample: CPU shows "–" until the
  second sample gives a delta. Never gone, never ready.
- **Closed notch:** nothing.
- **Data, public APIs only, no permission, no network:**
  | Figure | Source |
  |---|---|
  | CPU, per core | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)`: cumulative ticks, diffed between samples (32-bit, wrap-safe) |
  | Memory used | `host_statistics64(HOST_VM_INFO64)`: app memory (anonymous minus purgeable) + wired + compressed, as Activity Monitor adds it |
  | Memory pressure | `sysctl kern.memorystatus_vm_pressure_level` (1 normal, 2 warning, 4 critical) |
  | Disk | `URLResourceValues` `volumeAvailableCapacityForImportantUsage` and `volumeTotalCapacity` for `/` |
  | Network | `getifaddrs` byte counters of `en*` interfaces (Wi-Fi, Ethernet; tunnels skipped so traffic isn't doubled), diffed |
  | Battery | IOKit power sources (`IOPSCopyPowerSourcesInfo`), "Time to Empty" / "Time to Full Charge" |
- **Sampling:** `SystemStats.start()` when the card is on screen and `ticking`, `stop()` when the page hides or the notch
  closes. One sample every **2 s** (timer tolerance 0.5 s); disk and battery every 10 s. A hidden or closed notch does
  no work at all. The snapshot is published only when a value changes, and only this card observes it, so a sample
  re-renders one card, never the panel.
- **Pure logic** (`SystemStatsLogic.swift`, self-tested with fixtures): ticks to percentages, wrap-safe deltas,
  memory arithmetic, byte and rate text, battery and about lines.
- **A11y:** one element: "CPU 23%. Memory 8.0 GB of 16 GB, pressure high. Disk 200 GB free. Network down 1.2 MB/s, up 0 B/s.
  Battery 80 percent, Plugged in."
- **CPU budget:** open on the page ≤ 0.5% (target); closed or on another page 0.0%. **UNVERIFIED** in the app (see
  `docs/performance.md`). The sampler alone was run outside the app for 5 s: values were plausible against `top`.

### 3.10 Keep awake (Now, new, off by default)
- **Job:** stop the Mac and its display from idle-sleeping while a long agent run, build or download finishes, with one
  click and an automatic stop, so you never leave it on by accident. It is `caffeinate -d` without the terminal.
- **Forms:** tile or wide (the shared widget card). Ready: [cup] Keep awake, status `OFF`, a length chip (`1h`, click to
  cycle `30m 1h 2h 4h ∞`) and ▶. On: filled cup in live green, status `UNTIL 15:40` (or `NO LIMIT`), ■ to stop.
- **How:** one public IOKit power assertion, `IOPMAssertionCreateWithName("PreventUserIdleDisplaySleep")`, created on
  the click and released on stop, at the end of the length, or when Belay quits (the system drops a process's
  assertions with it). It shows in `pmset -g assertions` as "Belay: keep awake (user started it)". **No permission.**
  Never started automatically, never started by anything but a click; a Mac in a closed lid or on a low battery still
  sleeps by system policy.
- **Closed notch:** nothing. (Considered: a cup glyph in the wing; cut, since the menu bar already shows the assertion.)
- **Cost:** nothing ticks. The end time is a clock time, and one `DispatchWorkItem` fires once at the deadline.
- **Data:** in memory; the chosen length is remembered for the session only.
- **A11y:** "Keep awake, off. Length 1h." / "Keep awake, on. until 15:40."; buttons "Keep awake for 1h", "Length 1h, change", "Stop keeping awake".

### 3.11 Moon (Now, new, off by default)
- **Job:** a small, calm glance at the moon: tonight's phase and how lit it is, and when the next full or new moon is.
  Useful for late sessions, walks and photographers; delightful rather than urgent, which is why it is off by default.
- **Forms:** tile: a 32 pt disc (ink 14% track, lit part in ink), the phase name ("Waxing gibbous"), `63% LIT`. Wide
  adds "Full moon in 5 days" (or "New moon tomorrow") on the right in ink2, truncating tail.
- **Data:** date math only, no network, no location, no permission. The phase comes from the mean synodic month
  (29.530589 days) counted from the new moon of 2000-01-06 18:14 UTC; illumination is `(1 - cos 2π·cycle) / 2`. Accurate
  to about half a day (the real moon's speed varies), which is fine for a glance and is not an almanac.
- **Drawing:** a static polygon (limb plus terminator, 66 points) as a `Shape`; no animation, no `Canvas`, drawn once.
  Waxing is lit on the right, waning on the left, **as seen from the northern hemisphere** (a southern-hemisphere flip
  is not built; UNVERIFIED need).
- **Eight phases**, each an eighth of the month centred on its moment: New, Waxing crescent, First quarter, Waxing
  gibbous, Full, Waning gibbous, Last quarter, Waning crescent.
- **Closed notch:** nothing.
- **A11y:** one element: "Moon, waxing gibbous, 63% lit. Full moon in 5 days."
- **CPU:** `Ticking(seconds: 3600, active: visible)`: one redraw an hour while its page is visible; otherwise nothing.

### 3.12 Roll (Now, new, off by default)
- **Job:** settle a small question (who goes first, which of two options, a number from 1 to 20) with one click, without
  opening a site or a search.
- **Forms:** tile or wide (the shared widget card). Ready: [die] Roll, a mode chip (`Coin`, click to cycle `Coin D6 D20`)
  and a roll button. After a roll: the result in mono 15 semibold ("Heads", "4"), status = the mode (`D6`). Wide also
  shows the previous results (up to 4) in ink3 beside the buttons.
- **Randomness:** Swift's `SystemRandomNumberGenerator` (secure, unbiased `Int.random(in:)`); the pure logic takes any
  generator, so the self-test uses a seeded one and checks range, coverage and a fair coin.
- **State:** in memory only. Changing the mode clears the result and history, so a "4" never sits under "Coin".
- **Closed notch:** nothing. **Data, network, permission:** none. **Motion:** the result swaps with the standard blur-swap.
- **A11y:** "D6 roll: 4."; buttons "Flip the coin" / "Roll the D6", "Rolling D6, change".
- **CPU:** nothing ticks; a click is the only work.

## 4. Customization
- **What users choose:** which pages exist (on/off), their order, which widgets are on each page, their order, and which
  are hidden. The packing rule (ADR 0019) is unchanged and runs per page.
- **In the notch (Edit widgets):**
  - Edits the **current page**; the dots still switch pages.
  - Drag to arrange (as today); − hides a widget.
  - The tray lists **every hidden widget, from any page**, as + chips. + puts it on **this** page and shows it. That's
    how a widget moves between pages in the notch: hide it here, add it there.
  - Right-click a card: Move up · Move down · **Move to ▸ Now / Notes / Day** · Hide · Edit widgets….
- **In Settings → Widgets:**
  - **Pages:** a native list, drag to reorder, a switch per page.
  - **One section per page:** its widgets, drag to reorder, a switch each, and a **Page** menu to move a widget.
  - Then each widget's own settings: Clock (zones), Weather (city, units, attribution), Notes (capture shortcut, count,
    Delete all notes…), Calendar (access status and action).
  - Reset returns pages and widgets to the defaults (§1.1); it never deletes notes.
- **Persistence:** `AppSettings.pages` (ADR 0021). The old `AppSettings.widgets` is migrated once (ADR 0021 §Migration).

## 5. The closed notch: only what's live
Priority, highest first (one wing pair at a time; hover shows everything):
1. Agent moments (A1–A3, later)
2. Transient alerts: screenshot copied, low battery, internet lost or back, timer done (as today)
3. **Meeting soon** (new)
4. Music playing
5. Timer running
6. **Stopwatch running** (new)

Clock, notes and weather never take the closed notch.

## 6. Agents page and agent chat (designed now, ships with A1–A2)
**Not shipped in this update.** The design rules forbid a page without real content, so the page and its dot appear only
when belayd is running and reports at least one session (A1).

### 6.1 Page
- **Job:** see every agent session and answer the ones that need you.
- **Content:** one wide card per session, most urgent first:
  `[terminal app icon] belay · main` / status line `WAITING · APPROVE BASH` (warning), `WORKING · EDITING NOTCHVIEWS.SWIFT`
  (live), `DONE · 3 MIN AGO` (ink3) … elapsed on the right.
- **Approvals (A2) are not hidden on a page.** A rope drop takes over the closed notch, and opening the notch shows the
  approval card **pinned above whatever page is visible** (Allow ↵ / Deny ⎋ / Always ⇧↵). The product's first priority
  never depends on which page you left the notch on (ui-inventory §2).
- **Expanded:** each card shows its last 3 tool calls and the files it touched.
- **Brand slot:** becomes the status light (beepo's eyes live green while any agent works), as already planned.

### 6.2 Chat with agents
- **Composer:** the Agents page's last row is a field, "Reply to belay · main" (the focused session; ⌘↑/⌘↓ change it).
  It uses the same focus approach as Notes (§1.5).
- **What a message is (ADR 0020):** the user's own words, verbatim and attributed: "The user replied in Belay, the
  approval app they configured. Their reply, verbatim: "…"". Belay never adds instructions of its own.
- **How it reaches the agent:**
  1. **While a request is held** (A2): the reply is the deny message (the spike-verified path).
  2. **While the agent works:** the reply is queued and delivered at the next hook boundary that can carry it: the
     `Stop` hook ("block" with the reply as the reason, so the agent continues with it). Shown as "Queued · sends when
     Claude pauses". **UNVERIFIED:** the A0 spike logged `Stop` but didn't test continuing from it. Verify in A1 before
     building the composer.
  3. **No session reachable:** the field isn't shown (never a disabled composer).
- **Crew (`docs/crew.md`, v0.2):** the same composer addresses crew members by name ("Scout, find …"); routing goes
  through `CrewService` (ADR 0009). Untrusted content never authors a message (ADR 0011).
- **Voice (A4):** push-to-talk fills the composer; you confirm before it's sent (ADR 0020).

## 7. Performance rules for the hub
- **Only the visible page exists.** Hidden pages aren't in the view tree: no `Ticking`, no polling, no network.
- **Every tick is `Ticking(active:)`** with `active = notch open && page visible && widget live`.
- **Network only while visible and stale:** weather ≤ once per 30 min while Day is visible.
- **No system queries in `body`:** EventKit, notes and the forecast are loaded into models off the render path.
- **Swipe:** the follow offset is a render-only `.offset` on a `geometryGroup`; no layout per scroll event.
- **The scroll and key monitors exist only while the notch is open.**
- **Budgets** (measured in `docs/performance.md`):

| State | Budget |
|---|---|
| Open, any page, nothing running | ≤ 0.3% |
| Open, Now, timer or stopwatch running | ≤ 1% |
| Closed, stopwatch wing | ≤ 0.3% |
| Page change | ≤ 8.3 ms CPU per frame |
| Weather fetch | one request per 30 min while Day is visible |
| Calendar, closed | 0.0% (one scheduled wake-up) |

## 8. States to screenshot
- Now: clock tile + timer ready with chips; clock wide with zones; stopwatch running with laps; music + clock.
- Notes: empty field, with notes, searching, hover actions, focused by the shortcut.
- Day: calendar not determined + weather ready; calendar demo events + weather live; denied.
- Dots: three pages, the current one on each page; one page (no dots).
- Edit mode on a page, with the tray holding a widget from another page.
- Closed: stopwatch wing, meeting-soon wing.

## 9. Not now
- Custom-named pages and more than one copy of a widget.
- Dragging a card onto a dot to move it between pages (the tray and the context menu cover it).
- Editing a note in place (copy, delete and re-capture cover v1).
- Reminders, clipboard history, file shelf (conversions), a recorder for the capture shortcut.
