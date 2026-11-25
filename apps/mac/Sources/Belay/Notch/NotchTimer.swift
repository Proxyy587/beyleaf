import Foundation

/// A countdown for time-boxing work while agents run (Timer widget, docs/notch-widgets.md §5).
/// Publishes only on state changes; views read the remaining time from the end date inside a TimelineView, so a
/// running timer costs nothing while the notch is closed and nothing is shown.
@MainActor
final class NotchTimer: ObservableObject {
    enum State: Equatable {
        case idle
        case running(end: Date, total: TimeInterval)
        case paused(remaining: TimeInterval, total: TimeInterval)
        case done(at: Date, total: TimeInterval)
    }

    /// The duration the next start uses, kept between launches. Changed with − / + or by dragging the number.
    @Published var minutes: Int { didSet { UserDefaults.standard.set(minutes, forKey: "timerMinutes") } }

    init() { minutes = UserDefaults.standard.object(forKey: "timerMinutes") as? Int ?? 25 }

    /// Finer steps for short timers: 1…10 by 1, then by 5 to an hour, then by 15 up to 3 hours.
    static func step(_ m: Int, by dir: Int) -> Int {
        if dir > 0 { return min(180, m < 10 ? m + 1 : m < 60 ? m + 5 : m + 15) }
        return max(1, m <= 10 ? m - 1 : m <= 60 ? m - 5 : m - 15)
    }

    @Published private(set) var state: State = .idle
    /// Increments when a countdown reaches zero, so the closed notch can flash "Done".
    @Published private(set) var finished = 0

    private var fire: Task<Void, Never>?
    private var clear: Task<Void, Never>?

    var isActive: Bool { if case .idle = state { false } else { true } }
    var isRunning: Bool { if case .running = state { true } else { false } }

    func start(minutes: Int) { begin(TimeInterval(minutes * 60), total: TimeInterval(minutes * 60)) }

    func pause() {
        guard case let .running(end, total) = state else { return }
        fire?.cancel()
        state = .paused(remaining: max(0, end.timeIntervalSinceNow), total: total)
    }

    func resume() {
        guard case let .paused(remaining, total) = state else { return }
        begin(remaining, total: total)
    }

    func restart() {
        switch state {
        case let .done(_, total), let .paused(_, total), let .running(_, total): begin(total, total: total)
        case .idle: break
        }
    }

    func stop() { fire?.cancel(); clear?.cancel(); state = .idle }

    /// Seconds left and the fraction elapsed (0…1) at `now`.
    func progress(at now: Date) -> (remaining: TimeInterval, fraction: Double) {
        switch state {
        case .idle: return (0, 0)
        case let .running(end, total): let r = max(0, end.timeIntervalSince(now)); return (r, total > 0 ? 1 - r / total : 1)
        case let .paused(r, total): return (r, total > 0 ? 1 - r / total : 1)
        case .done: return (0, 1)
        }
    }

    private func begin(_ remaining: TimeInterval, total: TimeInterval) {
        fire?.cancel(); clear?.cancel()
        state = .running(end: Date().addingTimeInterval(remaining), total: total)
        fire = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled, let self else { return }
            self.state = .done(at: Date(), total: total)
            self.finished &+= 1
            // "Done" stays in the widget for two minutes, then the timer goes back to its presets.
            self.clear = Task { [weak self] in
                try? await Task.sleep(for: .seconds(120))
                guard !Task.isCancelled, let self, case .done = self.state else { return }
                self.state = .idle
            }
        }
    }
}

/// "24:13", or "1:02:05" past an hour.
func countdown(_ seconds: TimeInterval) -> String {
    let s = Int(seconds.rounded(.up))
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
}
