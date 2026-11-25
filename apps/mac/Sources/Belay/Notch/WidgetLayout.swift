import Foundation

// The widget and page model and the span grid (ADR 0023, which supersedes ADR 0019's packing rule; ADR 0021 pages;
// docs/widget-hub.md). Foundation only, so the self-test can compile it alone with swiftc (scripts/widgets-selftest.sh).

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
        }
    }
    /// The page a widget starts on (and returns to on Reset).
    var home: PageKind {
        switch self {
        case .clock, .nowPlaying, .timer, .stopwatch, .screenshot: .now
        case .notes: .notes
        case .weather, .calendar: .day
        }
    }
    /// Side options start off (owner, 2026-11-25: the timer is a convenience, not the product; the stopwatch follows it).
    var onByDefault: Bool { self != .timer && self != .stopwatch }

    // MARK: Sizes (ADR 0023). A new kind declares its sizes here and nowhere else in this file.
    /// The span a widget gets when it is first placed (and on Reset). Exhaustive on purpose: a new kind must choose.
    var defaultSpan: WidgetSpan {
        switch self {
        case .nowPlaying, .notes, .calendar: .wide
        case .clock, .timer, .stopwatch, .screenshot, .weather: .small
        }
    }
    /// The narrowest span the widget's design supports. Every kind designs a `.tile` form (span 1) and a `.wide` form
    /// (span 2 and 3), so today every kind goes down to `.small`; raise this only for a widget that truly can't.
    var minSpan: WidgetSpan { .small }
    /// The spans the user may pick for this widget, narrowest first.
    var spans: [WidgetSpan] { WidgetSpan.allCases.filter { $0.rawValue >= minSpan.rawValue } }
}

/// How many columns of the panel's grid a widget takes. The grid has 2 columns, or 3 when the panel is expanded
/// (a span wider than the grid is clamped to a full row). A span of 1 draws the widget's tile form, 2 and 3 its wide form.
enum WidgetSpan: Int, Codable, CaseIterable, Identifiable, Sendable {
    case small = 1, wide = 2, full = 3
    var id: Int { rawValue }
    var name: String { switch self { case .small: "Small"; case .wide: "Wide"; case .full: "Full" } }
    /// The form the widget draws at this span.
    var form: WidgetSize { self == .small ? .tile : .wide }

    /// The span after this one among `allowed`, as it shows in a grid of `columns`: spans the grid can't tell apart
    /// (wide and full in 2 columns) count once, and the sequence wraps. A stored span wider than the grid counts as
    /// the grid's full row.
    static func next(after current: WidgetSpan, allowed: [WidgetSpan], columns: Int) -> WidgetSpan {
        var options: [WidgetSpan] = []
        for s in allowed where s.rawValue <= columns { options.append(s) }
        if allowed.contains(where: { $0.rawValue >= columns }), !options.contains(where: { $0.rawValue == columns }),
           let top = WidgetSpan(rawValue: columns) { options.append(top) }
        guard !options.isEmpty else { return current }
        let shown = min(current.rawValue, columns)
        let i = options.firstIndex { $0.rawValue >= shown } ?? 0
        return options[(options[i].rawValue == shown ? i + 1 : i) % options.count]
    }
}

/// The user's choice for one widget: shown or not, and how wide. The array's order is the user's order.
struct WidgetSetting: Codable, Equatable, Identifiable, Sendable {
    var kind: WidgetKind
    var enabled: Bool
    var span: WidgetSpan
    var id: WidgetKind { kind }

    init(kind: WidgetKind, enabled: Bool, span: WidgetSpan? = nil) {
        self.kind = kind; self.enabled = enabled; self.span = Self.clamp(span ?? kind.defaultSpan, for: kind)
    }

    /// A span the widget's design supports: never narrower than its `minSpan`.
    static func clamp(_ span: WidgetSpan, for kind: WidgetKind) -> WidgetSpan {
        span.rawValue < kind.minSpan.rawValue ? kind.minSpan : span
    }

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
            out.append(WidgetSetting(kind: k, enabled: item["enabled"] as? Bool ?? true,
                                     span: (item["span"] as? Int).flatMap(WidgetSpan.init(rawValue:))))
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
    /// The defaults: each widget on its home page, shown or not by `onByDefault`, in `autoSpans` so the first look is
    /// what ADR 0019 packed (no half-row holes). After that the user's choices are never re-packed.
    static let defaults: [PageSetting] = PageKind.allCases.map { page in
        var widgets = WidgetKind.allCases.filter { $0.home == page }.map { WidgetSetting(kind: $0, enabled: $0.onByDefault) }
        autoSpans(&widgets, clockHasZones: false)
        return PageSetting(kind: page, enabled: true, widgets: widgets)
    }

    /// Gives a page's shown widgets the spans ADR 0019's rule would have drawn: a widget that is wide by nature stays
    /// wide, small ones pair up, and a small one left alone becomes wide. Used for the defaults and to migrate pages
    /// saved before spans existed. Hidden widgets keep their own default span.
    static func autoSpans(_ widgets: inout [WidgetSetting], clockHasZones: Bool, columns: Int = 2) {
        var waiting: Int?
        for i in widgets.indices {
            guard widgets[i].enabled else { continue }
            let k = widgets[i].kind
            let wide = k.defaultSpan.rawValue >= 2 || (k == .clock && clockHasZones)
            if wide {
                if let w = waiting { widgets[w].span = .wide; waiting = nil }
                widgets[i].span = WidgetSetting.clamp(k.defaultSpan.rawValue >= 2 ? k.defaultSpan : .wide, for: k)
            } else if let w = waiting {
                widgets[w].span = .small; widgets[i].span = .small; waiting = nil
            } else {
                waiting = i
            }
        }
        if let w = waiting { widgets[w].span = .wide }
    }

    /// Tolerant decode: unknown page or widget kinds are dropped, a widget listed twice keeps its first place, and
    /// anything missing is added back at its default place (ADR 0021).
    static func decode(_ data: Data, clockHasZones: Bool = false) -> [PageSetting]? {
        guard let items = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        // Saved before spans existed (no widget carries one): lay the old packing out as spans, once (ADR 0023).
        let legacy = !items.contains { ($0["widgets"] as? [[String: Any]] ?? []).contains { $0["span"] != nil } }
        var out: [PageSetting] = []
        var seen = Set<WidgetKind>()
        for item in items {
            guard let k = (item["kind"] as? String).flatMap(PageKind.init(rawValue:)), !out.contains(where: { $0.kind == k }) else { continue }
            let widgets = WidgetSetting.parse(item["widgets"] as? [[String: Any]] ?? []).filter { seen.insert($0.kind).inserted }
            out.append(PageSetting(kind: k, enabled: item["enabled"] as? Bool ?? true, widgets: widgets))
        }
        if legacy { for i in out.indices { autoSpans(&out[i].widgets, clockHasZones: clockHasZones) } }
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
    static func migrated(from widgets: [WidgetSetting], clockHasZones: Bool = false) -> [PageSetting] {
        var pages = defaults.map { PageSetting(kind: $0.kind, enabled: $0.enabled, widgets: []) }
        if let now = pages.firstIndex(where: { $0.kind == .now }) {
            pages[now].widgets = widgets.filter { $0.kind.home == .now }
            autoSpans(&pages[now].widgets, clockHasZones: clockHasZones)
        }
        return normalized(pages)
    }

    static func page(of kind: WidgetKind, in pages: [PageSetting]) -> PageKind? {
        pages.first { $0.widgets.contains { $0.kind == kind } }?.kind
    }

    static func setEnabled(_ kind: WidgetKind, _ on: Bool, in pages: inout [PageSetting]) {
        for p in pages.indices { if let i = pages[p].widgets.firstIndex(where: { $0.kind == kind }) { pages[p].widgets[i].enabled = on } }
    }

    /// Moves a widget to the end of another page (shown), keeping its size and everything else.
    static func move(_ kind: WidgetKind, to page: PageKind, enabled: Bool = true, in pages: inout [PageSetting]) {
        guard let target = pages.firstIndex(where: { $0.kind == page }) else { return }
        let span = span(of: kind, in: pages)
        for p in pages.indices { pages[p].widgets.removeAll { $0.kind == kind } }
        pages[target].widgets.append(WidgetSetting(kind: kind, enabled: enabled, span: span))
    }

    static func span(of kind: WidgetKind, in pages: [PageSetting]) -> WidgetSpan {
        pages.lazy.flatMap(\.widgets).first { $0.kind == kind }?.span ?? kind.defaultSpan
    }

    /// Sets a widget's size (clamped to what it supports).
    static func setSpan(_ kind: WidgetKind, _ span: WidgetSpan, in pages: inout [PageSetting]) {
        for p in pages.indices { if let i = pages[p].widgets.firstIndex(where: { $0.kind == kind }) { pages[p].widgets[i].span = WidgetSetting.clamp(span, for: kind) } }
    }

    /// The next size for a widget in a grid of `columns` (tap in the editor).
    static func cycleSpan(_ kind: WidgetKind, columns: Int, in pages: inout [PageSetting]) {
        setSpan(kind, WidgetSpan.next(after: span(of: kind, in: pages), allowed: kind.spans, columns: columns), in: &pages)
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

/// The form a widget draws: its compact tile (one column) or its wide layout (two or more).
enum WidgetSize: Sendable { case wide, tile }

/// One placed widget: its kind, the columns it takes in this grid, and the form it draws.
struct PlacedWidget: Equatable, Sendable {
    let kind: WidgetKind
    /// Columns taken, 1 ... the grid's columns (a wider stored span is clamped).
    let columns: Int
    var size: WidgetSize { columns == 1 ? .tile : .wide }
}

enum WidgetLayout {
    /// The panel grid: 2 columns, 3 when expanded. Each column is the same width in both, so widgets keep their size
    /// and expanded simply holds more of them (ADR 0023).
    static func columns(expanded: Bool) -> Int { expanded ? 3 : 2 }

    /// Flows widgets into rows in the given order, each taking its span (clamped to the grid). A widget that doesn't
    /// fit the rest of the row starts the next one. Never reorders, never resizes: whatever the user arranged stays,
    /// including a row that isn't full.
    static func rows(_ items: [(kind: WidgetKind, span: WidgetSpan)], columns: Int) -> [[PlacedWidget]] {
        let cols = max(1, columns)
        var rows: [[PlacedWidget]] = []
        var used = 0
        for item in items {
            let n = min(max(1, item.span.rawValue), cols)
            if rows.isEmpty || used + n > cols { rows.append([]); used = 0 }
            rows[rows.count - 1].append(PlacedWidget(kind: item.kind, columns: n))
            used += n
        }
        return rows
    }

    /// The open panel's width when expanded: the theme's width plus one more column (and its gap), capped so the
    /// panel's shadow fits the canvas. `inner` is the width the grid gets at `base`.
    static func expandedWidth(base: CGFloat, inner: CGFloat, gap: CGFloat, cap: CGFloat) -> CGFloat {
        let column = (inner - gap) / 2
        return min(base + column + gap, max(base, cap))
    }

    /// Width of one column when `inner` is split into `columns` with `gap` between.
    static func columnWidth(inner: CGFloat, columns: Int, gap: CGFloat) -> CGFloat {
        (inner - gap * CGFloat(max(0, columns - 1))) / CGFloat(max(1, columns))
    }

    /// Smallest height a widget cell may have, so a card with little or nothing in it never collapses to a sliver.
    static func minHeight(_ size: WidgetSize, button: CGFloat, inset: CGFloat) -> CGFloat {
        size == .tile ? 2 * button + 4 + 2 * inset : button + 2 * inset + 8
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
