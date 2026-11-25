import Foundation

// The widget model and packing rule (ADR 0019, docs/notch-widgets.md §4). Foundation only, so the self-test can
// compile it alone with swiftc (scripts/widgets-selftest.sh).

/// Every widget the open notch can show. Order of cases is the default order.
enum WidgetKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case nowPlaying, timer, screenshot
    var id: String { rawValue }
    var name: String {
        switch self {
        case .nowPlaying: "Now playing"
        case .timer: "Timer"
        case .screenshot: "Last screenshot"
        }
    }
    var symbol: String {
        switch self {
        case .nowPlaying: "music.note"
        case .timer: "timer"
        case .screenshot: "camera.viewfinder"
        }
    }
}

/// The user's choice for one widget: shown or not. The array's order is the user's order.
struct WidgetSetting: Codable, Equatable, Identifiable, Sendable {
    var kind: WidgetKind
    var enabled: Bool
    var id: WidgetKind { kind }

    /// The timer is a side option (owner, 2026-11-25): listed, but off until the user turns it on.
    static let defaults: [WidgetSetting] = WidgetKind.allCases.map { WidgetSetting(kind: $0, enabled: $0 != .timer) }

    /// Tolerant decode: unknown kinds are dropped, duplicates keep the first, and kinds added since are appended.
    static func decode(_ data: Data) -> [WidgetSetting]? {
        guard let items = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        var out: [WidgetSetting] = []
        for item in items {
            guard let k = (item["kind"] as? String).flatMap(WidgetKind.init(rawValue:)), !out.contains(where: { $0.kind == k }) else { continue }
            out.append(WidgetSetting(kind: k, enabled: item["enabled"] as? Bool ?? true))
        }
        return normalized(out)
    }

    /// Appends any kind missing from `list` with its default, keeping the user's order for the rest.
    static func normalized(_ list: [WidgetSetting]) -> [WidgetSetting] {
        var out = list
        for d in defaults where !out.contains(where: { $0.kind == d.kind }) { out.append(d) }
        return out
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
