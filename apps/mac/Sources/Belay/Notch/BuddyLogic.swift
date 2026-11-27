import Foundation

// Buddy display rules (docs/buddies.md §3–§5). Foundation only so the self-test compiles it alone. What a buddy does is
// decided by belayd (ADR 0001); this file only orders and words what the core reports.

/// What a buddy is doing right now, as belayd reports it (`BuddyState` in protocol v1).
enum BuddyRunState: String, Codable, CaseIterable, Sendable {
    case idle, working, waiting, done, error, paused

    /// Lower sorts first: what needs you, then what is broken, then what is running.
    var urgency: Int {
        switch self {
        case .waiting: 0
        case .error: 1
        case .working: 2
        case .done: 3
        case .idle: 4
        case .paused: 5
        }
    }
    var label: String {
        switch self {
        case .idle: "idle"
        case .working: "working"
        case .waiting: "needs you"
        case .done: "done"
        case .error: "stopped"
        case .paused: "paused"
        }
    }
}

enum BuddyLogic {
    /// Most urgent first; ties keep the user's order.
    static func ordered<T>(_ items: [T], state: (T) -> BuddyRunState) -> [T] {
        items.enumerated().sorted {
            let a = state($0.element).urgency, b = state($1.element).urgency
            return a != b ? a < b : $0.offset < $1.offset
        }.map(\.element)
    }

    /// "WORKING · RUNNING TESTS", "NEEDS YOU · OPEN MAIL": the state, then what it is on (the view uppercases).
    static func statusText(_ state: BuddyRunState, detail: String?) -> String {
        guard let detail, !detail.isEmpty else { return state.label }
        return "\(state.label) · \(detail)"
    }

    /// The roster strip shows at most `fit` buddies; the rest collapse into "+n". The selected one is always shown.
    static func strip(count: Int, selected: Int, fit: Int) -> (visible: [Int], more: Int) {
        guard count > fit, fit > 0 else { return (Array(0..<max(count, 0)), 0) }
        var visible = Array(0..<fit)
        if selected >= fit { visible[fit - 1] = selected }
        return (visible, count - fit)
    }

    /// How a thread is cut for each form: compact keeps the last reply, the wide card a few lines, the expanded pane more.
    static func tail<T>(_ lines: [T], columns: Int) -> [T] {
        Array(lines.suffix(columns >= 3 ? 6 : columns == 2 ? 2 : 0))
    }

    /// "in 3 h", "in 12 min", "now": the time until a routine's next run, as the clock says it.
    static func until(_ next: Date?, now: Date) -> String {
        guard let next else { return "on event" }
        let s = Int(next.timeIntervalSince(now))
        if s <= 60 { return "now" }
        if s < 3600 { return "in \(s / 60) min" }
        if s < 86_400 { return "in \(s / 3600) h" }
        return "in \(s / 86_400) d"
    }
}

/// Where a task stands, as belayd reports it (`TaskStatus` in protocol v1). Words for the notch live here.
enum TaskRunState: String, Sendable, CaseIterable {
    case planning, blocked, planOK = "needs-plan-ok", running, needsYou = "needs-you", paused, done, stopped, failed

    var label: String {
        switch self {
        case .planning: "planning"
        case .blocked: "can't start"
        case .planOK: "approve the plan"
        case .running: "working"
        case .needsYou: "needs you"
        case .paused: "paused"
        case .done: "done"
        case .stopped: "stopped"
        case .failed: "failed"
        }
    }
    /// Waiting on you: the plan, a spend or send, or your own hands (a payment).
    var needsYou: Bool { self == .planOK || self == .needsYou }
    var isActive: Bool { self == .running || self == .needsYou || self == .planOK || self == .planning || self == .paused }
    var isFinished: Bool { self == .done || self == .stopped || self == .failed || self == .blocked }
    /// Lower sorts first: what needs you, then what runs, then the rest.
    var urgency: Int {
        switch self {
        case .planOK, .needsYou: 0
        case .running: 1
        case .planning, .paused: 2
        case .blocked, .failed: 3
        case .stopped: 4
        case .done: 5
        }
    }
}

extension BuddyLogic {
    /// "3 of 5 steps" for a task with a plan, else nothing.
    static func progress(done: Int, total: Int) -> String? { total == 0 ? nil : "\(done) of \(total) steps" }

    /// A whole-number amount without a trailing .0, with its currency ("120 USD").
    static func money(_ amount: Double, currency: String?) -> String {
        let n = amount == amount.rounded() ? String(Int(amount)) : String(format: "%.2f", amount)
        return currency.map { "\(n) \($0)" } ?? n
    }

    /// The amount you typed in the limit field: digits and one point, nothing else, positive.
    static func parseLimit(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, t.allSatisfy({ $0.isNumber || $0 == "." }), let v = Double(t), v > 0 else { return nil }
        return v
    }
}
