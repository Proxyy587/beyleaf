// Self-test for the widget packing rule and settings decode (ADR 0019).
// Run: apps/mac/scripts/widgets-selftest.sh
import Foundation

var failures = 0
@MainActor func check(_ ok: Bool, _ what: String) { print(ok ? "ok    \(what)" : "FAIL  \(what)"); if !ok { failures += 1 } }
func shape(_ rows: [[PlacedWidget]]) -> String {
    rows.map { $0.map { "\($0.kind.rawValue):\($0.size == .wide ? "W" : "t")" }.joined(separator: "+") }.joined(separator: " | ")
}
let np = WidgetKind.nowPlaying, tm = WidgetKind.timer, ss = WidgetKind.screenshot

// 1. Nothing shown: no rows.
check(WidgetLayout.rows([]).isEmpty, "empty input gives no rows")

// 2. Two tiles share a row.
check(shape(WidgetLayout.rows([(tm, .tile), (ss, .tile)])) == "timer:t+screenshot:t", "two tiles pair")

// 3. A lone tile is promoted to wide.
check(shape(WidgetLayout.rows([(tm, .tile)])) == "timer:W", "lone tile promoted")

// 4. A wide widget splits tiles and each lone tile is promoted; order is kept.
let mixed = WidgetLayout.rows([(tm, .tile), (np, .wide), (ss, .tile)])
check(shape(mixed) == "timer:W | nowPlaying:W | screenshot:W", "wide between tiles: order kept, both promoted")

// 5. Wide first, then a pair.
check(shape(WidgetLayout.rows([(np, .wide), (tm, .tile), (ss, .tile)])) == "nowPlaying:W | timer:t+screenshot:t", "wide then pair")

// 6. No row ever holds a single tile (the no-hole guarantee), over every order and size mix.
var allOk = true
let kinds = Array(WidgetKind.allCases.prefix(5))   // 5! orders × 4^5 masks; more kinds add nothing new to the rule
func perms<T>(_ a: [T]) -> [[T]] { a.count <= 1 ? [a] : a.indices.flatMap { i -> [[T]] in var r = a; let x = r.remove(at: i); return perms(r).map { [x] + $0 } } }
for order in perms(kinds) {
    for mask in 0..<(1 << (kinds.count * 2)) {
        var items: [(kind: WidgetKind, size: WidgetSize)] = []
        for (i, k) in order.enumerated() {
            switch (mask >> (2 * i)) & 3 { case 0: continue; case 1: items.append((k, .wide)); default: items.append((k, .tile)) }
        }
        let rows = WidgetLayout.rows(items)
        let flat = rows.flatMap { $0 }.map(\.kind)
        if flat != items.map(\.kind) { allOk = false }                       // order preserved, nothing dropped
        if rows.contains(where: { $0.count == 1 && $0[0].size == .tile }) { allOk = false }  // no half-row hole
        if rows.contains(where: { $0.count == 2 && $0.contains { $0.size == .wide } }) { allOk = false }
    }
}
check(allOk, "every order and size mix: order kept, no half-row hole, pairs are tiles")

// 7. Old `widgets` decode: unknown kinds dropped, duplicates collapsed, user order kept.
let json = #"[{"kind":"screenshot","enabled":false},{"kind":"volume","enabled":true},{"kind":"screenshot","enabled":true},{"kind":"nowPlaying","enabled":true}]"#
let decoded = WidgetSetting.decode(Data(json.utf8)) ?? []
check(decoded.map(\.kind) == [.screenshot, .nowPlaying], "old decode drops unknown, keeps first duplicate")
check(decoded.first?.enabled == false, "old decode keeps enabled flags")

// 8. Pages (ADR 0021). Invariant: every page once, every widget exactly once.
func invariant(_ pages: [PageSetting]) -> Bool {
    let ws = pages.flatMap { $0.widgets.map(\.kind) }
    return Set(pages.map(\.kind)) == Set(PageKind.allCases) && pages.count == PageKind.allCases.count
        && ws.count == WidgetKind.allCases.count && Set(ws) == Set(WidgetKind.allCases)
}
check(invariant(Pages.defaults), "defaults hold the invariant")
check(Pages.defaults.allSatisfy { p in p.widgets.allSatisfy { $0.kind.home == p.kind } }, "defaults put each widget on its home page")

// 9. Migration keeps the old Now order and switches, and adds everything else.
let migrated = Pages.migrated(from: decoded)
check(invariant(migrated), "migration holds the invariant")
let nowOrder = migrated.first { $0.kind == .now }!.widgets.map(\.kind).filter { decoded.map(\.kind).contains($0) }
check(nowOrder == [.screenshot, .nowPlaying], "migration keeps the user's order on Now")
check(migrated.first { $0.kind == .now }!.widgets.first { $0.kind == .screenshot }?.enabled == false, "migration keeps switches")

// 10. Pages decode: unknown page and widget kinds dropped, cross-page duplicates keep the first, missing added back.
let pjson = #"[{"kind":"day","enabled":false,"widgets":[{"kind":"timer","enabled":true},{"kind":"weather2","enabled":true}]},{"kind":"mars","enabled":true,"widgets":[]},{"kind":"now","enabled":true,"widgets":[{"kind":"timer","enabled":false},{"kind":"nowPlaying","enabled":true}]}]"#
let pages = Pages.decode(Data(pjson.utf8)) ?? []
check(invariant(pages), "pages decode holds the invariant")
check(pages.first?.kind == .day && pages.first?.enabled == false, "pages decode keeps page order and switch")
check(Pages.page(of: .timer, in: pages) == .day, "a widget listed twice keeps its first page")
check(Pages.decode(Data("nonsense".utf8)) == nil, "garbage is rejected")

// 11. Moves and visibility.
var moved = Pages.defaults
Pages.move(.timer, to: .day, in: &moved)
check(invariant(moved) && Pages.page(of: .timer, in: moved) == .day, "move between pages keeps the invariant")
check(Pages.visible(moved, present: { _ in true }) == [.now, .notes, .day], "visible: pages with a shown widget, in order (Notes holds the Notes widget)")
check(Pages.visible(Pages.defaults, present: { $0 == .notes }) == [.notes], "visible: the Notes page shows whenever its field is present")
check(Pages.visible(moved, present: { $0 == .nowPlaying }) == [.now], "visible: a page with nothing present is skipped")
var off = moved; off[0].enabled = false
check(Pages.visible(off, present: { _ in true }) == [.notes, .day], "visible: a page switched off is skipped")
check(Pages.resolve(.notes, visible: [.now, .day]) == .now, "resolve falls back to the first visible page")
check(Pages.resolve(.day, visible: [.now, .day]) == .day, "resolve keeps the remembered page")
check(Pages.neighbour(of: .now, by: 1, visible: [.now, .day]) == .day && Pages.neighbour(of: .day, by: 1, visible: [.now, .day]) == nil, "neighbour has no wrap")
var stepped = Pages.defaults
Pages.step(.screenshot, by: -1, skippingDisabled: false, in: &stepped)
check(Array(stepped[0].widgets.map(\.kind).prefix(5)) == [.clock, .nowPlaying, .timer, .screenshot, .stopwatch], "step moves within the page")
check(!Pages.canStep(.clock, by: -1, in: Pages.defaults), "step stops at the page's start")

// 12. Overflow: a page taller than the room scrolls inside it; otherwise it hugs its rows.
check(PanelFit.fit(natural: 200, limit: 300) == (200, false), "fit: short page hugs its rows")
check(PanelFit.fit(natural: 300, limit: 300) == (300, false), "fit: exact fit does not scroll")
check(PanelFit.fit(natural: 450, limit: 300) == (300, true), "fit: tall page is capped and scrolls")
check(PanelFit.fit(natural: 450, limit: -5) == (0, true), "fit: no room never goes negative")
check(PanelFit.maxContent(canvas: 620, screen: 1243, notch: 37) == 551, "maxContent: canvas bound on a tall screen")
check(PanelFit.maxContent(canvas: 620, screen: 600, notch: 37) == 323, "maxContent: 60% of a short screen")
check(PanelFit.edges(offset: 0, natural: 400, visible: 300) == (false, true), "edges: at top, more below")
check(PanelFit.edges(offset: 50, natural: 400, visible: 300) == (true, true), "edges: middle fades both")
check(PanelFit.edges(offset: 100, natural: 400, visible: 300) == (true, false), "edges: at end, more above only")
// Every enabled widget of the busiest page, drawn as tiles or wide: the rows account for each one once.
let busy = WidgetLayout.rows(WidgetKind.allCases.map { ($0, WidgetSize.tile) })
check(busy.flatMap { $0 }.map(\.kind) == WidgetKind.allCases, "overflow: nothing is dropped when rows exceed the room")

// 13. Page swipe (docs/widget-hub.md §1.3). Deltas are finger-direction: negative = fingers left = next page.
func swipe(_ steps: [(CGFloat, CGFloat)], hasNeighbour: Bool = true, follow: Bool = true) -> (results: [SwipeTracker.Result], tracker: SwipeTracker) {
    var t = SwipeTracker(), out: [SwipeTracker.Result] = []
    for (i, d) in steps.enumerated() {
        let phase: SwipeTracker.Phase = i == 0 ? .began : i == steps.count - 1 ? .ended : .changed
        out.append(t.feed(dx: d.0, dy: d.1, phase: phase, followsFingers: follow) { _ in hasNeighbour })
    }
    return (out, t)
}
let drag = swipe([(-10, 0), (-30, 0), (-30, 0), (-60, 0), (0, 0)])
check(drag.results.dropLast().allSatisfy(\.consumed), "swipe: horizontal gesture is consumed")
check(drag.results.dropLast().compactMap(\.offset).allSatisfy { $0 <= 0 && $0 >= -40 }, "swipe: follow offset stays within 40 pt")
check(drag.results.last?.commit == 1 && drag.results.last?.settle == true, "swipe: fingers left past 60 pt commits to the next page")
check(swipe([(40, 0), (40, 0), (0, 0)]).results.last?.commit == -1, "swipe: fingers right past 60 pt commits to the previous page")
let short = swipe([(-20, 0), (-30, 0), (0, 0)])
check(short.results.last?.commit == nil && short.results.last?.settle == true, "swipe: under 60 pt springs back without committing")
let huge = swipe([(-500, 0), (-500, 0), (0, 0)])
check(huge.results.compactMap(\.offset).allSatisfy { abs($0) <= 40 }, "swipe: a huge swipe still moves the page at most 40 pt")
let edge = swipe([(-80, 0), (-80, 0), (0, 0)], hasNeighbour: false)
check(edge.results.last?.commit == nil, "swipe: no commit past the last page (no wrap)")
check(edge.results.compactMap(\.offset).allSatisfy { abs($0) < 14 }, "swipe: the end rubber-bands under 14 pt")
let vertical = swipe([(-2, 10), (-3, 30), (-60, 40), (0, 0)])
check(vertical.results.allSatisfy { !$0.consumed && $0.offset == nil && $0.commit == nil }, "swipe: a vertical scroll is never consumed, even if it drifts sideways")
check(swipe([(-10, 0), (-40, 0), (0, 0)], follow: false).results.allSatisfy { $0.offset == nil }, "swipe: reduced motion has no follow")
check(swipe([(-40, 0), (-40, 0), (0, 0)], follow: false).results.last?.commit == 1, "swipe: reduced motion still commits")
var mt = drag.tracker
check(mt.momentum(ended: false) && mt.momentum(ended: true) && !mt.momentum(ended: false), "swipe: momentum after a swipe is swallowed, then released")
var v2 = SwipeTracker(); _ = v2.feed(dx: 0, dy: 20, phase: .began, followsFingers: true) { _ in true }; _ = v2.feed(dx: 0, dy: 0, phase: .ended, followsFingers: true) { _ in true }
check(!v2.momentum(ended: false), "swipe: momentum after a vertical scroll is left to the scroll view")

// Clock (docs/widget-hub.md §3.1)
do {
    let utc = TimeZone(identifier: "UTC")!, lon = TimeZone(identifier: "Europe/London")!, tok = TimeZone(identifier: "Asia/Tokyo")!
    let ny = TimeZone(identifier: "America/New_York")!, kol = TimeZone(identifier: "Asia/Kolkata")!
    // 2026-11-25 (Wednesday) 14:32 UTC
    let t = Date(timeIntervalSince1970: 1_795_617_120)
    check(ClockLogic.time(t, in: utc, is24: true) == "14:32", "clock: 24-hour time")
    check(ClockLogic.time(t, in: utc, is24: false) == "2:32 PM", "clock: 12-hour time")
    check(ClockLogic.dateLine(t, in: utc) == "WED 25 NOV", "clock: date line is WED 25 NOV")
    check(ClockLogic.offset(t, zone: tok, local: utc) == "+9h", "clock: Tokyo is +9h from UTC")
    check(ClockLogic.offset(t, zone: kol, local: utc) == "+5:30h", "clock: Kolkata is +5:30h")
    check(ClockLogic.offset(t, zone: ny, local: utc) == "-5h", "clock: New York is -5h in November")
    check(ClockLogic.offset(t, zone: lon, local: utc) == "same", "clock: London equals UTC in November")
    check(ClockLogic.note(t, zone: tok, local: utc) == "+9h", "clock: 23:32 in Tokyo is still today, so the offset shows")
    let late = t.addingTimeInterval(5.5 * 3600)   // 20:02 UTC = 05:02 next day in Tokyo, 15:02 in New York
    check(ClockLogic.note(late, zone: tok, local: utc) == "Tomorrow", "clock: a zone on the next day says Tomorrow")
    let early = t.addingTimeInterval(-12 * 3600)  // 02:32 UTC = 21:32 the day before in New York
    check(ClockLogic.note(early, zone: ny, local: utc) == "Yesterday", "clock: a zone on the previous day says Yesterday")
    check(ClockLogic.city("America/Port_of_Spain") == "Port of Spain" && ClockLogic.city("Europe/London") == "London", "clock: city names from identifiers")
    check(ClockLogic.clean(["Europe/London", "Nope/Zone", "Europe/London", "Asia/Tokyo", "Asia/Kolkata", "America/New_York"]) == ["Europe/London", "Asia/Tokyo", "Asia/Kolkata"], "clock: zones are validated, distinct and capped at 3")
    check(ClockLogic.search("lond").first == "Europe/London", "clock: search finds London by prefix")
    check(ClockLogic.search("new york").contains("America/New_York") && ClockLogic.search("").isEmpty, "clock: multi-word search; empty query gives nothing")
    check(ClockLogic.spoken(t, zones: ["Europe/London"], is24: true).contains("London 14:32."), "clock: spoken label names the zones")
}

// Stopwatch (docs/widget-hub.md §3.3)
do {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }
    var w = StopwatchState()
    check(w.isReady && w.elapsed(at: at(50)) == 0, "stopwatch: ready shows zero")
    check(!w.lap(at: at(1)) && w.laps.isEmpty, "stopwatch: no lap while ready")
    w.start(at: at(0))
    check(w.isRunning && w.elapsed(at: at(12)) == 12, "stopwatch: running counts from start")
    w.pause(at: at(30))
    check(!w.isRunning && w.elapsed(at: at(500)) == 30, "stopwatch: paused holds its value")
    check(!w.lap(at: at(500)), "stopwatch: no lap while paused")
    w.resume(at: at(100))
    check(w.elapsed(at: at(110)) == 40, "stopwatch: resume continues from the paused value, not wall time")
    w.start(at: at(200))
    check(w.elapsed(at: at(110)) == 40, "stopwatch: start while running is ignored")
    var l = StopwatchState(); l.start(at: at(0))
    l.lap(at: at(41.37)); l.lap(at: at(60)); l.lap(at: at(61)); l.lap(at: at(100))
    check(l.laps.count == 4 && abs(l.laps[0] - 41.37) < 1e-4 && abs(l.laps[1] - 18.63) < 1e-4, "stopwatch: laps are measured from the previous lap")
    check(l.recentLaps.map(\.number) == [4, 3, 2], "stopwatch: last three laps, newest first, numbered")
    l.reset()
    check(l.isReady && l.laps.isEmpty && l.elapsed(at: at(999)) == 0, "stopwatch: reset returns to ready and clears laps")
    check(StopwatchFormat.elapsed(724) == "12:04" && StopwatchFormat.elapsed(3725) == "1:02:05" && StopwatchFormat.elapsed(5) == "0:05", "stopwatch: elapsed format")
    check(StopwatchFormat.precise(41.37) == "0:41.37" && StopwatchFormat.precise(3725.5) == "1:02:05.50", "stopwatch: lap format shows hundredths")
    check(StopwatchFormat.wing(30) == "<1m" && StopwatchFormat.wing(724) == "12m", "stopwatch: closed notch label")
    check(StopwatchFormat.spoken(724, running: true) == "Stopwatch, 12 minutes 4 seconds, running", "stopwatch: spoken label")
}

// Notes (docs/widget-hub.md §3.4)
do {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    func note(_ text: String, _ ago: Double) -> Note { Note(id: UUID(), text: text, created: t0.addingTimeInterval(-ago)) }
    check(NotesLogic.capture("  hello \n") == "hello" && NotesLogic.capture("  \n ") == nil && NotesLogic.capture("") == nil, "notes: capture trims; empty saves nothing")
    let a = note("Run bun test in core", 100), b = note("Café opens at nine", 50), c = note("tell Porter to convert the PDF", 10)
    check(NotesLogic.search([a, b, c], query: "").map(\.text) == [c.text, b.text, a.text], "notes: no query lists newest first")
    check(NotesLogic.search([a, b, c], query: "BUN CORE").map(\.text) == [a.text], "notes: every word must match, case-insensitively")
    check(NotesLogic.search([a, b, c], query: "cafe").map(\.text) == [b.text], "notes: accent-insensitive")
    check(NotesLogic.search([a, b, c], query: "zzz").isEmpty, "notes: no match gives nothing")
    let w1 = note("xxtest at the end", 10), w2 = note("test first", 100)
    check(NotesLogic.search([w1, w2], query: "test").map(\.text) == [w2.text, w1.text], "notes: a word-start match outranks a mid-word match")
    var many: [Note] = []
    for i in 0..<5_002 { many = NotesLogic.adding(Note(id: UUID(), text: "n\(i)", created: t0.addingTimeInterval(Double(i))), to: many) }
    check(many.count == 5_000 && many.first?.text == "n2" && many.last?.text == "n5001", "notes: capped at 5,000, oldest dropped")
    check(NotesLogic.age(t0.addingTimeInterval(-30), now: t0) == "now" && NotesLogic.age(t0.addingTimeInterval(-240), now: t0) == "4 min"
          && NotesLogic.age(t0.addingTimeInterval(-7200), now: t0) == "2 h" && NotesLogic.age(t0.addingTimeInterval(-172_800), now: t0) == "2 d", "notes: age labels")
    check(NotesLogic.count(total: 12, matches: nil) == "12 NOTES" && NotesLogic.count(total: 1, matches: nil) == "1 NOTE" && NotesLogic.count(total: 12, matches: 3) == "3 MATCH", "notes: count status")

    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("belay-notes-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = NotesStorage(url: dir.appendingPathComponent("sub/notes.json"))
    check(store.load() == .missing, "notes: no file reads as missing")
    check(store.save([a, b]) && store.load() == .notes([a, b]), "notes: save creates the folder and round-trips")
    let raw = (try? String(contentsOf: store.url, encoding: .utf8)) ?? ""
    check(raw.contains("\"version\" : 1") && raw.contains("\"created\" : \"2027-"), "notes: file has version 1 and ISO 8601 dates")
    try? "not json".write(to: store.url, atomically: true, encoding: .utf8)
    check(store.load() == .corrupt, "notes: a damaged file reads as corrupt, not empty")
    store.setCorruptAside(now: t0)
    check(store.load() == .missing && FileManager.default.fileExists(atPath: store.url.deletingLastPathComponent().appendingPathComponent("notes.json.bad-1800000000").path), "notes: a damaged file is moved aside, never overwritten")
    let ro = NotesStorage(url: URL(fileURLWithPath: "/dev/null/notes.json"))
    check(!ro.save([a]), "notes: an unwritable location reports failure")
}

// Weather (docs/widget-hub.md §3.7): fixtures shaped like Open-Meteo's real responses (checked 2026-11-26).
do {
    let geo = Data("""
    {"results":[{"name":"London","admin1":"England","country":"United Kingdom","latitude":51.50853,"longitude":-0.12574,"timezone":"Europe/London"},
                {"name":"London","admin1":"Ontario","country":"Canada","latitude":42.98339,"longitude":-81.23304},{"id":1}]}
    """.utf8)
    let cities = WeatherLogic.parseCities(geo)
    check(cities.count == 2 && cities[0].label == "London, England, United Kingdom", "weather: geocoding gives labelled cities, skipping malformed rows")
    check(WeatherLogic.parseCities(Data("{}".utf8)).isEmpty && WeatherLogic.parseCities(Data("nope".utf8)).isEmpty, "weather: no results is an empty list, not a crash")
    check(WeatherLogic.searchURL("São Paulo")?.absoluteString.contains("name=S%C3%A3o%20Paulo") == true, "weather: search URL percent-encodes the query")
    let u = WeatherLogic.forecastURL(cities[0])?.absoluteString ?? ""
    check(u.hasPrefix("https://api.open-meteo.com/v1/forecast?") && u.contains("timeformat=unixtime") && u.contains("timezone=auto") && !u.contains("api_key"), "weather: forecast URL uses the public API, no key")

    // 2026-11-26 00:00 UTC is 1795651200; "now" is 13:20 UTC that day.
    let mid = 1_795_651_200.0
    func hours(rain: [Int]) -> String { "[" + rain.enumerated().map { "\(Int(mid) + $0.offset * 3600)" }.joined(separator: ",") + "]" }
    func fixture(rain: [Int]) -> Data {
        Data("""
        {"utc_offset_seconds":0,"current":{"time":\(Int(mid) + 48000),"temperature_2m":6.4,"weather_code":2},
         "daily":{"time":[\(Int(mid))],"temperature_2m_max":[8.2,7],"temperature_2m_min":[2.6,1]},
         "hourly":{"time":\(hours(rain: rain)),"precipitation_probability":[\(rain.map(String.init).joined(separator: ","))]}}
        """.utf8)
    }
    let now = Date(timeIntervalSince1970: mid + 13 * 3600 + 1200)
    var dry = Array(repeating: 10, count: 48)
    let f1 = WeatherLogic.parseForecast(fixture(rain: dry), fetched: now)
    check(f1 != nil && f1?.hourly.count == 48 && f1?.code == 2 && f1?.high == 8.2 && f1?.low == 2.6, "weather: forecast parses current, daily and hourly")
    check(WeatherLogic.parseForecast(Data("{\"current\":{}}".utf8), fetched: now) == nil, "weather: a malformed forecast is rejected")
    check(f1.map { WeatherLogic.rainHint($0, now: now) } == "Dry until 01:00", "weather: dry window ends 12 hours after the current hour")
    dry[15] = 60; dry[16] = 90
    check(WeatherLogic.parseForecast(fixture(rain: dry), fetched: now).map { WeatherLogic.rainHint($0, now: now) } == "Rain from 15:00", "weather: first hour at 50% or more starts the rain")
    var edge = Array(repeating: 10, count: 48); edge[13] = 50
    check(WeatherLogic.parseForecast(fixture(rain: edge), fetched: now).map { WeatherLogic.rainHint($0, now: now) } == "Rain now", "weather: rain in the current hour says now")
    var late = Array(repeating: 10, count: 48); late[25] = 100
    check(WeatherLogic.parseForecast(fixture(rain: late), fetched: now).map { WeatherLogic.rainHint($0, now: now) } == "Dry until 01:00", "weather: rain beyond 12 hours is ignored")
    check(WeatherLogic.degrees(6.4, fahrenheit: false) == "6°" && WeatherLogic.degrees(-0.3, fahrenheit: false) == "0°" && WeatherLogic.degrees(0, fahrenheit: true) == "32°", "weather: degrees round, never -0")
    let c0 = cities[0]
    check(f1.map { WeatherLogic.status(city: c0, $0, fahrenheit: false, offline: false) } == "LONDON · H 8 L 3", "weather: status line")
    check(f1.map { WeatherLogic.status(city: c0, $0, fahrenheit: false, offline: true) } == "LONDON · H 8 L 3 · OFFLINE", "weather: offline keeps the forecast and says so")
    check(f1.map { WeatherLogic.spoken(city: c0, $0, fahrenheit: false, now: now) } == "Weather in London: 6 degrees, partly cloudy, high 8, low 3. Dry until 01:00.", "weather: spoken label")
    check(WeatherUnits.celsius.isFahrenheit() == false && WeatherUnits.fahrenheit.isFahrenheit() && WeatherUnits.auto.isFahrenheit(locale: Locale(identifier: "en_US")) && !WeatherUnits.auto.isFahrenheit(locale: Locale(identifier: "en_GB")), "weather: units, automatic follows the locale")
    check(WeatherLogic.needsFetch(nil, now: now) && !WeatherLogic.needsFetch(f1, now: now.addingTimeInterval(29 * 60)) && WeatherLogic.needsFetch(f1, now: now.addingTimeInterval(31 * 60)), "weather: fetch when missing or older than 30 minutes")
    check(f1.map { !WeatherLogic.isTooStale($0, now: now.addingTimeInterval(2.9 * 3600)) && WeatherLogic.isTooStale($0, now: now.addingTimeInterval(3.1 * 3600)) } == true, "weather: too stale after 3 hours")
    check(WeatherLogic.condition(0).symbol == "sun.max" && WeatherLogic.condition(63).symbol == "cloud.rain" && WeatherLogic.condition(95).symbol == "cloud.bolt.rain" && WeatherLogic.condition(999).symbol == "cloud", "weather: condition symbols, unknown codes fall back to cloud")
}

// Calendar (docs/widget-hub.md §3.8)
do {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    func ev(_ id: String, _ title: String, start: Double, mins: Double = 30, allDay: Bool = false, url: String? = nil, loc: String? = nil, notes: String? = nil) -> CalEvent {
        CalEvent(id: id, title: title, start: t0.addingTimeInterval(start * 60), end: t0.addingTimeInterval((start + mins) * 60), allDay: allDay,
                 url: url.flatMap(URL.init(string:)), location: loc, notes: notes)
    }
    // Join links
    check(CalendarLogic.joinLink(url: URL(string: "https://zoom.us/j/123"), location: nil, notes: nil)?.host == "zoom.us", "calendar: the event URL wins when it is a meeting host")
    check(CalendarLogic.joinLink(url: URL(string: "https://example.com/agenda"), location: "Room 4 https://meet.google.com/abc-defg-hij", notes: nil)?.host == "meet.google.com", "calendar: a meeting link in the location is found")
    check(CalendarLogic.joinLink(url: nil, location: nil, notes: "Agenda: https://example.com/doc\nJoin: https://acme.zoom.us/j/9?pwd=x")?.host == "acme.zoom.us", "calendar: a subdomain of a meeting host counts; the first non-meeting link is skipped")
    check(CalendarLogic.joinLink(url: nil, location: "http://zoom.us/j/1", notes: "https://notzoom.us/j/1 https://example.com/zoom.us") == nil, "calendar: http, look-alike hosts and paths are not joinable")
    check(CalendarLogic.joinLink(url: nil, location: nil, notes: nil) == nil, "calendar: no link, no Join")
    // Which events
    let past = ev("a", "Past", start: -90), now1 = ev("b", "On now", start: -10), soon = ev("c", "Soon", start: 12), later = ev("d", "Later", start: 300)
    let far = ev("e", "Tomorrow noon", start: 1500), day = ev("f", "Holiday", start: -60, mins: 1440, allDay: true), x4 = ev("g", "Fourth", start: 400)
    check(CalendarLogic.upcoming([far, later, past, soon, now1, day, x4], now: t0).map(\.id) == ["b", "c", "d"], "calendar: not-ended timed events within 24 h, soonest first, at most 3")
    check(CalendarLogic.upcoming([far, day, past], now: t0).isEmpty, "calendar: nothing in 24 h (or only all-day) is empty, so the widget is gone")
    check(CalendarLogic.upcoming([later, x4, soon, now1], now: t0, limit: 10).count == 4, "calendar: the limit is a parameter")
    // Countdown
    check(CalendarLogic.countdown(soon, now: t0) == "in 12 min" && CalendarLogic.countdown(now1, now: t0) == "now" && CalendarLogic.countdown(past, now: t0) == nil, "calendar: countdown, now, and none once ended")
    check(CalendarLogic.countdown(ev("h", "h", start: 120), now: t0) == "in 2 h" && CalendarLogic.countdown(ev("i", "i", start: 65), now: t0) == "in 1 h 5 min", "calendar: hours in the countdown")
    check(CalendarLogic.countdown(ev("j", "j", start: 0.2), now: t0) == "in 1 min", "calendar: seconds round up to a minute, never 'in 0 min'")
    check(CalendarLogic.isImminent(ev("k", "k", start: 5), now: t0) && !CalendarLogic.isImminent(ev("l", "l", start: 5.1), now: t0) && !CalendarLogic.isImminent(now1, now: t0), "calendar: live green within 5 minutes before the start only")
    let utc = TimeZone(identifier: "UTC")!
    check(CalendarLogic.timeRange(ev("m", "m", start: 0), is24: true, zone: utc) == "\(ClockLogic.time(t0, in: utc, is24: true))–\(ClockLogic.time(t0.addingTimeInterval(1800), in: utc, is24: true))", "calendar: time range")
    check(CalendarLogic.spoken(ev("n", "Design review", start: 12, url: "https://zoom.us/j/1"), now: t0, is24: true, zone: utc).hasSuffix("in 12 minutes. Join call."), "calendar: spoken label includes the countdown and Join call")
    // Closed notch
    check(CalendarLogic.soon([ev("o", "o", start: 6)], now: t0) == nil && CalendarLogic.soon([ev("p", "p", start: 5)], now: t0)?.id == "p", "calendar: the wing opens 5 minutes before")
    check(CalendarLogic.soon([ev("q", "q", start: -1)], now: t0)?.id == "q" && CalendarLogic.soon([ev("r", "r", start: -1.1)], now: t0) == nil, "calendar: the wing closes 1 minute after the start")
    check(CalendarLogic.soon([ev("s", "s", start: 3, allDay: true)], now: t0) == nil, "calendar: all-day events never trigger the wing")
    check(CalendarLogic.soon([ev("u", "late", start: 4), ev("t", "early", start: 2)], now: t0)?.id == "t", "calendar: the earliest event owns the wing")
    check(CalendarLogic.wingLabel(ev("v", "v", start: 4.2), now: t0) == "5m" && CalendarLogic.wingLabel(ev("w", "w", start: 0.5), now: t0) == "<1m" && CalendarLogic.wingLabel(ev("x", "x", start: -0.5), now: t0) == "now", "calendar: wing label counts down to now")
    check(CalendarLogic.nextWake([ev("y", "y", start: 30), ev("z", "z", start: 10)], now: t0) == t0.addingTimeInterval(5 * 60), "calendar: one wake-up, at the next window opening")
    check(CalendarLogic.nextWake([ev("y", "y", start: 2)], now: t0) == t0.addingTimeInterval(3 * 60), "calendar: inside a window the next wake is its close")
    check(CalendarLogic.nextWake([past, day], now: t0) == nil, "calendar: nothing to wake for")
}

// System widget logic (docs/widget-hub.md §3.9): ticks to percentages, counters to rates, bytes to text.
MainActor.assumeIsolated {
    let a = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)
    let b = CPUTicks(user: 130, system: 60, idle: 910, nice: 0)   // +40 busy, +60 idle
    check(abs(SystemLogic.coreUsage(a, b) - 0.4) < 1e-9, "system: core usage is busy over elapsed ticks")
    check(SystemLogic.coreUsage(a, a) == 0, "system: no elapsed ticks reads 0, never NaN")
    let wrapped = CPUTicks(user: 10, system: 0, idle: 20, nice: 0)   // 32-bit counters wrapped past UInt32.max
    check(abs(SystemLogic.coreUsage(CPUTicks(user: UInt32.max - 9, system: 0, idle: UInt32.max - 79, nice: 0), wrapped) - 20.0 / 120.0) < 1e-9, "system: CPU counters wrap safely")
    let two = SystemLogic.cpuUsage(prev: [a, a], cur: [b, CPUTicks(user: 100, system: 50, idle: 950, nice: 0)])
    check(two != nil && abs(two!.overall - 0.2) < 1e-9 && two!.perCore.count == 2 && two!.perCore[1] == 0, "system: overall is the ticks-weighted mean of the cores")
    check(SystemLogic.cpuUsage(prev: [], cur: [a]) == nil && SystemLogic.cpuUsage(prev: [a], cur: [a, a]) == nil, "system: first sample or a core-count change has no usage yet")
    check(SystemLogic.coreUsage(CPUTicks(user: 0, system: 0, idle: 0, nice: 0), CPUTicks(user: 0, system: 0, idle: 50, nice: 50)) == 0.5, "system: nice time counts as busy")

    let mem = MemoryPages(internalPages: 1000, purgeable: 200, wired: 300, compressed: 100, pageSize: 16384)
    check(SystemLogic.memoryUsed(mem) == (800 + 300 + 100) * 16384, "system: memory used = app + wired + compressed")
    check(SystemLogic.memoryUsed(MemoryPages(internalPages: 5, purgeable: 9, wired: 1, compressed: 1, pageSize: 4096)) == 2 * 4096, "system: purgeable above internal never underflows")
    check(SystemLogic.pressure(fromSysctl: 1) == .normal && SystemLogic.pressure(fromSysctl: 2) == .warning && SystemLogic.pressure(fromSysctl: 4) == .critical && SystemLogic.pressure(fromSysctl: 9) == .normal, "system: pressure levels, unknown reads normal")

    check(SystemLogic.rate(prev: 1_000, cur: 3_000, seconds: 2) == 1_000, "system: network rate is bytes over seconds")
    check(SystemLogic.rate(prev: UInt32.max - 99, cur: 100, seconds: 1) == 200, "system: network counter wraps safely")
    check(SystemLogic.rate(prev: 0, cur: 10, seconds: 0) == 0, "system: zero elapsed time gives 0")

    check(SystemLogic.bytes(0) == "0 B" && SystemLogic.bytes(512) == "512 B" && SystemLogic.bytes(1_200) == "1.2 KB", "system: bytes, small")
    check(SystemLogic.bytes(12_400_000) == "12 MB" && SystemLogic.bytes(1_240_000_000) == "1.2 GB", "system: bytes, one decimal under 10 only")
    check(SystemLogic.bytes(999_950) == "1.0 MB" && SystemLogic.bytes(-5) == "0 B", "system: bytes carries 1000 up a unit, clamps negatives")
    check(SystemLogic.rateText(1_200_000) == "1.2 MB/s" && SystemLogic.rateText(0) == "0 B/s", "system: rate text")
    check(SystemLogic.percent(0.234) == "23%" && SystemLogic.percent(1.4) == "100%" && SystemLogic.percent(-1) == "0%", "system: percent clamps")
    check(SystemLogic.duration(minutes: 45) == "45 min" && SystemLogic.duration(minutes: 60) == "1 h" && SystemLogic.duration(minutes: 184) == "3 h 4 min", "system: durations")
    check(SystemLogic.batteryStatus(BatteryInfo(percent: 50, charging: true, pluggedIn: true, minutes: 80)) == "Charging · 1 h 20 min to full", "system: charging with an estimate")
    check(SystemLogic.batteryStatus(BatteryInfo(percent: 50, charging: true, pluggedIn: true, minutes: nil)) == "Charging", "system: charging while calculating")
    check(SystemLogic.batteryStatus(BatteryInfo(percent: 100, charging: false, pluggedIn: true, minutes: nil)) == "Charged" && SystemLogic.batteryStatus(BatteryInfo(percent: 80, charging: false, pluggedIn: true, minutes: nil)) == "Plugged in", "system: plugged in")
    check(SystemLogic.batteryStatus(BatteryInfo(percent: 40, charging: false, pluggedIn: false, minutes: 184)) == "3 h 4 min left" && SystemLogic.batteryStatus(BatteryInfo(percent: 40, charging: false, pluggedIn: false, minutes: nil)) == "On battery", "system: on battery")
    check(SystemLogic.about(chip: "Apple M2", cores: 8, memoryBytes: 17_179_869_184) == "Apple M2 · 8 cores · 16 GB" && SystemLogic.about(chip: "", cores: 0, memoryBytes: 0) == "", "system: about line, with gaps")
    check(SystemLogic.spoken(cpu: 0.23, memUsed: 8_000_000_000, memTotal: 16_000_000_000, pressure: .warning, diskFree: 200_000_000_000, down: 1_200_000, up: 0, battery: nil)
          == "CPU 23%. Memory 8.0 GB of 16 GB, pressure high. Disk 200 GB free. Network down 1.2 MB/s, up 0 B/s.", "system: spoken label")
}

// Keep awake logic (docs/widget-hub.md §3.10).
MainActor.assumeIsolated {
    check(AwakeLength.allCases.map(\.label) == ["30m", "1h", "2h", "4h", "∞"], "awake: the choices and their chips")
    check(AwakeLength.m30.next == .h1 && AwakeLength.unlimited.next == .m30, "awake: one click cycles the length and wraps")
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    check(AwakeLength.h2.end(from: t0) == t0.addingTimeInterval(7200) && AwakeLength.unlimited.end(from: t0) == nil, "awake: the end time, none for no limit")
    let utc = TimeZone(identifier: "UTC")!
    check(KeepAwakeLogic.status(endsAt: t0.addingTimeInterval(3600), is24: true, zone: utc) == "Until 23:13" && KeepAwakeLogic.status(endsAt: nil, is24: true) == "No limit", "awake: status is a clock time, so nothing has to tick")
    check(KeepAwakeLogic.isExpired(t0, now: t0) && !KeepAwakeLogic.isExpired(t0.addingTimeInterval(1), now: t0) && !KeepAwakeLogic.isExpired(nil, now: t0), "awake: expiry, never for no limit")
    check(KeepAwakeLogic.spoken(active: false, endsAt: nil, length: .h1, is24: true) == "Keep awake, off. Length 1h." && KeepAwakeLogic.spoken(active: true, endsAt: nil, length: .h1, is24: true) == "Keep awake, on. no limit.", "awake: spoken")
}

print(failures == 0 ? "PASS" : "FAILED: \(failures)")
exit(failures == 0 ? 0 : 1)
