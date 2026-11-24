import SwiftUI

// MARK: - Compact (beside the hardware notch)

struct CompactLeadingView: View {
    // Static on purpose: a repeatForever animation redraws every frame and broke the idle CPU budget (<1%, docs/tech-stack.md §4).
    var body: some View {
        Image(systemName: "figure.climbing")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
    }
}

struct CompactTrailingView: View {
    @ObservedObject var music: NowPlaying
    @ObservedObject var status: SystemStatus
    var body: some View {
        if music.isPlaying {
            EqualizerBars(playing: true).frame(width: 16, height: 12)
        } else if let b = status.battery {
            Text("\(b.percent)%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(b.percent <= 20 && !b.onAC ? .red : .white.opacity(0.85))
        }
    }
}

// MARK: - Expanded

struct ExpandedView: View {
    @ObservedObject var music: NowPlaying
    @ObservedObject var status: SystemStatus
    var shown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header.reveal(shown, delay: 0.00)
            NowPlayingCard(music: music).reveal(shown, delay: 0.04)
            HStack(spacing: 8) {
                WifiChip(status: status)
                BatteryChip(status: status)
                VolumeChip(status: status)
            }
            .reveal(shown, delay: 0.08)
            ShelfPlaceholder().reveal(shown, delay: 0.12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 20)
        .padding(.top, 6)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.climbing")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [.orange, .pink], startPoint: .top, endPoint: .bottom))
            Text("Belay").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            Text("holding the rope").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.45))
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(status.now, format: .dateTime.hour().minute())
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                Text(status.now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

struct NowPlayingCard: View {
    @ObservedObject var music: NowPlaying
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.98, green: 0.45, blue: 0.35), Color(red: 0.55, green: 0.3, blue: 0.95)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                if music.isPlaying { EqualizerBars(playing: true).frame(width: 22, height: 18) }
                else { Image(systemName: "music.note").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white) }
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(music.title ?? "Nothing playing")
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                Text(music.title == nil ? "Play something in Music or Spotify" : [music.artist, music.player?.rawValue].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                ControlButton(symbol: "backward.fill", size: 12) { music.previous() }
                ControlButton(symbol: music.isPlaying ? "pause.fill" : "play.fill", size: 16) { music.playPause() }
                ControlButton(symbol: "forward.fill", size: 12) { music.next() }
            }
            .opacity(music.player == nil ? 0.35 : 1)
        }
        .padding(10)
        .background(Card())
    }
}

struct WifiChip: View {
    @ObservedObject var status: SystemStatus
    var body: some View {
        Chip(symbol: status.wifiOn ? "wifi" : "wifi.slash",
             tint: status.online ? .white : .orange,
             title: status.wifiName ?? (status.wifiOn ? (status.online ? "Wi-Fi" : "No internet") : "Wi-Fi off"),
             detail: status.wifiOn ? String(repeating: "●", count: status.wifiBars) + String(repeating: "○", count: 3 - status.wifiBars) : nil)
    }
}

struct BatteryChip: View {
    @ObservedObject var status: SystemStatus
    var body: some View {
        let b = status.battery
        Chip(symbol: b.map { $0.charging ? "battery.100percent.bolt" : $0.percent > 60 ? "battery.75percent" : $0.percent > 25 ? "battery.50percent" : "battery.25percent" } ?? "powerplug",
             tint: b.map { $0.percent <= 20 && !$0.onAC ? .red : ($0.charging ? .green : .white) } ?? .white,
             title: b.map { "\($0.percent)%" } ?? "Power",
             detail: b.map { $0.charging ? "Charging" : ($0.onAC ? "Plugged in" : "Battery") })
    }
}

struct VolumeChip: View {
    @ObservedObject var status: SystemStatus
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.volume == 0 ? "speaker.slash.fill" : status.volume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.2.fill")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.85)).frame(width: 16)
            Slider(value: Binding(get: { status.volume }, set: { status.setVolume($0) }), in: 0...1)
                .controlSize(.mini).tint(.white)
        }
        .padding(.horizontal, 10).frame(height: 40).frame(maxWidth: .infinity)
        .background(Card())
    }
}

struct ShelfPlaceholder: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down").font(.system(size: 12, weight: .semibold))
            Text("Drop files here to convert · coming soon").font(.system(size: 11, weight: .medium, design: .rounded))
            Spacer()
        }
        .foregroundStyle(.white.opacity(0.4))
        .padding(.horizontal, 12).frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(.white.opacity(0.15)))
    }
}

// MARK: - Building blocks

struct Chip: View {
    let symbol: String; let tint: Color; let title: String; let detail: String?
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint).frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                if let detail { Text(detail).font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.45)).lineLimit(1) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).frame(height: 40).frame(maxWidth: .infinity)
        .background(Card())
    }
}

struct Card: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.white.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.06)))
    }
}

struct ControlButton: View {
    let symbol: String; let size: CGFloat; let action: () -> Void
    @State private var hover = false
    @State private var pressed = false
    var body: some View {
        Button {
            Feel.tap()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { withAnimation(Feel.tile) { pressed = false } }
            action()
        } label: {
            Image(systemName: symbol).font(.system(size: size, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(.white.opacity(hover ? 0.14 : 0)))
                .scaleEffect(pressed ? 0.85 : 1)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
    }
}

struct EqualizerBars: View {
    var playing: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !playing)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    let h = playing ? 0.35 + 0.65 * abs(sin(t * (2.2 + Double(i) * 0.7) + Double(i))) : 0.3
                    Capsule().fill(.white).frame(maxHeight: .infinity).scaleEffect(x: 1, y: h, anchor: .bottom)
                }
            }
        }
    }
}

extension View {
    /// Staggered spring entrance for sections of the expanded notch.
    func reveal(_ shown: Bool, delay: Double) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : -6)
            .scaleEffect(shown ? 1 : 0.98, anchor: .top)
            .animation(Feel.tile.delay(delay), value: shown)
    }
}
