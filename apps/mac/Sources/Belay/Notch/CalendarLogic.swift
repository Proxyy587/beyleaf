import Foundation

// Calendar widget logic (docs/widget-hub.md §3.8). Foundation only: no EventKit types, so the self-test can compile it.

enum CalendarAccess: Equatable, Sendable { case notDetermined, full, writeOnly, denied }

struct CalEvent: Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var allDay = false
    /// The calendar's own colour, `#RRGGBB` (content, like an app icon).
    var colorHex = "#8E8E93"
    var url: URL?
    var location: String?
    var notes: String?
}

enum CalendarLogic {
    static let meetingHosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "webex.com", "whereby.com", "around.co"]
    /// The wing shows from this long before an event until a minute after it starts.
    static let soonBefore: TimeInterval = 5 * 60
    static let soonAfter: TimeInterval = 60

    // MARK: Join link

    private static func isMeeting(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        return meetingHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// The event's own URL if it is a meeting link, else the first `https://` meeting link in the location or notes.
    static func joinLink(url: URL?, location: String?, notes: String?) -> URL? {
        if let url, isMeeting(url) { return url }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        for text in [location, notes].compactMap({ $0 }) {
            let range = NSRange(text.startIndex..., in: text)
            for m in detector?.matches(in: text, range: range) ?? [] {
                if let u = m.url, isMeeting(u) { return u }
            }
        }
        return nil
    }

    // MARK: Which events, and what to say

    /// Timed events that haven't ended and start within 24 hours, soonest first. All-day events aren't "the next thing".
    static func upcoming(_ events: [CalEvent], now: Date, limit: Int = 3) -> [CalEvent] {
        events.filter { !$0.allDay && $0.end > now && $0.start < now.addingTimeInterval(86_400) }
            .sorted { ($0.start, $0.id) < ($1.start, $1.id) }
            .prefix(limit).map { $0 }
    }

    /// "in 12 min", "in 2 h", "in 1 h 5 min", "now" while it is on, nil once it has ended.
    static func countdown(_ e: CalEvent, now: Date) -> String? {
        if now >= e.end { return nil }
        if now >= e.start { return "now" }
        let m = Int((e.start.timeIntervalSince(now) / 60).rounded(.up))
        if m < 60 { return "in \(m) min" }
        return m % 60 == 0 ? "in \(m / 60) h" : "in \(m / 60) h \(m % 60) min"
    }

    /// Live green when the event is within 5 minutes and hasn't started.
    static func isImminent(_ e: CalEvent, now: Date) -> Bool {
        let t = e.start.timeIntervalSince(now)
        return t > 0 && t <= soonBefore
    }

    /// "14:00–14:30"
    static func timeRange(_ e: CalEvent, is24: Bool, zone: TimeZone = .current) -> String {
        "\(ClockLogic.time(e.start, in: zone, is24: is24))–\(ClockLogic.time(e.end, in: zone, is24: is24))"
    }

    /// "Design review, 14:00 to 14:30, in 12 minutes. Join call."
    static func spoken(_ e: CalEvent, now: Date, is24: Bool, zone: TimeZone = .current) -> String {
        var s = "\(e.title), \(ClockLogic.time(e.start, in: zone, is24: is24)) to \(ClockLogic.time(e.end, in: zone, is24: is24))"
        if let c = countdown(e, now: now) { s += ", " + (c == "now" ? "happening now" : c.replacingOccurrences(of: " min", with: " minutes").replacingOccurrences(of: " h", with: " hours")) }
        s += "."
        if joinLink(url: e.url, location: e.location, notes: e.notes) != nil { s += " Join call." }
        return s
    }

    // MARK: Closed notch: "meeting soon"

    /// The timed event whose wing window is open now (5 min before to 1 min after its start), earliest first.
    static func soon(_ events: [CalEvent], now: Date) -> CalEvent? {
        events.filter { !$0.allDay && now >= $0.start.addingTimeInterval(-soonBefore) && now <= $0.start.addingTimeInterval(soonAfter) }
            .min { ($0.start, $0.id) < ($1.start, $1.id) }
    }

    /// "5m" … "now" for the wing.
    static func wingLabel(_ e: CalEvent, now: Date) -> String {
        let t = e.start.timeIntervalSince(now)
        if t <= 0 { return "now" }
        return t < 60 ? "<1m" : "\(Int((t / 60).rounded(.up)))m"
    }

    /// The next moment the wing's state can change (a window opening or closing): one scheduled wake-up, not a poll.
    static func nextWake(_ events: [CalEvent], now: Date) -> Date? {
        events.filter { !$0.allDay }
            .flatMap { [$0.start.addingTimeInterval(-soonBefore), $0.start.addingTimeInterval(soonAfter)] }
            .filter { $0 > now }.min()
    }
}
