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
check(Pages.visible(moved, present: { _ in true }) == [.now, .day], "visible: pages with a shown widget, in order")
check(Pages.visible(moved, present: { $0 == .nowPlaying }) == [.now], "visible: a page with nothing present is skipped")
var off = moved; off[0].enabled = false
check(Pages.visible(off, present: { _ in true }) == [.day], "visible: a page switched off is skipped")
check(Pages.resolve(.notes, visible: [.now, .day]) == .now, "resolve falls back to the first visible page")
check(Pages.resolve(.day, visible: [.now, .day]) == .day, "resolve keeps the remembered page")
check(Pages.neighbour(of: .now, by: 1, visible: [.now, .day]) == .day && Pages.neighbour(of: .day, by: 1, visible: [.now, .day]) == nil, "neighbour has no wrap")
var stepped = Pages.defaults
Pages.step(.screenshot, by: -1, skippingDisabled: false, in: &stepped)
check(stepped[0].widgets.map(\.kind) == [.clock, .nowPlaying, .screenshot, .timer], "step moves within the page")
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

print(failures == 0 ? "PASS" : "FAILED: \(failures)")
exit(failures == 0 ? 0 : 1)
