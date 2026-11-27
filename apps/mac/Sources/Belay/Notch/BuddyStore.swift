import SwiftUI

// What the notch shows of the crew. belayd owns the truth (docs/buddies.md, ADR 0001); the shell holds what the core last
// reported. Until the core is connected, `--buddies-demo` fills this in memory with sample data, like `--calendar-demo`.

struct BuddyEntry: Identifiable, Equatable {
    let id: BuddyID
    var name: String
    var job: String
    var state: BuddyRunState
    var detail: String?
}

struct ChatStep: Equatable, Identifiable {
    let id = UUID()
    var label: String
}

struct ChatLine: Identifiable, Equatable {
    let id = UUID()
    /// nil is you.
    var from: BuddyID?
    var text: String
    var steps: [ChatStep] = []
}

struct RoutineEntry: Identifiable, Equatable {
    let id: String
    var buddy: BuddyID
    var goal: String
    /// "weekdays 08:30" (from the core's `describe`).
    var when: String
    var next: Date?
    var paused: Bool
}

@MainActor
final class BuddyStore: ObservableObject {
    static let shared = BuddyStore()
    @Published private(set) var buddies: [BuddyEntry] = []
    @Published private(set) var routines: [RoutineEntry] = []
    @Published private(set) var threads: [BuddyID: [ChatLine]] = [:]
    @Published var selected: BuddyID?
    @Published var draft = ""
    @Published private(set) var isDemo = false

    var hasBuddies: Bool { !buddies.isEmpty }
    var current: BuddyEntry? { buddies.first { $0.id == selected } ?? buddies.first }
    func thread(_ id: BuddyID) -> [ChatLine] { threads[id] ?? [] }

    func select(_ id: BuddyID) { selected = id }

    /// Your line goes into the thread. Delivering it to the buddy is the core's job; in demo mode nothing answers.
    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let id = current?.id else { return }
        threads[id, default: []].append(ChatLine(from: nil, text: text))
        draft = ""
    }

    func setPaused(_ id: String, _ paused: Bool) {
        guard let i = routines.firstIndex(where: { $0.id == id }) else { return }
        routines[i].paused = paused
    }

    /// `--buddies-demo`: sample crew, thread and routines, in memory only. Nothing is saved or sent anywhere.
    func loadDemo() {
        isDemo = true
        let now = Date()
        buddies = [
            BuddyEntry(id: .pip, name: "pip", job: "errands on your Mac", state: .waiting, detail: "open Mail"),
            BuddyEntry(id: .sprout, name: "sprout", job: "code in your repos", state: .working, detail: "running tests"),
            BuddyEntry(id: .beepo, name: "beepo", job: "routes your asks", state: .idle, detail: nil),
            BuddyEntry(id: .willo, name: "willo", job: "research with sources", state: .done, detail: "4 sources"),
            BuddyEntry(id: .otto, name: "otto", job: "inbox and calendar", state: .idle, detail: nil),
            BuddyEntry(id: .fizz, name: "fizz", job: "music", state: .paused, detail: nil),
        ]
        selected = .beepo
        threads = [
            .beepo: [
                ChatLine(from: nil, text: "willo, find the Bun docs for Unix sockets"),
                ChatLine(from: .beepo, text: "Handing that to willo."),
                ChatLine(from: .willo, text: "Bun.listen takes a unix path. The docs list `unix` next to `hostname`.", steps: [ChatStep(label: "searched the web · 2 s"), ChatStep(label: "read bun.sh/docs · 1 s")]),
                ChatLine(from: nil, text: "pip, open the PR in Safari when sprout is done"),
                ChatLine(from: .beepo, text: "pip is waiting on sprout. It will ask before it opens the PR."),
            ],
            .sprout: [
                ChatLine(from: nil, text: "fix the flaky checkout test"),
                ChatLine(from: .sprout, text: "Found it: a race in the cart reducer. Running the suite again.", steps: [ChatStep(label: "edited cart.ts"), ChatStep(label: "ran bun test · 8 s")]),
            ],
        ]
        routines = [
            RoutineEntry(id: "r1", buddy: .otto, goal: "Summarise my inbox and calendar", when: "weekdays 08:30", next: now.addingTimeInterval(3 * 3600), paused: false),
            RoutineEntry(id: "r2", buddy: .sprout, goal: "Run the tests on main", when: "every 2 hours", next: now.addingTimeInterval(40 * 60), paused: false),
            RoutineEntry(id: "r3", buddy: .willo, goal: "Check Bun release notes", when: "Mon 09:00", next: now.addingTimeInterval(3 * 86_400), paused: false),
            RoutineEntry(id: "r4", buddy: .fizz, goal: "Something calm at 22:00", when: "daily 22:00", next: nil, paused: true),
        ]
    }
}
