import Foundation

// Roll widget logic (docs/widget-hub.md §3.12): a coin, a d6 and a d20. Foundation only, so the self-test compiles it alone.

enum RollMode: Int, CaseIterable, Sendable {
    case coin, d6, d20

    var label: String {
        switch self {
        case .coin: "Coin"
        case .d6: "D6"
        case .d20: "D20"
        }
    }
    var symbol: String {
        switch self {
        case .coin: "circle.circle"
        case .d6: "die.face.5"
        case .d20: "dice"
        }
    }
    /// How many outcomes there are.
    var sides: Int { self == .coin ? 2 : self == .d6 ? 6 : 20 }
    var next: RollMode { Self.allCases[(rawValue + 1) % Self.allCases.count] }
}

enum RollLogic {
    /// An outcome in 0..<sides, uniformly (`Int.random(in:using:)` is unbiased).
    static func roll(_ mode: RollMode, using rng: inout some RandomNumberGenerator) -> Int {
        Int.random(in: 0..<mode.sides, using: &rng)
    }

    /// What an outcome reads as: "Heads" / "Tails", or the face number "1"..."6" / "1"..."20".
    static func text(_ mode: RollMode, _ outcome: Int) -> String {
        mode == .coin ? (outcome == 0 ? "Heads" : "Tails") : String(outcome + 1)
    }

    /// Newest first, at most `limit`.
    static func pushed(_ history: [String], _ result: String, limit: Int = 5) -> [String] {
        Array(([result] + history).prefix(limit))
    }

    /// "Heads, Tails, Heads", for the wide card's history.
    static func historyText(_ history: [String]) -> String { history.joined(separator: " · ") }

    static func spoken(_ mode: RollMode, last: String?) -> String {
        last.map { "\(mode.label) roll: \($0)." } ?? "Roll a \(mode.label.lowercased())."
    }
}
