import Foundation

// Clock widget logic (docs/widget-hub.md §3.1). Foundation only, so the self-test compiles it with swiftc.

enum ClockLogic {
    /// "14:32" or "2:32 PM" in `zone`, following the 24-hour choice.
    static func time(_ date: Date, in zone: TimeZone, is24: Bool, locale: Locale = Locale(identifier: "en_US_POSIX")) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = zone
        f.dateFormat = is24 ? "HH:mm" : "h:mm a"
        return f.string(from: date)
    }

    /// "WED 25 NOV", for the status line under the time.
    static func dateLine(_ date: Date, in zone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = zone
        f.dateFormat = "EEE d MMM"
        return f.string(from: date).uppercased().replacingOccurrences(of: ".", with: "")
    }

    /// Whole days between the local calendar day and the zone's calendar day (-1 yesterday, 0 same, 1 tomorrow).
    static func dayOffset(_ date: Date, zone: TimeZone, local: TimeZone = .current) -> Int {
        var l = Calendar(identifier: .gregorian); l.timeZone = local
        var z = Calendar(identifier: .gregorian); z.timeZone = zone
        let a = l.dateComponents([.year, .month, .day], from: date)
        let b = z.dateComponents([.year, .month, .day], from: date)
        guard let da = Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: .gmt, year: a.year, month: a.month, day: a.day)),
              let db = Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: .gmt, year: b.year, month: b.month, day: b.day))
        else { return 0 }
        return Int((db.timeIntervalSince(da) / 86_400).rounded())
    }

    /// "+5h", "-3h", "+5:30h", or "same" when the offsets match.
    static func offset(_ date: Date, zone: TimeZone, local: TimeZone = .current) -> String {
        let secs = zone.secondsFromGMT(for: date) - local.secondsFromGMT(for: date)
        if secs == 0 { return "same" }
        let m = abs(secs) / 60
        let body = m % 60 == 0 ? "\(m / 60)h" : "\(m / 60):\(String(format: "%02d", m % 60))h"
        return (secs > 0 ? "+" : "-") + body
    }

    /// The offset text, or "Tomorrow" / "Yesterday" when the zone is on another day (spec §3.1).
    static func note(_ date: Date, zone: TimeZone, local: TimeZone = .current) -> String {
        switch dayOffset(date, zone: zone, local: local) {
        case 1: "Tomorrow"
        case -1: "Yesterday"
        default: offset(date, zone: zone, local: local)
        }
    }

    /// "Europe/London" → "London", "America/Port_of_Spain" → "Port of Spain".
    static func city(_ identifier: String) -> String {
        (identifier.split(separator: "/").last.map(String.init) ?? identifier).replacingOccurrences(of: "_", with: " ")
    }

    /// Whether the system's time format is 24-hour ("HH" in the localized pattern for hour).
    static var system24Hour: Bool {
        !(DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "").contains("a")
    }

    static let maxZones = 3

    /// Valid, distinct, capped identifiers in the user's order.
    static func clean(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { TimeZone(identifier: $0) != nil && seen.insert($0).inserted }.prefix(maxZones).map { $0 }
    }

    /// The system's zones whose city or identifier contains every word of `query`, city-name matches first.
    static func search(_ query: String, among all: [String] = TimeZone.knownTimeZoneIdentifiers) -> [String] {
        let words = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .split(whereSeparator: { $0 == " " || $0 == "_" }).map(String.init)
        guard !words.isEmpty else { return [] }
        let hits = all.filter { id in
            let hay = id.replacingOccurrences(of: "_", with: " ").folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            return words.allSatisfy { hay.contains($0) }
        }
        let first = words[0]
        return hits.sorted { a, b in
            let pa = city(a).folding(options: [.caseInsensitive], locale: nil).hasPrefix(first)
            let pb = city(b).folding(options: [.caseInsensitive], locale: nil).hasPrefix(first)
            return pa != pb ? pa : a < b
        }
    }

    /// VoiceOver text: "14:32, Wednesday 25 November. London 19:32."
    static func spoken(_ date: Date, zones: [String], is24: Bool) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "EEEE d MMMM"
        var s = "\(time(date, in: .current, is24: is24)), \(f.string(from: date))."
        for id in zones { if let z = TimeZone(identifier: id) { s += " \(city(id)) \(time(date, in: z, is24: is24))." } }
        return s
    }
}
