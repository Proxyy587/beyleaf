import AppKit
import EventKit

/// Today's events from Calendar.app through EventKit, read-only (docs/widget-hub.md §3.8).
/// The permission is asked once, only when the user clicks "Show events". Events load when access is already granted,
/// when the store changes, and at midnight; the closed notch's "meeting soon" is one scheduled wake-up, not a poll.
@MainActor
final class CalendarService: ObservableObject {
    static let shared = CalendarService()

    @Published private(set) var access: CalendarAccess = .notDetermined
    @Published private(set) var events: [CalEvent] = []
    /// The event whose wing window is open now (5 min before to 1 min after its start).
    @Published private(set) var soon: CalEvent?

    private let store = EKEventStore()
    private var wake: Task<Void, Never>?
    private var observer: NSObjectProtocol?
    private var demo = false

    private init() { access = Self.map(EKEventStore.authorizationStatus(for: .event)) }

    private static func map(_ s: EKAuthorizationStatus) -> CalendarAccess {
        switch s {
        case .notDetermined: .notDetermined
        case .fullAccess, .authorized: .full
        case .writeOnly: .writeOnly
        default: .denied
        }
    }

    /// Called at launch: if the user already granted access, load and schedule. Never prompts.
    func start() {
        guard !demo, access == .full else { return }
        observe(); reload()
    }

    /// The only place that asks (the system's prompt). Called from the "Show events" button.
    func requestAccess() async {
        guard access == .notDetermined else { return }
        _ = try? await store.requestFullAccessToEvents()
        access = Self.map(EKEventStore.authorizationStatus(for: .event))
        if access == .full { observe(); reload() }
    }

    /// Re-reads access (the user may have changed it in System Settings) and, if granted, the events. Cheap; called when the Day page shows.
    func refresh() {
        guard !demo else { return }
        access = Self.map(EKEventStore.authorizationStatus(for: .event))
        if access == .full { observe(); reload() } else { events = []; soon = nil; wake?.cancel() }
    }

    private func observe() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    private func reload() {
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-3600), end: now.addingTimeInterval(86_400 + 3600), calendars: nil)
        events = store.events(matching: predicate).map { e in
            CalEvent(id: e.eventIdentifier ?? UUID().uuidString, title: e.title ?? "Untitled", start: e.startDate, end: e.endDate,
                     allDay: e.isAllDay, colorHex: e.calendar.cgColor.flatMap(Self.hex) ?? "#8E8E93", url: e.url, location: e.location, notes: e.notes)
        }
        schedule()
    }

    /// Sets `soon` and sleeps until the next moment it can change (and at midnight, to reload).
    private func schedule() {
        wake?.cancel()
        let now = Date()
        soon = CalendarLogic.soon(events, now: now)
        let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 5), matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
        let next = min(CalendarLogic.nextWake(events, now: now) ?? .distantFuture, midnight)
        wake = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(1, next.timeIntervalSinceNow)))
            guard !Task.isCancelled, let self else { return }
            if self.demo { return }
            next == midnight ? self.reload() : self.schedule()
        }
    }

    private static func hex(_ c: CGColor) -> String? {
        guard let rgb = NSColor(cgColor: c)?.usingColorSpace(.sRGB) else { return nil }
        return String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
    }

    #if DEBUG
    /// `--calendar-demo`: sample events and full access, in memory only (nothing is read from or written to Calendar).
    func loadDemo() {
        demo = true; access = .full
        let now = Date()
        func e(_ id: String, _ t: String, _ startMin: Double, _ len: Double, _ hex: String, url: String? = nil) -> CalEvent {
            CalEvent(id: id, title: t, start: now.addingTimeInterval(startMin * 60), end: now.addingTimeInterval((startMin + len) * 60), colorHex: hex, url: url.flatMap(URL.init(string:)))
        }
        events = [e("1", "Design review", 4, 30, "#5E9BFF", url: "https://meet.google.com/abc-defg-hij"), e("2", "Standup with the crew", 95, 15, "#34C759"), e("3", "Dentist", 240, 60, "#FF9F0A")]
        soon = CalendarLogic.soon(events, now: now)
    }
    #endif
}
