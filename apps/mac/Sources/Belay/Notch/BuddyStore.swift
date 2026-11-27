import Combine
import SwiftUI

// What the notch shows of the crew. belayd owns the truth (docs/buddies.md, ADR 0001); the shell holds what the core last
// reported. Until the core is connected, `--buddies-demo` fills this in memory with sample data, like `--calendar-demo`.

struct BuddyEntry: Identifiable, Equatable {
    /// The character. Each is on the crew at most once, so it is also the buddy's identity in the shell.
    let id: BuddyID
    /// The core's id for this buddy (the name as a slug); what requests carry.
    var key: String = ""
    /// You, or the buddy that made this one (never made on its own, docs/buddies.md §2a).
    var madeBy: String = "you"
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

struct TaskStepEntry: Identifiable, Equatable {
    let id: String
    var label: String
    var kind: String
    var status: String
}

struct TaskEntry: Identifiable, Equatable {
    let id: String
    var buddy: BuddyID
    var goal: String
    var state: TaskRunState
    var steps: [TaskStepEntry]
    var moved: Double
    var maxMoney: Double?
    var currency: String?
    var note: String?

    /// The step the task is on, or waiting at.
    var current: TaskStepEntry? { steps.first { $0.status == "doing" } }
    var done: Int { steps.filter { $0.status == "done" || $0.status == "skipped" }.count }
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
    /// beepo is always on the crew: it is how you reach the rest. Every other buddy exists because you (or a buddy you made)
    /// made it; none appears on its own.
    @Published private(set) var buddies: [BuddyEntry] = [BuddyStore.beepo]
    @Published private(set) var routines: [RoutineEntry] = []
    @Published private(set) var threads: [BuddyID: [ChatLine]] = [:]
    @Published private(set) var tasks: [TaskEntry] = []
    @Published var selected: BuddyID? = .beepo
    @Published var draft = ""
    /// Why the last attempt was refused, in the core's words (a full crew, a limit): shown until the next try.
    @Published var notice: String?
    @Published private(set) var isDemo = false
    private var link: AnyCancellable?
    private var refusalLink: AnyCancellable?
    private var taskLink: AnyCancellable?
    private var routineLink: AnyCancellable?

    static let beepo = BuddyEntry(id: .beepo, key: "beepo", name: "beepo", job: "routes what you ask", state: .idle, detail: nil)
    static let maxBuddies = 8

    var hasBuddies: Bool { !buddies.isEmpty }
    var current: BuddyEntry? { buddies.first { $0.id == selected } ?? buddies.first }
    func thread(_ id: BuddyID) -> [ChatLine] { threads[id] ?? [] }
    /// Characters not yet on the crew, in catalogue order: the faces the new-buddy form offers.
    var freeCharacters: [BuddyID] { BuddyID.allCases.filter { c in !buddies.contains { $0.id == c } } }
    var canAddBuddy: Bool { buddies.count < Self.maxBuddies }
    var activeTasks: [TaskEntry] { tasks.filter { $0.state.isActive } }
    var needsYouCount: Int { tasks.filter { $0.state.needsYou }.count }
    var taskSummary: String {
        let n = needsYouCount
        if n > 0 { return "\(n) need\(n == 1 ? "s" : "") you" }
        let a = activeTasks.count
        return a == 0 ? "none running" : "\(a) running"
    }

    func select(_ id: BuddyID) { selected = id }

    /// Follows what the core reports: the roster, the tasks and its refusals. The core decides, the shell shows.
    func attach(_ core: CoreLink) {
        link = core.$buddies.sink { [weak self] list in
            guard let self, !self.isDemo, !list.isEmpty else { return }
            self.apply(roster: list)
        }
        refusalLink = core.$refusal.sink { [weak self] why in
            guard let self, let why else { return }
            self.notice = why
            core.refusal = nil
        }
        routineLink = core.$routines.sink { [weak self] list in
            guard let self, !self.isDemo else { return }
            self.routines = list.compactMap { r in
                guard let b = self.buddies.first(where: { $0.key == r.buddy }) else { return nil }
                return RoutineEntry(id: r.id, buddy: b.id, goal: r.goal, when: r.when, next: r.next, paused: r.paused)
            }
        }
        taskLink = core.$tasks.sink { [weak self] list in
            guard let self, !self.isDemo else { return }
            self.tasks = list.compactMap { self.entry($0) }
        }
    }

    private func apply(roster: [BuddyDTO]) {
        let old = Dictionary(uniqueKeysWithValues: buddies.map { ($0.id, $0) })
        buddies = roster.compactMap { b in
            guard let id = BuddyID(rawValue: b.sprite) else { return nil }
            return BuddyEntry(id: id, key: b.id, madeBy: b.createdBy, name: b.name, job: b.job, state: old[id]?.state ?? .idle, detail: old[id]?.detail)
        }
        if let s = selected, !buddies.contains(where: { $0.id == s }) { selected = buddies.first?.id }
    }

    private func entry(_ t: TaskDTO) -> TaskEntry? {
        guard let b = buddies.first(where: { $0.key == t.buddy }) else { return nil }
        return TaskEntry(id: t.id, buddy: b.id, goal: t.goal, state: TaskRunState(rawValue: t.status) ?? .failed,
                         steps: t.steps.map { TaskStepEntry(id: $0.id, label: $0.label, kind: $0.kind, status: $0.status) },
                         moved: t.moved, maxMoney: t.limits.maxMoney, currency: t.limits.currency, note: t.note)
    }

    /// Makes a buddy. The core checks the rules (names, the crew's size, one of each character) and answers with the roster.
    func create(name: String, job: String, character: BuddyID, reach: [String]) {
        notice = nil
        let clean = name.trimmingCharacters(in: .whitespaces)
        if isDemo {
            guard canAddBuddy, !clean.isEmpty else { return }
            buddies.append(BuddyEntry(id: character, key: clean.lowercased(), name: clean, job: job, state: .idle, detail: nil))
            selected = character
            return
        }
        CoreLink.shared.createBuddy(name: clean, sprite: character.rawValue, job: job, tiers: reach)
        selected = character
    }

    func remove(_ id: BuddyID) {
        guard let b = buddies.first(where: { $0.id == id }), b.id != .beepo else { return }
        if isDemo { buddies.removeAll { $0.id == id }; if selected == id { selected = .beepo } }
        else { CoreLink.shared.removeBuddy(b.key) }
    }

    /// Your line goes into the thread. Delivering it to a buddy's engine is the runtime's job, which isn't built yet: until it
    /// is, the buddy says so instead of pretending.
    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let id = current?.id else { return }
        threads[id, default: []].append(ChatLine(from: nil, text: text))
        draft = ""
        if !isDemo {
            threads[id, default: []].append(ChatLine(from: id, text: "I can't answer yet: the engine runtime isn't built. I kept your message."))
        }
    }

    /// Hands the goal to the core as a task. Nothing runs until the plan comes back and you approve it.
    func startTask(goal: String, limit: Double?) {
        let text = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let b = current else { return }
        notice = nil
        if isDemo {
            tasks.insert(TaskEntry(id: "demo\(tasks.count)", buddy: b.id, goal: text, state: .planning, steps: [], moved: 0, maxMoney: limit, currency: nil,
                                   note: "Demo: nothing plans or runs here."), at: 0)
        } else {
            CoreLink.shared.createTask(buddy: b.key, goal: text, maxMoney: limit)
        }
    }

    /// approve, deny, stop. The core moves the task on; in the demo the card just records the press.
    func act(_ id: String, _ action: String) {
        if isDemo {
            guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
            if action == "stop" { tasks[i].state = .stopped; tasks[i].note = "You stopped it." }
            if action == "deny" { tasks[i].state = .stopped; tasks[i].note = "You said no." }
            if action == "approve" { tasks[i].state = .running; tasks[i].note = nil }
        } else {
            CoreLink.shared.taskAction(id, action)
        }
    }

    func setPaused(_ id: String, _ paused: Bool) {
        if isDemo, let i = routines.firstIndex(where: { $0.id == id }) { routines[i].paused = paused }
        else { CoreLink.shared.pauseRoutine(id, paused: paused) }
    }

    func removeRoutine(_ id: String) {
        if isDemo { routines.removeAll { $0.id == id } } else { CoreLink.shared.removeRoutine(id) }
    }

    /// Schedules a goal for the buddy on screen. When its time comes the core makes a task, which waits for your OK to its plan.
    func schedule(goal: String, every: RoutineRepeat, time: String) {
        let text = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let b = current else { return }
        notice = nil
        if isDemo {
            routines.append(RoutineEntry(id: "demo-r\(routines.count + 1)", buddy: b.id, goal: text,
                                         when: every == .hourly ? "every hour" : "\(every == .daily ? "daily" : "weekdays") \(time)", next: nil, paused: false))
        } else {
            CoreLink.shared.createRoutine(buddy: b.key, goal: text, schedule: every.schedule(time: time))
        }
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
        buddies[buddies.firstIndex { $0.id == .fizz }!].madeBy = "sprout"
        tasks = [
            TaskEntry(id: "d1", buddy: .pip, goal: "Open my browser and play something to focus", state: .running, steps: [
                TaskStepEntry(id: "1", label: "Open the browser", kind: "mac", status: "done"),
                TaskStepEntry(id: "2", label: "Search for a focus playlist", kind: "browse", status: "done"),
                TaskStepEntry(id: "3", label: "Press play", kind: "browse", status: "doing"),
            ], moved: 0, maxMoney: nil, currency: nil, note: nil),
            TaskEntry(id: "d2", buddy: .otto, goal: "Book a flight to Mumbai on Friday", state: .needsYou, steps: [
                TaskStepEntry(id: "1", label: "Search flights for Friday", kind: "browse", status: "done"),
                TaskStepEntry(id: "2", label: "Hold the 09:10 fare", kind: "spend", status: "done"),
                TaskStepEntry(id: "3", label: "Pay for the ticket", kind: "payment", status: "doing"),
            ], moved: 120, maxMoney: 150, currency: "USD", note: "You pay. Belay never types card or bank details; the page is yours."),
            TaskEntry(id: "d3", buddy: .beepo, goal: "Start trading with my money until it reaches 10,000", state: .blocked, steps: [],
                      moved: 0, maxMoney: 500, currency: "USD", note: "Trading isn't switched on: it needs a broker connection and a legal check first. Nothing was started."),
        ]
        routines = [
            RoutineEntry(id: "r1", buddy: .otto, goal: "Summarise my inbox and calendar", when: "weekdays 08:30", next: now.addingTimeInterval(3 * 3600), paused: false),
            RoutineEntry(id: "r2", buddy: .sprout, goal: "Run the tests on main", when: "every 2 hours", next: now.addingTimeInterval(40 * 60), paused: false),
            RoutineEntry(id: "r3", buddy: .willo, goal: "Check Bun release notes", when: "Mon 09:00", next: now.addingTimeInterval(3 * 86_400), paused: false),
            RoutineEntry(id: "r4", buddy: .fizz, goal: "Something calm at 22:00", when: "daily 22:00", next: nil, paused: true),
        ]
    }
}
