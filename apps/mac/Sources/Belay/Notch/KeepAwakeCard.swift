import SwiftUI

// The Keep awake widget (docs/widget-hub.md §3.10): one click keeps the Mac and its display awake for a chosen length.
// Built on the shared WidgetCard, so it is a tile or a wide row like the timer and stopwatch. Nothing ticks.

struct KeepAwakeCard: View {
    @ObservedObject var awake = KeepAwake.shared
    let size: WidgetSize

    var body: some View {
        let is24 = ClockLogic.system24Hour
        let status = awake.isOn ? KeepAwakeLogic.status(endsAt: awake.endsAt, is24: is24) : "Off"
        WidgetCard(size: size, status: status, live: awake.isOn) {
            Image(systemName: awake.isOn ? "cup.and.saucer.fill" : "cup.and.saucer").font(Tok.icon)
                .foregroundStyle(awake.isOn ? Tok.live : Tok.ink2)
        } title: {
            Text("Keep awake").font(Tok.rowTitle).foregroundStyle(Tok.ink)
        } actions: {
            if !awake.isOn {
                Chip(title: awake.length.label, label: "Length \(awake.length.label), change") { awake.cycleLength() }
            }
            IconButton(symbol: awake.isOn ? "stop.fill" : "play.fill", label: awake.isOn ? "Stop keeping awake" : "Keep awake for \(awake.length.label)") { awake.toggle() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(KeepAwakeLogic.spoken(active: awake.isOn, endsAt: awake.endsAt, length: awake.length, is24: is24))
    }
}
