import Foundation

// The widget and page model, and the packing rule (ADR 0019, ADR 0021, docs/widget-hub.md). Foundation only, so the
// self-test can compile it alone with swiftc (scripts/widgets-selftest.sh).

/// The pages of the open notch (ADR 0021). Order of cases is the default order. `agents` joins at A1.
enum PageKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case now, notes, day
    var id: String { rawValue }
    var name: String {
        switch self {
        case .now: "Now"
        case .notes: "Notes"
        case .day: "Day"
        }
    }
    var symbol: String {
        switch self {
        case .now: "play.circle"
        case .notes: "square.and.pencil"
        case .day: "calendar"
        }
    }
}

/// Every widget the open notch can show. Order of cases is the default order within each home page.
enum WidgetKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case clock, nowPlaying, timer, stopwatch, screenshot, notes, weather, calendar
    case system, keepAwake
    var id: String { rawValue }
    var name: String {
        switch self {
        case .clock: "Clock"
        case .nowPlaying: "Now playing"
        case .timer: "Timer"
        case .stopwatch: "Stopwatch"
        case .notes: "Notes"
        case .weather: "Weather"
        case .calendar: "Calendar"
        case .screenshot: "Last screenshot"
        case .system: "System"
        case .keepAwake: "Keep awake"
        }
    }
    var symbol: String {
        switch self {
        case .clock: "clock"
        case .nowPlaying: "music.note"
        case .timer: "timer"
        case .stopwatch: "stopwatch"
        case .notes: "square.and.pencil"
        case .weather: "cloud.sun"
        case .calendar: "calendar"
        case .screenshot: "camera.viewfinder"
        case .system: "cpu"
        case .keepAwake: "cup.and.saucer"
        }
    }
    /// The page a widget starts on (and returns to on Reset).
    var home: PageKind {
        switch self {
        case .clock, .nowPlaying, .timer, .stopwatch, .screenshot, .system, .keepAwake: .now
        case .notes: .notes
        case .weather, .calendar: .day
        }
    }
    /// Side options start off (owner, 2026-11-25: the timer is a convenience, not the product; the stopwatch follows it).
    var onByDefault: Bool { self != .timer && self != .stopwatch && self != .system && self != .keepAwake }
}

/// The user's choice for one widget: shown or not. The array's order is the user's order.
struct WidgetSetting: Codable, Equatable, Identifiable, Sendable {
    var kind: WidgetKind
    var enabled: Bool
    var id: WidgetKind { kind }

    /// The pre-pages default list (ADR 0019), kept for decoding the old `widgets` key.
    static let defaults: [WidgetSetting] = WidgetKind.allCases.map { WidgetSetting(kind: $0, enabled: $0.onByDefault) }

    /// Tolerant decode of the old `widgets` key: unknown kinds dropped, duplicates keep the first.
    static func decode(_ data: Data) -> [WidgetSetting]? {
        guard let items = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        return parse(items)
    }

    static func parse(_ items: [[String: Any]]) -> [WidgetSetting] {
        var out: [WidgetSetting] = []
        for item in items {
            guard let k = (item["kind"] as? String).flatMap(WidgetKind.init(rawValue:)), !out.contains(where: { $0.kind == k }) else { continue }
            out.append(WidgetSetting(kind: k, enabled: item["enabled"] as? Bool ?? true))
        }
        return out
    }
}

/// One page: whether it's shown, and its widgets in the user's order.
struct PageSetting: Codable, Equatable, Identifiable, Sendable {
    var kind: PageKind
    var enabled: Bool
    var widgets: [WidgetSetting]
    var id: PageKind { kind }
}

/// Pure operations on the pages list. Invariant after `normalized`: every page kind once, every widget kind exactly once.
enum Pages {
    static let defaults: [PageSetting] = PageKind.allCases.map { page in
        PageSetting(kind: page, enabled: true,
                    widgets: WidgetKind.allCases.filter { $0.home == page }.map { WidgetSetting(kind: $0, enabled: $0.onByDefault) })
    }

    /// Tolerant decode: unknown page or widget kinds are dropped, a widget listed twice keeps its first place, and
    /// anything missing is added back at its default place (ADR 0021).
    static func decode(_ data: Data) -> [PageSetting]? {
        guard let items = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        var out: [PageSetting] = []
        var seen = Set<WidgetKind>()
        for item in items {
            guard let k = (item["kind"] as? String).flatMap(PageKind.init(rawValue:)), !out.contains(where: { $0.kind == k }) else { continue }
            let widgets = WidgetSetting.parse(item["widgets"] as? [[String: Any]] ?? []).filter { seen.insert($0.kind).inserted }
            out.append(PageSetting(kind: k, enabled: item["enabled"] as? Bool ?? true, widgets: widgets))
        }
        return normalized(out)
    }

    /// Adds missing pages (at their default place) and missing widgets (on their home page, at their default place).
    static func normalized(_ list: [PageSetting]) -> [PageSetting] {
        var out = list
        for (i, d) in defaults.enumerated() where !out.contains(where: { $0.kind == d.kind }) {
            out.insert(PageSetting(kind: d.kind, enabled: d.enabled, widgets: []), at: min(i, out.count))
        }
        let present = Set(out.flatMap { $0.widgets.map(\.kind) })
        for page in defaults {
            for (i, w) in page.widgets.enumerated() where !present.contains(w.kind) {
                guard let p = out.firstIndex(where: { $0.kind == page.kind }) else { continue }
                out[p].widgets.insert(w, at: min(i, out[p].widgets.count))
            }
        }
        return out
    }

    /// One-time migration from the single list of ADR 0019: it becomes the Now page; everything else is default.
    static func migrated(from widgets: [WidgetSetting]) -> [PageSetting] {
        var pages = defaults.map { PageSetting(kind: $0.kind, enabled: $0.enabled, widgets: []) }
        if let now = pages.firstIndex(where: { $0.kind == .now }) {
            pages[now].widgets = widgets.filter { $0.kind.home == .now }
        }
        return normalized(pages)
    }

    static func page(of kind: WidgetKind, in pages: [PageSetting]) -> PageKind? {
        pages.first { $0.widgets.contains { $0.kind == kind } }?.kind
    }

    static func setEnabled(_ kind: WidgetKind, _ on: Bool, in pages: inout [PageSetting]) {
        for p in pages.indices { if let i = pages[p].widgets.firstIndex(where: { $0.kind == kind }) { pages[p].widgets[i].enabled = on } }
    }

    /// Moves a widget to the end of another page (shown), keeping everything else.
    static func move(_ kind: WidgetKind, to page: PageKind, enabled: Bool = true, in pages: inout [PageSetting]) {
        guard let target = pages.firstIndex(where: { $0.kind == page }) else { return }
        for p in pages.indices { pages[p].widgets.removeAll { $0.kind == kind } }
        pages[target].widgets.append(WidgetSetting(kind: kind, enabled: enabled))
    }

    /// Moves a widget one step within its page. `skippingDisabled` steps over hidden widgets, so a move from the
    /// notch is always visible.
    static func step(_ kind: WidgetKind, by step: Int, skippingDisabled: Bool = true, in pages: inout [PageSetting]) {
        guard let p = pages.firstIndex(where: { $0.widgets.contains { $0.kind == kind } }),
              let i = pages[p].widgets.firstIndex(where: { $0.kind == kind }),
              let j = target(i, step, skippingDisabled, pages[p].widgets) else { return }
        let item = pages[p].widgets.remove(at: i)
        pages[p].widgets.insert(item, at: j)
    }

    static func canStep(_ kind: WidgetKind, by step: Int, skippingDisabled: Bool = true, in pages: [PageSetting]) -> Bool {
        guard let page = pages.first(where: { $0.widgets.contains { $0.kind == kind } }),
              let i = page.widgets.firstIndex(where: { $0.kind == kind }) else { return false }
        return target(i, step, skippingDisabled, page.widgets) != nil
    }

    private static func target(_ i: Int, _ step: Int, _ skipping: Bool, _ list: [WidgetSetting]) -> Int? {
        var j = i + step
        while list.indices.contains(j) { if !skipping || list[j].enabled { return j }; j += step }
        return nil
    }

    /// The pages to show right now: enabled, in order, with at least one widget present. `present` says whether a
    /// widget has something to show (live or ready).
    static func visible(_ pages: [PageSetting], present: (WidgetKind) -> Bool) -> [PageKind] {
        pages.filter { $0.enabled && $0.widgets.contains { $0.enabled && present($0.kind) } }.map(\.kind)
    }

    /// The page to open on: the remembered one if it's visible, else the first visible page.
    static func resolve(_ remembered: PageKind, visible: [PageKind]) -> PageKind? {
        visible.contains(remembered) ? remembered : visible.first
    }

    /// The page `step` places from `current` among the visible ones, or nil at either end (no wrap).
    static func neighbour(of current: PageKind, by step: Int, visible: [PageKind]) -> PageKind? {
        guard let i = visible.firstIndex(of: current), visible.indices.contains(i + step) else { return nil }
        return visible[i + step]
    }
}

/// What a widget has to show right now. `gone` takes no space at all.
enum WidgetPresence: Sendable { case live, ready, gone }

/// How much of a row a widget wants in its current state.
enum WidgetSize: Sendable { case wide, tile }

/// One placed widget: its kind and the size it is drawn at (a lone tile is promoted to `wide`).
struct PlacedWidget: Equatable, Sendable {
    let kind: WidgetKind
    let size: WidgetSize
}

enum WidgetLayout {
    /// Packs widgets into rows in the given order. Tiles pair with the next tile; a tile left alone (because a wide
    /// widget or the end follows it) is promoted to wide. Never reorders, never leaves a half-row hole.
    static func rows(_ items: [(kind: WidgetKind, size: WidgetSize)]) -> [[PlacedWidget]] {
        var rows: [[PlacedWidget]] = []
        var waiting: WidgetKind?
        func flush() { if let w = waiting { rows.append([PlacedWidget(kind: w, size: .wide)]); waiting = nil } }
        for item in items {
            switch item.size {
            case .wide:
                flush()
                rows.append([PlacedWidget(kind: item.kind, size: .wide)])
            case .tile:
                if let w = waiting {
                    rows.append([PlacedWidget(kind: w, size: .tile), PlacedWidget(kind: item.kind, size: .tile)])
                    waiting = nil
                } else {
                    waiting = item.kind
                }
            }
        }
        flush()
        return rows
    }
}

// MARK: - Panel fit and page swipe (docs/widget-hub.md §1.3, §7)

/// How a page's rows fit the open panel. A page that is taller than the room scrolls vertically inside it, so no
/// widget is ever clipped or pushed off screen. Pure, so the self-test covers it.
enum PanelFit {
    /// The tallest the open content (everything below the notch line) may be: inside the panel canvas with room for
    /// the shadow, and never more than `fraction` of the screen so the panel never covers the work underneath.
    static func maxContent(canvas: CGFloat, screen: CGFloat, notch: CGFloat, fraction: CGFloat = 0.6, shadow: CGFloat = 32) -> CGFloat {
        max(0, min(canvas - notch - shadow, screen * fraction - notch))
    }

    /// Height of the page area given the rows' natural height and the room for it.
    static func fit(natural: CGFloat, limit: CGFloat) -> (height: CGFloat, scrolls: Bool) {
        let room = max(0, limit)
        return natural > room + 0.5 ? (room, true) : (natural, false)
    }

    /// Which edge fades to hint at more content: top once scrolled down, bottom until the end is reached.
    static func edges(offset: CGFloat, natural: CGFloat, visible: CGFloat) -> (top: Bool, bottom: Bool) {
        (offset > 1, offset < natural - visible - 1)
    }
}

/// The two-finger page swipe as a small state machine, fed with finger-direction deltas (already normalised for
/// natural scrolling). The view layer only applies what it returns.
struct SwipeTracker {
    enum Axis { case undecided, horizontal, vertical }
    enum Phase { case began, changed, ended }

    /// Follow resistance and its cap (≤ 40 pt), the travel that commits, and how far an end of the list gives.
    static let resistance: CGFloat = 0.35
    static let maxFollow: CGFloat = 40
    static let commitTravel: CGFloat = 60
    static let endGive: CGFloat = 14
    /// Travel before the gesture is called horizontal or vertical.
    static let decide: CGFloat = 6

    struct Result: Equatable {
        /// The event belongs to a page swipe: don't pass it on (vertical scrolling must not see it).
        var consumed = false
        /// Where the page follows to, or nil to leave it.
        var offset: CGFloat?
        /// +1 next page, -1 previous, once, on release.
        var commit: Int?
        /// Released: spring back to rest.
        var settle = false
    }

    private(set) var axis = Axis.undecided
    private var x: CGFloat = 0, y: CGFloat = 0
    private var swallowMomentum = false

    /// Momentum after a horizontal swipe is swallowed, so it can't scroll the page vertically.
    mutating func momentum(ended: Bool) -> Bool {
        let s = swallowMomentum
        if ended { swallowMomentum = false }
        return s
    }

    mutating func reset() { axis = .undecided; x = 0; y = 0; swallowMomentum = false }

    /// `hasNeighbour(step)`: whether a page exists that way (else the end gives a little and never commits).
    mutating func feed(dx: CGFloat, dy: CGFloat, phase: Phase, followsFingers: Bool, hasNeighbour: (Int) -> Bool) -> Result {
        if phase == .began { x = 0; y = 0; axis = .undecided; swallowMomentum = false }
        x += dx; y += dy
        if axis == .undecided, abs(x) + abs(y) > Self.decide { axis = abs(x) > abs(y) * 1.5 ? .horizontal : .vertical }
        var r = Result(consumed: axis == .horizontal)
        if axis == .horizontal {
            let step = x < 0 ? 1 : -1
            let has = hasNeighbour(step)
            if phase == .ended {
                if has, abs(x) > Self.commitTravel { r.commit = step }
                r.settle = true
                swallowMomentum = true
            } else if followsFingers {
                let sign: CGFloat = x < 0 ? -1 : 1
                r.offset = sign * (has ? min(Self.maxFollow, abs(x) * Self.resistance)
                                       : Self.endGive * (1 - exp(-abs(x) / 50)))
            }
        }
        if phase == .ended { axis = .undecided; x = 0; y = 0 }
        return r
    }
}
