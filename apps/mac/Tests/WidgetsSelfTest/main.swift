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
let kinds = WidgetKind.allCases
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

// 7. Decode: unknown kinds dropped, duplicates collapsed, missing kinds appended, user order kept.
let json = #"[{"kind":"screenshot","enabled":false},{"kind":"volume","enabled":true},{"kind":"screenshot","enabled":true},{"kind":"nowPlaying","enabled":true}]"#
let decoded = WidgetSetting.decode(Data(json.utf8)) ?? []
check(decoded.map(\.kind) == [.screenshot, .nowPlaying, .timer], "decode drops unknown, keeps first duplicate, appends missing")
check(decoded.first?.enabled == false, "decode keeps enabled flags")

print(failures == 0 ? "PASS" : "FAILED: \(failures)")
exit(failures == 0 ? 0 : 1)
