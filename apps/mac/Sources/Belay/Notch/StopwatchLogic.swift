import Foundation

// Stopwatch widget logic (docs/widget-hub.md §3.3). Foundation only and clock-injected, so the self-test can drive it.

struct StopwatchState: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case ready
        case running(since: Date, base: TimeInterval)
        case paused(elapsed: TimeInterval)
    }
    private(set) var phase: Phase = .ready
    /// Lap times (each since the previous lap), oldest first.
    private(set) var laps: [TimeInterval] = []
    /// Elapsed time at the last lap mark, so the next lap is measured from it.
    private var lastMark: TimeInterval = 0

    var isRunning: Bool { if case .running = phase { true } else { false } }
    var isReady: Bool { phase == .ready }

    func elapsed(at now: Date) -> TimeInterval {
        switch phase {
        case .ready: 0
        case let .running(since, base): base + max(0, now.timeIntervalSince(since))
        case let .paused(e): e
        }
    }

    mutating func start(at now: Date) { if phase == .ready { phase = .running(since: now, base: 0) } }
    mutating func pause(at now: Date) { if isRunning { phase = .paused(elapsed: elapsed(at: now)) } }
    mutating func resume(at now: Date) { if case let .paused(e) = phase { phase = .running(since: now, base: e) } }
    mutating func reset() { self = StopwatchState() }

    /// Marks a lap while running. Returns false (and does nothing) when it isn't running.
    @discardableResult mutating func lap(at now: Date) -> Bool {
        guard isRunning else { return false }
        let e = elapsed(at: now)
        laps.append(e - lastMark)
        lastMark = e
        return true
    }

    /// The last three laps, newest first, numbered by their place in the run.
    var recentLaps: [(number: Int, time: TimeInterval)] {
        laps.enumerated().reversed().prefix(3).map { ($0.offset + 1, $0.element) }
    }
}

enum StopwatchFormat {
    /// "12:04", or "1:02:05" past an hour (whole seconds, truncated like a watch).
    static func elapsed(_ t: TimeInterval) -> String {
        let s = Int(max(0, t))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }

    /// "0:41.37": laps and the paused value show hundredths.
    static func precise(_ t: TimeInterval) -> String {
        let h = Int((max(0, t) * 100).rounded(.down))
        let sec = h / 100, cs = h % 100
        return sec >= 3600
            ? String(format: "%d:%02d:%02d.%02d", sec / 3600, sec / 60 % 60, sec % 60, cs)
            : String(format: "%d:%02d.%02d", sec / 60, sec % 60, cs)
    }

    /// The closed notch's label: "<1m" or whole minutes.
    static func wing(_ t: TimeInterval) -> String { t < 60 ? "<1m" : "\(Int(t / 60))m" }

    /// "Stopwatch, 12 minutes 4 seconds, running"
    static func spoken(_ t: TimeInterval, running: Bool) -> String {
        let s = Int(max(0, t)), h = s / 3600, m = s / 60 % 60, sec = s % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hour" + (h == 1 ? "" : "s")) }
        if m > 0 { parts.append("\(m) minute" + (m == 1 ? "" : "s")) }
        if sec > 0 || parts.isEmpty { parts.append("\(sec) second" + (sec == 1 ? "" : "s")) }
        return "Stopwatch, \(parts.joined(separator: " ")), \(running ? "running" : "paused")"
    }
}
