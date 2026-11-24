import AppKit
import Combine
import SwiftUI

/// Live activities for the closed notch (Dynamic Island style): music while it plays, and short system alerts.
/// Transient alerts take over for a moment, then the persistent one (music) comes back.
/// Today the shell decides these from system events; once belayd exists, agent activities arrive over protocol v1.
enum NotchActivity: Hashable {
    case nowPlaying
    case copied
    case charging(Int)
    case lowBattery(Int)
    case wifi(online: Bool)

    /// Width of each wing beside the camera for this activity.
    var wingWidth: CGFloat {
        switch self {
        case .nowPlaying, .copied: 44
        case .charging, .lowBattery: 52
        case .wifi: 72
        }
    }
}

@MainActor
final class ActivityCenter: ObservableObject {
    @Published private(set) var current: NotchActivity?
    /// Bumped when an activity starts or a new track begins, so the shape can play its jelly spring.
    @Published private(set) var pulse = 0

    private let music: NowPlaying
    private let status: SystemStatus
    private let shots: Screenshots
    private let settings = AppSettings.shared
    private var transient: NotchActivity?
    private var transientTask: Task<Void, Never>?
    private var briefMusicUntil: Date?
    private var subs: Set<AnyCancellable> = []
    private var lastBattery: SystemStatus.Battery?
    private var lastOnline: Bool?

    init(music: NowPlaying, status: SystemStatus, shots: Screenshots) {
        self.music = music; self.status = status; self.shots = shots
        music.$trackChange.dropFirst().sink { [weak self] _ in DispatchQueue.main.async { self?.newTrack() } }.store(in: &subs)
        music.$isPlaying.sink { [weak self] _ in DispatchQueue.main.async { self?.resolve() } }.store(in: &subs)
        shots.$justCopied.sink { [weak self] on in DispatchQueue.main.async { if on { self?.flash(.copied, for: 2) } } }.store(in: &subs)
        status.$battery.sink { [weak self] b in DispatchQueue.main.async { self?.battery(b) } }.store(in: &subs)
        status.$online.sink { [weak self] o in DispatchQueue.main.async { self?.network(o) } }.store(in: &subs)
        settings.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.resolve() } }.store(in: &subs)
    }

    private func newTrack() {
        if settings.musicActivity == .brief { briefMusicUntil = Date().addingTimeInterval(4)
            Task { try? await Task.sleep(for: .seconds(4.1)); self.resolve() } }
        pulse &+= 1
        resolve()
    }

    private func battery(_ b: SystemStatus.Battery?) {
        defer { lastBattery = b }
        guard let b, let old = lastBattery else { return }
        if settings.alertCharging, b.onAC, !old.onAC { flash(.charging(b.percent), for: 2.5) }
        if settings.alertLowBattery, !b.onAC, (b.percent <= 20 && old.percent > 20) || (b.percent <= 10 && old.percent > 10) {
            flash(.lowBattery(b.percent), for: 4)
        }
    }

    private func network(_ online: Bool) {
        defer { lastOnline = online }
        guard settings.alertWifi, let old = lastOnline, old != online else { return }
        flash(.wifi(online: online), for: 2.5)
    }

    func flash(_ activity: NotchActivity, for seconds: Double) {
        transient = activity
        pulse &+= 1
        resolve()
        transientTask?.cancel()
        transientTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.transient = nil
            self?.resolve()
        }
    }

    private func resolve() {
        let musicOn: Bool = {
            guard music.isPlaying else { return false }
            switch settings.musicActivity {
            case .keep: return true
            case .brief: return (briefMusicUntil ?? .distantPast) > Date()
            case .off: return false
            }
        }()
        let next = transient ?? (musicOn ? .nowPlaying : nil)
        if next != current { current = next }
    }
}

/// What a wing shows for an activity.
struct ActivityWing: View {
    let activity: NotchActivity
    let side: HorizontalEdge
    @ObservedObject var music: NowPlaying
    @ObservedObject var shots: Screenshots
    @ObservedObject var beat: MusicBeat

    var body: some View {
        Group {
            switch (activity, side) {
            case (.nowPlaying, .leading):
                Artwork(image: music.artwork, size: 22)
            case (.nowPlaying, .trailing):
                if music.isPlaying { BeatBars(beat: beat).frame(width: 16, height: 12) }
                else { Image(systemName: "pause.fill").font(Tok.icon).foregroundStyle(Tok.ink2) }
            case (.copied, .leading):
                if let c = shots.lastCopied { Thumbnail(url: c.url) } else { Image(systemName: "camera.viewfinder").font(Tok.icon).foregroundStyle(Tok.ink) }
            case (.copied, .trailing):
                Image(systemName: "checkmark").font(Tok.icon).foregroundStyle(Tok.live)
            case (.charging, .leading):
                Image(systemName: "bolt.fill").font(Tok.icon).foregroundStyle(Tok.live)
            case (.charging(let p), .trailing):
                Text("\(p)%").font(Tok.digits).foregroundStyle(Tok.live)
            case (.lowBattery(let p), .leading):
                Image(systemName: "battery.25percent").font(Tok.icon).foregroundStyle(p <= 10 ? Tok.danger : Tok.warning)
            case (.lowBattery(let p), .trailing):
                Text("\(p)%").font(Tok.digits).foregroundStyle(p <= 10 ? Tok.danger : Tok.warning)
            case (.wifi(let online), .leading):
                Image(systemName: online ? "wifi" : "wifi.slash").font(Tok.icon).foregroundStyle(online ? Tok.live : Tok.warning)
            case (.wifi(let online), .trailing):
                StatusLine(text: online ? "Online" : "Offline", live: online)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Album art with a fallback glyph (art is content, so it may have a plate; docs/design.md §2).
struct Artwork: View {
    let image: NSImage?
    let size: CGFloat
    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Tok.raised
                Image(systemName: "music.note").font(.system(size: size * 0.45, weight: .medium)).foregroundStyle(Tok.ink2)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(4, size * 0.22), style: .continuous))
        .blurSwap(on: image.map { ObjectIdentifier($0) })
    }
}
