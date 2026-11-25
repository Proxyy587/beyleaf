import Foundation

// Keep-awake widget logic (docs/widget-hub.md §3.10). Foundation only, so the self-test compiles it with swiftc.

/// How long to keep the Mac awake. The choices are fixed: nothing to configure, one click cycles them.
enum AwakeLength: Int, CaseIterable, Sendable {
    case m30 = 30, h1 = 60, h2 = 120, h4 = 240, unlimited = 0

    /// Chip text: "30m", "1h", "2h", "4h", "∞".
    var label: String {
        switch self {
        case .m30: "30m"
        case .h1: "1h"
        case .h2: "2h"
        case .h4: "4h"
        case .unlimited: "∞"
        }
    }

    /// The next choice in the cycle, wrapping.
    var next: AwakeLength {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    /// When it ends if started at `now`; nil for no limit.
    func end(from now: Date) -> Date? { self == .unlimited ? nil : now.addingTimeInterval(Double(rawValue) * 60) }
}

enum KeepAwakeLogic {
    /// "Until 15:40" (a clock time never needs a ticking redraw), or "No limit".
    static func status(endsAt: Date?, is24: Bool, zone: TimeZone = .current) -> String {
        guard let endsAt else { return "No limit" }
        return "Until " + ClockLogic.time(endsAt, in: zone, is24: is24)
    }

    /// Whether a deadline has passed (the auto-off check, also run on wake in case the timer slept).
    static func isExpired(_ endsAt: Date?, now: Date) -> Bool { endsAt.map { $0 <= now } ?? false }

    /// VoiceOver text.
    static func spoken(active: Bool, endsAt: Date?, length: AwakeLength, is24: Bool, zone: TimeZone = .current) -> String {
        guard active else { return "Keep awake, off. Length \(length == .unlimited ? "no limit" : length.label)." }
        return "Keep awake, on. " + status(endsAt: endsAt, is24: is24, zone: zone).lowercased() + "."
    }
}
