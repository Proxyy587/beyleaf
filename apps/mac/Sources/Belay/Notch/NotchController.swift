// Cursor polling cadence adapted from Perch (MIT), Sources/Perch/NotchController.swift @ 47ce905f. See third_party/perch/.
import AppKit
import Combine
import SwiftUI

/// UI state for the notch. Swift renders; when agent features arrive, *what* to show comes from belayd (ADR 0001).
@MainActor
final class NotchModel: ObservableObject {
    @Published var isOpen = false
    /// The open panel is showing the widget editor (docs/notch-widgets.md §6). Cleared when the notch closes.
    @Published var editing = false
    @Published var metrics: NotchMetrics
    /// Height of the open content, measured by SwiftUI.
    @Published var openContentHeight: CGFloat = 230
    @Published var openWidth: CGFloat = Tok.openWidth

    /// Room for the compact "wings" either side of the hardware notch, when shown.
    static let wing: CGFloat = 40
    /// Current wing width, per activity.
    @Published var wingWidth: CGFloat = 40
    /// Wings are shown only for a live activity (music, screenshot copied, low battery, internet).
    @Published var wingsVisible = false
    /// Height of a sentence row below the notch line during a drop activity (screenshot copied).
    @Published var dropHeight: CGFloat = 0

    init(metrics: NotchMetrics) { self.metrics = metrics }

    /// Exactly the hardware notch unless wings are visible.
    var closedSize: CGSize {
        CGSize(width: metrics.notchSize.width + (wingsVisible ? 2 * wingWidth : 0), height: metrics.notchSize.height + dropHeight)
    }
    var openSize: CGSize { CGSize(width: openWidth, height: metrics.notchSize.height + openContentHeight) }
}

/// Owns the panel and decides when the notch opens and closes.
///
/// Hover detection polls the cursor (30 Hz near the top of the screen, 4 Hz elsewhere) instead of a global mouse-moved
/// monitor: no Accessibility permission, and almost no cost while the cursor is far away.
@MainActor
final class NotchController {
    private let music = NowPlaying()
    private let status = SystemStatus()
    private let shots = Screenshots()
    private let beat = MusicBeat()
    private let countdown = NotchTimer()
    private var beatSubs: [Any] = []
    private var screensAsleep = false
    private var probing = false
    private let settings = AppSettings.shared
    private var settingsSub: Any?
    var onOpenSettings: () -> Void = {}
    private var hoverSince: Date?
    private lazy var activities = ActivityCenter(music: music, status: status, shots: shots, timer: countdown)
    private var activitySub: Any?
    private var pulseSub: Any?

    /// Wings show for a live activity. New activities and tracks get a
    /// jelly spring (more bounce than the open/close spring); reduced motion keeps it a fade.
    private func updateWings() {
        let activity = activities.current
        let show = activity != nil
        let width = activity?.wingWidth ?? NotchModel.wing
        let drop = activity?.dropHeight ?? 0
        guard show != model.wingsVisible || width != model.wingWidth || drop != model.dropHeight else { return }
        withAnimation(Tok.jelly) { model.wingsVisible = show; model.wingWidth = width; model.dropHeight = drop }
    }
    /// Listen to the player's audio only while the bars are on screen: music playing, the music wing showing (closed
    /// notch), bars on, motion allowed, screens awake. Everything else stops the tap (battery, privacy).
    private func updateBeat() {
        guard !probing else { return }
        let visible = music.isPlaying && !model.isOpen && activities.current == .nowPlaying && !screensAsleep
        let wanted = visible && settings.equalizerWhilePlaying && !Tok.reduceMotion
        beat.listen(to: wanted ? music.player?.bundleID : nil)
    }
    private var model: NotchModel!
    private var panel: NotchPanel!

    private var pinned = false          // opened from the menu / --expand
    private var pointerVisited = false
    private var leftAt: Date?
    private var timer: Timer?
    private var fastPolling = true
    private var screenObserver: NSObjectProtocol?

    /// The panel is sized for the largest state; the SwiftUI shape animates inside it.
    /// Large enough for the widest, tallest theme plus its shadow; transparent areas pass clicks through.
    private static let canvas = CGSize(width: 720, height: 620)

    func start(openOnLaunch: Bool) {
        let screen = Self.screen
        model = NotchModel(metrics: .of(screen))
        panel = NotchPanel(rect: frame(on: screen))
        let root = NotchRoot(model: model, music: music, status: status, shots: shots, timer: countdown, activities: activities, beat: beat,
                             openSettings: { [weak self] in self?.close(); self?.onOpenSettings() })
        let host = FirstClickHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: Self.canvas)
        panel.contentView = host
        panel.orderFrontRegardless()

        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.relayout() }
        }
        settingsSub = settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                withAnimation(Tok.open) { self.model.openWidth = Tok.openWidth }
                self.shots.apply()
                self.updateWings()
            }
        }
        activitySub = activities.$current.sink { [weak self] _ in DispatchQueue.main.async { self?.updateWings(); self?.updateBeat() } }
        beatSubs = [
            music.$isPlaying.sink { [weak self] _ in DispatchQueue.main.async { self?.updateBeat() } },
            music.$trackChange.sink { [weak self] _ in DispatchQueue.main.async { self?.beat.retry(); self?.updateBeat() } },
            settings.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.updateBeat() } },
        ]
        let ws = NSWorkspace.shared.notificationCenter
        for (name, asleep) in [(NSWorkspace.screensDidSleepNotification, true), (NSWorkspace.screensDidWakeNotification, false)] {
            beatSubs.append(ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.screensAsleep = asleep; self?.updateBeat() }
            })
        }
        updateWings()
        music.refreshIfUnknown()
        startPolling()
        #if DEBUG
        // `--beat-probe <bundle id>`: start the tap on that (running, not necessarily playing) player for 5 s, then
        // stop, to check the start/stop path and logs without playing anything. Nothing is played or recorded.
        if let i = CommandLine.arguments.firstIndex(of: "--beat-probe"), CommandLine.arguments.indices.contains(i + 1) {
            let id = CommandLine.arguments[i + 1]
            probing = true
            beat.listen(to: id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self.beat.listen(to: nil); self.probing = false; self.updateBeat() }
        }
        // `--start-timer <minutes>` / `--edit-widgets`: put the notch in those states for screenshots.
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "--start-timer"), a.indices.contains(i + 1), let m = Int(a[i + 1]) { countdown.start(minutes: m) }
        if a.contains("--edit-widgets") { model.editing = true }
        // `--flash-copied`: play the "screenshot copied" moment (held 20 s) without taking a screenshot.
        if a.contains("--flash-copied") { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.activities.flash(.copied, for: 20) } }
        #endif
        if openOnLaunch { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.open() } }
    }

    func open() { pinned = true; pointerVisited = false; setOpen(true) }
    func close() { pinned = false; setOpen(false) }

    // MARK: - Hover

    private func startPolling() {
        timer?.invalidate()
        let t = Timer(timeInterval: fastPolling ? 1.0 / 30.0 : 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let p = NSEvent.mouseLocation
        let f = model.metrics.screenFrame
        let fast = model.isOpen || (f.maxY - p.y) < 160
        if fast != fastPolling { fastPolling = fast; startPolling(); return }

        if !model.isOpen {
            // Hover delay (Settings → General) avoids opening when the pointer just passes the menu bar.
            if rectOnScreen(model.closedSize, grow: 10).contains(p) {
                if hoverSince == nil { hoverSince = Date() }
                if let s = hoverSince, Date().timeIntervalSince(s) >= settings.openDelay { hoverSince = nil; pinned = false; setOpen(true) }
            } else { hoverSince = nil }
            return
        }
        if rectOnScreen(model.openSize, grow: 6).contains(p) {
            pointerVisited = true; leftAt = nil
        } else if !pinned || pointerVisited {
            if leftAt == nil { leftAt = Date() }
            if let t = leftAt, Date().timeIntervalSince(t) >= settings.closeDelay { pinned = false; setOpen(false) }
        }
    }

    /// The notch shape's rect in screen coordinates (top-centred).
    private func rectOnScreen(_ size: CGSize, grow: CGFloat) -> NSRect {
        let f = model.metrics.screenFrame
        let top = model.metrics.hasNotch ? f.maxY : f.maxY - 6
        return NSRect(x: f.midX - size.width / 2, y: top - size.height, width: size.width, height: size.height).insetBy(dx: -grow, dy: -grow)
    }

    private func setOpen(_ open: Bool) {
        guard model.isOpen != open else { return }
        leftAt = nil
        if open { Tok.haptic(.alignment); music.refreshIfUnknown() }
        music.setProgressActive(open)
        panel.ignoresMouseEvents = !open
        withAnimation(open ? Tok.open : Tok.close) { model.isOpen = open; if !open { model.editing = false } }
        updateBeat()
    }

    // MARK: - Screens

    private func frame(on screen: NSScreen) -> NSRect {
        let f = screen.frame
        return NSRect(x: f.midX - Self.canvas.width / 2, y: f.maxY - Self.canvas.height, width: Self.canvas.width, height: Self.canvas.height)
    }

    private func relayout() {
        let screen = Self.screen
        model.metrics = .of(screen)
        panel.setFrame(frame(on: screen), display: true)
    }

    /// The built-in display with a notch if there is one, otherwise the main screen.
    static var screen: NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}
