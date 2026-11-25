import Foundation

/// The Stopwatch widget's state holder. In memory only: it survives closing the notch, not quitting Belay.
/// Publishes only on state changes; views read the time from the start date inside a TimelineView.
@MainActor
final class NotchStopwatch: ObservableObject {
    @Published private(set) var state = StopwatchState()

    var isActive: Bool { !state.isReady }
    var isRunning: Bool { state.isRunning }

    func start() { state.start(at: Date()) }
    func pause() { state.pause(at: Date()) }
    func resume() { state.resume(at: Date()) }
    func lap() { state.lap(at: Date()) }
    func reset() { state.reset() }
    func elapsed(at now: Date) -> TimeInterval { state.elapsed(at: now) }

    #if DEBUG
    /// `--demo-stopwatch`: a run that began 12:04 ago with four laps, for screenshots. Never saved (nothing here persists).
    func demo() {
        let now = Date()
        state = StopwatchState()
        state.start(at: now.addingTimeInterval(-724))
        for mark in [95.2, 301.9, 512.45, 640.0] { state.lap(at: now.addingTimeInterval(-724 + mark)) }
    }
    #endif
}
