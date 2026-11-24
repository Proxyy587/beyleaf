import AppKit
import SwiftUI

// Layout and type follow docs/design.md: rows of [icon] title / status line … value. Tokens only.

// MARK: - Compact wings (beside the hardware notch)

struct WingView: View {
    let wing: AppSettings.Wing
    let side: HorizontalEdge
    @ObservedObject var music: NowPlaying
    @ObservedObject var status: SystemStatus
    @ObservedObject var shots: Screenshots
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        Group {
            if side == .trailing, shots.justCopied {
                Image(systemName: "checkmark").font(Tok.icon).foregroundStyle(Tok.live)
                    .accessibilityLabel("Screenshot copied")
            } else if side == .trailing, settings.equalizerWhilePlaying, music.isPlaying {
                Equalizer().frame(width: 14, height: 11)
            } else {
                content
            }
        }
        .blurSwap(on: WingState(copied: shots.justCopied, playing: settings.equalizerWhilePlaying && music.isPlaying, wing: wing))
    }

    @ViewBuilder private var content: some View {
        switch wing {
        case .climber:
            Image(systemName: "figure.climbing").font(Tok.icon).foregroundStyle(Tok.ink2)
        case .battery:
            if let b = status.battery {
                Text("\(b.percent)%").font(Tok.digits).foregroundStyle(batteryInk(b))
            }
        case .time:
            Text(status.now, format: .dateTime.hour().minute()).font(Tok.digits).foregroundStyle(Tok.ink2)
        case .none:
            EmptyView()
        }
    }
}

/// Identity of what a wing is showing, so changes blur-swap instead of popping.
private struct WingState: Hashable { let copied: Bool; let playing: Bool; let wing: AppSettings.Wing }

@MainActor func batteryInk(_ b: SystemStatus.Battery) -> Color {
    if b.onAC { return Tok.ink2 }
    return b.percent < 10 ? Tok.danger : b.percent <= 20 ? Tok.warning : Tok.ink2
}

// MARK: - Open panel

struct ExpandedView: View {
    @ObservedObject var music: NowPlaying
    @ObservedObject var status: SystemStatus
    @ObservedObject var shots: Screenshots
    var shown: Bool
    var openSettings: () -> Void

    var body: some View {
        let rows = AppSettings.shared.theme.rows.filter(\.visible).map(\.kind)
        VStack(alignment: .leading, spacing: Tok.s1) {
            header
                .padding(.bottom, Tok.s2)
                .blurReveal(shown, delay: 0.03)
            ForEach(Array(rows.enumerated()), id: \.element) { index, kind in
                row(kind).blurReveal(shown, delay: 0.05 + Double(index) * 0.025)
            }
        }
        .padding(.horizontal, Tok.s4)
        .padding(.top, Tok.s2)
        .padding(.bottom, Tok.s4)
    }

    @ViewBuilder private func row(_ kind: Theme.RowKind) -> some View {
        switch kind {
        case .nowPlaying: NowPlayingRow(music: music)
        case .wifi: WifiRow(status: status)
        case .battery: BatteryRow(status: status)
        case .volume: VolumeRow(status: status)
        case .screenshot: if let c = shots.lastCopied { ScreenshotRow(copied: c, shots: shots) }
        }
    }

    private var header: some View {
        HStack(spacing: Tok.s2) {
            Image(systemName: "figure.climbing").font(Tok.icon).foregroundStyle(Tok.ink)
                .frame(width: Tok.gutter)
            Text("Belay").font(Tok.title).foregroundStyle(Tok.ink)
            Spacer()
            Text(status.now, format: .dateTime.weekday(.abbreviated).hour().minute())
                .font(Tok.digits).foregroundStyle(Tok.ink2)
            IconButton(symbol: "gearshape", label: "Open Settings", action: openSettings)
        }
    }
}

/// A notch row: [icon] title over status line … trailing.
struct Row<Leading: View, Trailing: View>: View {
    let title: String
    let status: String
    var live = false
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Tok.s3) {
            leading.frame(width: Tok.gutter, height: Tok.gutter)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Tok.rowTitle).foregroundStyle(Tok.ink).lineLimit(1).truncationMode(.tail)
                    .blurSwap(on: title)
                StatusLine(text: status, live: live)
            }
            Spacer(minLength: Tok.s2)
            trailing
        }
        .frame(height: Tok.rowHeight)
    }
}

struct NowPlayingRow: View {
    @ObservedObject var music: NowPlaying
    var body: some View {
        Row(title: music.title ?? "Not playing",
            status: music.title == nil
                ? (music.player == nil ? "Idle" : "Paused · \(music.player!.rawValue)")
                : [music.isPlaying ? "Playing" : "Paused", music.artist, music.player?.rawValue].compactMap { $0 }.joined(separator: " · "),
            live: music.isPlaying) {
            AppIcon(bundleID: music.player.map { $0 == .spotify ? "com.spotify.client" : "com.apple.Music" }, fallback: "music.note")
        } trailing: {
            HStack(spacing: 0) {
                IconButton(symbol: "backward.fill", label: "Previous track") { music.previous() }
                IconButton(symbol: music.isPlaying ? "pause.fill" : "play.fill", label: music.isPlaying ? "Pause" : "Play") { music.playPause() }
                IconButton(symbol: "forward.fill", label: "Next track") { music.next() }
            }
            .disabled(music.player == nil)
            .opacity(music.player == nil ? 0.4 : 1)
        }
    }
}

struct WifiRow: View {
    @ObservedObject var status: SystemStatus
    var body: some View {
        let strength = ["", "Weak", "Fair", "Strong"][max(0, min(3, status.wifiBars))]
        Row(title: status.wifiOn ? (status.wifiName ?? "Wi-Fi") : "Wi-Fi off",
            status: !status.wifiOn ? "Off" : status.online ? "Connected · \(strength)" : "No internet",
            live: status.wifiOn && status.online) {
            Image(systemName: status.wifiOn ? "wifi" : "wifi.slash", variableValue: Double(status.wifiBars) / 3)
                .font(Tok.icon).foregroundStyle(status.wifiOn && !status.online ? Tok.warning : Tok.ink)
        } trailing: { EmptyView() }
    }
}

struct BatteryRow: View {
    @ObservedObject var status: SystemStatus
    var body: some View {
        if let b = status.battery {
            Row(title: "Battery", status: b.charging ? "Charging" : b.onAC ? "Plugged in" : status.timeLeft.map { "On battery · \($0) left" } ?? "On battery") {
                Image(systemName: b.charging ? "battery.100percent.bolt" : b.percent > 60 ? "battery.75percent" : b.percent > 25 ? "battery.50percent" : "battery.25percent")
                    .font(Tok.icon).foregroundStyle(batteryInk(b) == Tok.ink2 ? Tok.ink : batteryInk(b))
            } trailing: {
                Text("\(b.percent)%").font(Tok.digits).foregroundStyle(Tok.ink2)
            }
        }
    }
}

struct VolumeRow: View {
    @ObservedObject var status: SystemStatus
    var body: some View {
        HStack(spacing: Tok.s3) {
            Image(systemName: "speaker.wave.3.fill", variableValue: status.volume)
                .font(Tok.icon).foregroundStyle(Tok.ink).frame(width: Tok.gutter)
            Slider(value: Binding(get: { status.volume }, set: { status.setVolume($0) }), in: 0...1)
                .controlSize(.small)
                .tint(Tok.accent)
                .accessibilityLabel("Volume")
            Text("\(Int((status.volume * 100).rounded()))").font(Tok.digits).foregroundStyle(Tok.ink2)
                .frame(width: 28, alignment: .trailing)
        }
        .frame(height: Tok.rowHeight)
    }
}

struct ScreenshotRow: View {
    let copied: Screenshots.Copied
    @ObservedObject var shots: Screenshots
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            Row(title: "Screenshot copied",
                status: "\(relative(copied.at, now: ctx.date)) · \(ByteCountFormatter.string(fromByteCount: Int64(copied.bytes), countStyle: .file))") {
                Thumbnail(url: copied.url)
            } trailing: {
                HStack(spacing: 0) {
                    IconButton(symbol: "doc.on.doc", label: "Copy again") { shots.copyAgain() }
                    IconButton(symbol: "folder", label: "Show in Finder") { shots.reveal() }
                }
            }
        }
    }
    private func relative(_ d: Date, now: Date) -> String {
        let s = Int(now.timeIntervalSince(d))
        return s < 60 ? "Just now" : s < 3600 ? "\(s / 60) min ago" : "\(s / 3600) h ago"
    }
}

// MARK: - Building blocks

struct IconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @State private var hover = false
    @State private var pressed = false

    var body: some View {
        Button {
            Tok.haptic()
            action()
        } label: {
            Image(systemName: symbol)
                .font(Tok.buttonIcon)
                .foregroundStyle(Tok.ink)
                .frame(width: Tok.button, height: Tok.button)
                .background(Circle().fill(pressed ? Tok.pressedFill : hover ? Tok.hoverFill : .clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .onHover { h in withAnimation(Tok.hover) { hover = h } }
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if !pressed { withAnimation(Tok.hover) { pressed = true } } }
            .onEnded { _ in withAnimation(Tok.hover) { pressed = false } })
    }
}

/// A real app's icon (the player, the terminal); falls back to a bare SF Symbol.
struct AppIcon: View {
    let bundleID: String?
    let fallback: String
    var body: some View {
        if let id = bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().interpolation(.high)
                .frame(width: Tok.gutter, height: Tok.gutter)
        } else {
            Image(systemName: fallback).font(Tok.icon).foregroundStyle(Tok.ink)
        }
    }
}

struct Thumbnail: View {
    let url: URL
    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                .frame(width: Tok.gutter, height: Tok.gutter)
                .clipShape(RoundedRectangle(cornerRadius: Tok.rThumb / 2, style: .continuous))
        } else {
            Image(systemName: "camera.viewfinder").font(Tok.icon).foregroundStyle(Tok.ink)
        }
    }
}

/// Live only while audio plays (the one allowed loop, docs/design.md §7). Static under reduced motion.
struct Equalizer: View {
    var body: some View {
        if Tok.reduceMotion {
            Image(systemName: "waveform").font(Tok.icon).foregroundStyle(Tok.live)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule().fill(Tok.live)
                            .frame(maxHeight: .infinity)
                            .scaleEffect(x: 1, y: 0.3 + 0.7 * abs(sin(t * (2.0 + Double(i) * 0.6) + Double(i))), anchor: .bottom)
                    }
                }
            }
        }
    }
}
