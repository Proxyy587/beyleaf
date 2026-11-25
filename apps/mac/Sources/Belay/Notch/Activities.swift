import AppKit
import Combine
import SwiftUI

/// Live activities for the closed notch (Dynamic Island style): music while it plays, and short system alerts.
/// Transient alerts take over for a moment, then the persistent one (music) comes back.
/// Today the shell decides these from system events; once belayd exists, agent activities arrive over protocol v1.
enum NotchActivity: Hashable {
    case nowPlaying
    case copied
    case lowBattery(Int)
    case wifi(online: Bool)
    case timer
    case timerDone

    /// Width of each wing beside the camera for this activity.
    var wingWidth: CGFloat {
        switch self {
        case .nowPlaying, .copied: 44
        case .lowBattery, .timer: 52
        case .wifi, .timerDone: 72
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
    private let timer: NotchTimer
    private let settings = AppSettings.shared
    private var transient: NotchActivity?
    private var transientTask: Task<Void, Never>?
    private var briefMusicUntil: Date?
    private var subs: Set<AnyCancellable> = []
    private var lastBattery: SystemStatus.Battery?
    private var lastOnline: Bool?

    init(music: NowPlaying, status: SystemStatus, shots: Screenshots, timer: NotchTimer) {
        self.music = music; self.status = status; self.shots = shots; self.timer = timer
        timer.$state.sink { [weak self] _ in DispatchQueue.main.async { self?.resolve() } }.store(in: &subs)
        timer.$finished.dropFirst().sink { [weak self] _ in DispatchQueue.main.async { self?.timerDone() } }.store(in: &subs)
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
        if settings.alertLowBattery, !b.onAC, (b.percent <= 20 && old.percent > 20) || (b.percent <= 10 && old.percent > 10) {
            flash(.lowBattery(b.percent), for: 4)
        }
    }

    private func network(_ online: Bool) {
        defer { lastOnline = online }
        guard settings.alertWifi, let old = lastOnline, old != online else { return }
        flash(.wifi(online: online), for: 2.5)
    }

    private func timerDone() {
        guard settings.timerActivity else { return }
        Tok.haptic(.levelChange)
        flash(.timerDone, for: 4)
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
        // Music outranks a running timer; hovering shows both.
        let timerOn = settings.timerActivity && timer.isRunning
        let next = transient ?? (musicOn ? .nowPlaying : timerOn ? .timer : nil)
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
    @ObservedObject var timer: NotchTimer

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
            case (.lowBattery(let p), .leading):
                Image(systemName: "battery.25percent").font(Tok.icon).foregroundStyle(p <= 10 ? Tok.danger : Tok.warning)
            case (.lowBattery(let p), .trailing):
                Text("\(p)%").font(Tok.digits).foregroundStyle(p <= 10 ? Tok.danger : Tok.warning)
            case (.wifi(let online), .leading):
                Image(systemName: online ? "wifi" : "wifi.slash").font(Tok.icon).foregroundStyle(online ? Tok.live : Tok.warning)
            case (.wifi(let online), .trailing):
                StatusLine(text: online ? "Online" : "Offline", live: online)
            case (.timer, .leading):
                // A minute's resolution is enough at a glance; 5 s ticks keep the closed notch nearly free.
                TimelineView(.periodic(from: .now, by: 5)) { ctx in
                    ProgressRing(fraction: timer.progress(at: ctx.date).fraction, lineWidth: 2.5).frame(width: 15, height: 15)
                }
            case (.timer, .trailing):
                TimelineView(.periodic(from: .now, by: 5)) { ctx in
                    let r = timer.progress(at: ctx.date).remaining
                    Text(r < 60 ? "<1m" : "\(Int((r / 60).rounded(.up)))m").font(Tok.digits).foregroundStyle(Tok.ink)
                        .contentTransition(.numericText(countsDown: true))
                }
            case (.timerDone, .leading):
                Image(systemName: "timer").font(Tok.icon).foregroundStyle(Tok.live)
            case (.timerDone, .trailing):
                StatusLine(text: "Done", live: true)
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
