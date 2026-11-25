import SwiftUI

// The System widget (docs/widget-hub.md §3.9): CPU, memory, disk, network and battery in one tonal card. Tokens only.
// It samples only while it is on screen: `SystemStats` starts and stops with `ticking` and the card's appearance.

struct SystemCard: View {
    @ObservedObject var stats = SystemStats.shared
    let size: WidgetSize
    var ticking = true

    var body: some View {
        let s = stats.snapshot
        let wide = size == .wide
        VStack(alignment: .leading, spacing: Tok.s2) {
            HStack(spacing: Tok.s2) {
                Image(systemName: "cpu").font(Tok.icon).foregroundStyle(Tok.ink2).frame(width: Tok.gutter, height: Tok.gutter)
                Text("System").font(Tok.rowTitle).foregroundStyle(Tok.ink).lineLimit(1)
                Spacer(minLength: Tok.s2)
                if wide { StatusLine(text: stats.about) }
            }
            .frame(height: Tok.gutter)
            if wide {
                HStack(alignment: .top, spacing: Tok.s4) {
                    VStack(alignment: .leading, spacing: Tok.s2) { cpuRow(s); coreBars(s); memRow(s) }
                    VStack(alignment: .leading, spacing: Tok.s2) { diskRow(s); netRow(s); batteryRow(s) }
                }
            } else {
                VStack(alignment: .leading, spacing: Tok.s2) { cpuRow(s); memRow(s); netRow(s); batteryRow(s) }
            }
        }
        .card()
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SystemLogic.spoken(cpu: s.cpu, memUsed: s.memUsed, memTotal: s.memTotal, pressure: s.pressure,
                                               diskFree: s.diskFree, down: s.down, up: s.up, battery: s.battery))
        .onAppear { if ticking { stats.start() } }
        .onChange(of: ticking) { _, on in if on { stats.start() } else { stats.stop() } }
        .onDisappear { stats.stop() }
    }

    private func cpuRow(_ s: SystemStats.Snapshot) -> some View {
        MeterRow(label: "CPU", fraction: s.cpu ?? 0, value: s.cpu.map(SystemLogic.percent) ?? "–", tint: (s.cpu ?? 0) > 0.9 ? Tok.warning : Tok.ink)
    }

    private func memRow(_ s: SystemStats.Snapshot) -> some View {
        let f = s.memTotal == 0 ? 0 : Double(s.memUsed) / Double(s.memTotal)
        return MeterRow(label: "MEM", fraction: f, value: SystemLogic.bytes(Double(s.memUsed)), tint: s.pressure == .normal ? Tok.ink : Tok.warning)
    }

    private func diskRow(_ s: SystemStats.Snapshot) -> some View {
        let f = (s.diskTotal ?? 0) == 0 ? 0 : 1 - Double(s.diskFree ?? 0) / Double(s.diskTotal ?? 1)
        return MeterRow(label: "DISK", fraction: f, value: s.diskFree.map { SystemLogic.bytes(Double($0)) + " free" } ?? "–", tint: f > 0.95 ? Tok.warning : Tok.ink)
    }

    private func netRow(_ s: SystemStats.Snapshot) -> some View {
        HStack(spacing: Tok.s2) {
            Text("NET").font(Tok.status).tracking(Tok.statusTracking).foregroundStyle(Tok.ink3).frame(width: 34, alignment: .leading)
            Text("↓ \(SystemLogic.rateText(s.down))").font(Tok.digits).foregroundStyle(Tok.ink)
            Text("↑ \(SystemLogic.rateText(s.up))").font(Tok.digits).foregroundStyle(Tok.ink2)
            Spacer(minLength: 0)
        }
        .lineLimit(1).minimumScaleFactor(0.8)
    }

    @ViewBuilder private func batteryRow(_ s: SystemStats.Snapshot) -> some View {
        if let b = s.battery {
            MeterRow(label: "BAT", fraction: Double(b.percent) / 100, value: "\(b.percent)%",
                     tint: b.charging ? Tok.live : (b.percent <= 20 && !b.pluggedIn ? Tok.warning : Tok.ink), caption: SystemLogic.batteryStatus(b))
        }
    }

    /// One thin bar per core, the height showing its load; capped at 16 so a big machine still fits.
    @ViewBuilder private func coreBars(_ s: SystemStats.Snapshot) -> some View {
        if !s.cores.isEmpty {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(s.cores.prefix(16).enumerated()), id: \.offset) { _, c in
                    Capsule().fill(Tok.ink.opacity(0.14)).frame(height: 12)
                        .overlay(alignment: .bottom) { Capsule().fill(Tok.ink2).frame(height: max(2, 12 * c)) }
                }
            }
            .frame(height: 12).padding(.leading, 34 + Tok.s2)
        }
    }
}

/// `LABEL ▬▬▬▭▭  value`, with an optional status caption underneath (battery).
private struct MeterRow: View {
    let label: String
    let fraction: Double
    let value: String
    var tint: Color = Tok.ink
    var caption: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Tok.s2) {
                Text(label).font(Tok.status).tracking(Tok.statusTracking).foregroundStyle(Tok.ink3).frame(width: 34, alignment: .leading)
                Capsule().fill(Tok.ink.opacity(0.14)).frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in Capsule().fill(tint).frame(width: g.size.width * min(1, max(0, fraction))) }
                    }
                Text(value).font(Tok.digits).foregroundStyle(Tok.ink).lineLimit(1).minimumScaleFactor(0.8)
                    .frame(minWidth: 56, alignment: .trailing)
            }
            if let caption { StatusLine(text: caption).padding(.leading, 34 + Tok.s2) }
        }
    }
}
