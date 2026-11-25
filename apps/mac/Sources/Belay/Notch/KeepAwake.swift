import Foundation
import IOKit.pwr_mgt

/// Holds one IOKit power assertion so the Mac (and its display) doesn't idle-sleep: the same thing `caffeinate -d` does,
/// through the public `IOPMAssertionCreateWithName`. No permission, no network, nothing runs while it's idle. It starts
/// only on a click and releases when you stop it, when the length ends (one scheduled wake-up, no ticking), or when Belay quits
/// (the system drops a process's assertions with it).
@MainActor
final class KeepAwake: ObservableObject {
    static let shared = KeepAwake()

    @Published private(set) var endsAt: Date?
    @Published private(set) var isOn = false
    /// The length the next start uses. Remembered for the session.
    @Published var length = AwakeLength.h1

    private var assertion: IOPMAssertionID = 0
    private var offItem: DispatchWorkItem?
    private init() {}

    func start() {
        stop()
        var id: IOPMAssertionID = 0
        let r = IOPMAssertionCreateWithName("PreventUserIdleDisplaySleep" as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                            "Belay: keep awake (user started it)" as CFString, &id)
        guard r == kIOReturnSuccess else { return }
        assertion = id
        isOn = true
        endsAt = length.end(from: Date())
        if let endsAt {
            let item = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.stop() } }
            offItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, endsAt.timeIntervalSinceNow), execute: item)
        }
    }

    func stop() {
        offItem?.cancel(); offItem = nil
        if assertion != 0 { IOPMAssertionRelease(assertion); assertion = 0 }
        isOn = false; endsAt = nil
    }

    func toggle() { isOn ? stop() : start() }
    func cycleLength() { length = length.next }
}
