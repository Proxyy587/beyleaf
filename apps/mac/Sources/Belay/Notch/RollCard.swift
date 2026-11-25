import SwiftUI

// The Roll widget (docs/widget-hub.md §3.12): flip a coin or roll a die from the notch. Nothing ticks; a click is the only input.

@MainActor
final class Roller: ObservableObject {
    static let shared = Roller()
    @Published var mode = RollMode.coin
    @Published private(set) var last: String?
    @Published private(set) var history: [String] = []
    private init() {}

    func roll() {
        var rng = SystemRandomNumberGenerator()
        let r = RollLogic.text(mode, RollLogic.roll(mode, using: &rng))
        last = r
        history = RollLogic.pushed(history, r)
    }

    /// Changing what you roll clears the last result, so a "4" never sits under "Coin".
    func cycleMode() { mode = mode.next; last = nil; history = [] }
}

struct RollCard: View {
    @ObservedObject var roller = Roller.shared
    let size: WidgetSize

    var body: some View {
        WidgetCard(size: size, status: roller.last == nil ? "" : roller.mode.label) {
            Image(systemName: roller.mode.symbol).font(Tok.icon).foregroundStyle(Tok.ink2)
        } title: {
            if let last = roller.last {
                Text(last).font(Tok.font(15, .semibold, mono: true)).foregroundStyle(Tok.ink).blurSwap(on: last + String(roller.history.count))
            } else {
                Text("Roll").font(Tok.rowTitle).foregroundStyle(Tok.ink)
            }
        } actions: {
            if size == .wide, roller.history.count > 1 {
                Text(RollLogic.historyText(Array(roller.history.dropFirst())))
                    .font(Tok.status).foregroundStyle(Tok.ink3).lineLimit(1).truncationMode(.tail)
                    .padding(.trailing, Tok.s2)
            }
            Chip(title: roller.mode.label, label: "Rolling \(roller.mode.label), change") { roller.cycleMode() }
            IconButton(symbol: "arrow.triangle.2.circlepath", label: roller.mode == .coin ? "Flip the coin" : "Roll the \(roller.mode.label)") { roller.roll() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(RollLogic.spoken(roller.mode, last: roller.last))
    }
}
