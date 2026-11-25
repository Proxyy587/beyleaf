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

    /// Pages shown right now and the one on screen (docs/widget-hub.md §1.2), reported by the open panel.
    @Published var visiblePages: [PageKind] = []
    @Published var currentPage: PageKind?
    /// +1 when the last page change went forward, -1 back: the side the new page slides in from.
    @Published var pageStep = 1
    /// The swipe-follow offset, in its own object so only the wrapper re-renders while fingers move.
    let swipe = SwipeState()

    init(metrics: NotchMetrics) { self.metrics = metrics }

    /// Shows `page` and remembers it as the page the notch opens on.
    func go(to page: PageKind) {
        guard page != currentPage, visiblePages.contains(page) else { return }
        let from = currentPage.flatMap { visiblePages.firstIndex(of: $0) } ?? 0
        pageStep = (visiblePages.firstIndex(of: page) ?? 0) >= from ? 1 : -1
        withAnimation(Tok.open) { AppSettings.shared.page = page }
    }

    /// Next (+1) or previous (-1) page. False at either end (no wrap).
    @discardableResult func go(by step: Int) -> Bool {
        guard let current = currentPage, let next = Pages.neighbour(of: current, by: step, visible: visiblePages) else { return false }
        go(to: next)
        return true
    }

    /// Exactly the hardware notch unless wings are visible.
    var closedSize: CGSize {
        CGSize(width: metrics.notchSize.width + (wingsVisible ? 2 * wingWidth : 0), height: metrics.notchSize.height)
    }
    /// The panel window's height; the shape animates inside it, so the open panel must fit with room for its shadow.
    static let canvasHeight: CGFloat = 620
    /// DEBUG `--page-limit <pt>`: forces a small limit so overflow can be seen with few widgets.
    nonisolated(unsafe) static var debugLimit: CGFloat?
    /// The most the open content (below the notch line) may grow to; taller pages scroll (docs/widget-hub.md §7).
    var maxContentHeight: CGFloat {
        Self.debugLimit ?? PanelFit.maxContent(canvas: Self.canvasHeight, screen: metrics.screenFrame.height, notch: metrics.notchSize.height)
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
    private let stopwatch = NotchStopwatch()
    private let notes = NotesStore()
    private let notesKey = GlobalHotKey()
    private lazy var activities = ActivityCenter(music: music, status: status, shots: shots, timer: countdown, stopwatch: stopwatch)
    private var activitySub: Any?
    private var settingsSub2: Any?
    private var pulseSub: Any?

    /// Wings show for a live activity. New activities and tracks get a
    /// jelly spring (more bounce than the open/close spring); reduced motion keeps it a fade.
    private func updateWings() {
        let activity = activities.current
        let show = activity != nil
        let width = activity?.wingWidth ?? NotchModel.wing
        guard show != model.wingsVisible || width != model.wingWidth else { return }
        withAnimation(Tok.jelly) { model.wingsVisible = show; model.wingWidth = width }
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
    /// Swipe and key monitors exist only while the notch is open (docs/widget-hub.md §7).
    private var inputMonitors: [Any] = []
    private var swipe = SwipeTracker()

    private var pinned = false          // opened from the menu / --expand
    private var pointerVisited = false
    private var leftAt: Date?
    private var timer: Timer?
    private var fastPolling = true
    private var screenObserver: NSObjectProtocol?

    /// The panel is sized for the largest state; the SwiftUI shape animates inside it.
    /// Large enough for the widest, tallest theme plus its shadow; transparent areas pass clicks through.
    private static let canvas = CGSize(width: 720, height: NotchModel.canvasHeight)

    func start(openOnLaunch: Bool) {
        let screen = Self.screen
        model = NotchModel(metrics: .of(screen))
        panel = NotchPanel(rect: frame(on: screen))
        let root = NotchRoot(model: model, music: music, status: status, shots: shots, timer: countdown, stopwatch: stopwatch, notes: notes, activities: activities, beat: beat,
                             openSettings: { [weak self] in self?.close(); self?.onOpenSettings() },
                             openFromClick: { [weak self] in self?.openFromClick() })
        let host = FirstClickHostingView(rootView: root)
        // The canvas never changes size; don't let SwiftUI recompute intrinsic size and constraints on every frame.
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: Self.canvas)
        panel.contentView = host
        panel.orderFrontRegardless()

        notes.onCaptured = { [weak self] in self?.close() }
        syncNotesShortcut()
        settingsSub2 = settings.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.syncNotesShortcut() } }

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
        // `--notes-capture "text"`: run the real save path once (with --notes-file, never the user's notes).
        if let i = a.firstIndex(of: "--notes-capture"), a.indices.contains(i + 1) { notes.loadIfNeeded(); notes.draft = a[i + 1]; notes.saveDraft() }
        if a.contains("--start-stopwatch") { stopwatch.start() }
        if a.contains("--demo-stopwatch") { stopwatch.demo() }
        if let i = a.firstIndex(of: "--start-timer"), a.indices.contains(i + 1), let m = Int(a[i + 1]) { countdown.start(minutes: m) }
        if let i = a.firstIndex(of: "--page-limit"), a.indices.contains(i + 1), let v = Double(a[i + 1]) { NotchModel.debugLimit = CGFloat(v) }
        if a.contains("--edit-widgets") { model.editing = true }
        // `--cycle-pages`: change page every 0.75 s while open, to measure what a page change costs.
        if a.contains("--cycle-pages") {
            let t = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { guard let self else { return }; if !self.model.go(by: 1), let first = self.model.visiblePages.first { self.model.go(to: first) } }
            }
            RunLoop.main.add(t, forMode: .common)
        }
        // `--cycle-open`: open and close every 1.5 s forever, to measure what the animation costs.
        if a.contains("--cycle-open") {
            let t = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { guard let self else { return }; self.model.isOpen ? self.close() : self.open() }
            }
            RunLoop.main.add(t, forMode: .common)
        }
        // `--beat-demo`: show the music wing with synthetic bars (no audio) to measure drawing cost.
        if a.contains("--beat-demo") { probing = true; beat.startDemo(); activities.flash(.nowPlaying, for: 3600) }
        // `--flash-copied`: play the "screenshot copied" moment (held 20 s) without taking a screenshot.
        if a.contains("--flash-copied") { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.activities.flash(.copied, for: 20) } }
        #endif
        if openOnLaunch { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.open() } }
    }

    /// ⌃⌥N (docs/widget-hub.md §3.4): open on Notes with the field focused. The panel becomes key without activating Belay.
    func captureNote() {
        settings.page = .notes
        notes.closeAfterSave = true
        let wasOpen = model.isOpen
        open()
        DispatchQueue.main.asyncAfter(deadline: .now() + (wasOpen ? 0 : 0.15)) {
            self.panel.makeKey()
            self.notes.requestFocus()
        }
    }

    /// Registers ⌃⌥N while the shortcut is on and the Notes widget is enabled; says so in Settings when another app owns it.
    private func syncNotesShortcut() {
        let widgetOn = settings.pages.flatMap(\.widgets).contains { $0.kind == .notes && $0.enabled }
        let want = settings.notesShortcut && widgetOn
        if !want { notesKey.unregister(); notesKeyRegistered = false; if settings.notesShortcutTaken { settings.notesShortcutTaken = false }; return }
        if notesKeyRegistered { return }
        let ok = notesKey.register { [weak self] in self?.captureNote() }
        notesKeyRegistered = ok
        #if DEBUG
        FileHandle.standardError.write(Data("notes shortcut \(ok ? "registered" : "REFUSED")\n".utf8))
        #endif
        if settings.notesShortcutTaken == ok { settings.notesShortcutTaken = !ok }
    }
    private var notesKeyRegistered = false

    func open() { pinned = true; pointerVisited = false; setOpen(true) }
    /// Click mode: opened under the pointer, so it closes when the pointer leaves (like hover).
    func openFromClick() { pinned = false; pointerVisited = true; setOpen(true) }
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
            if settings.openOnClick {
                // Click mode: take mouse events only while the pointer is over the notch itself, so the rest of the
                // menu bar keeps working; NotchRoot's tap opens it.
                let over = rectOnScreen(model.closedSize, grow: 2).contains(p)
                if panel.ignoresMouseEvents == over { panel.ignoresMouseEvents = !over }
                return
            }
            if !panel.ignoresMouseEvents { panel.ignoresMouseEvents = true }   // left over from click mode
            // Hover delay (Settings → General) avoids opening when the pointer just passes the menu bar.
            if rectOnScreen(model.closedSize, grow: 10).contains(p) {
                if hoverSince == nil { hoverSince = Date() }
                if let s = hoverSince, Date().timeIntervalSince(s) >= settings.openDelay {
                    hoverSince = nil; pinned = false
                    Tok.haptic(.alignment)   // hover only: a click open already has the trackpad's own click
                    setOpen(true)
                }
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
        if open { music.refreshIfUnknown() }
        music.setProgressActive(open)
        panel.ignoresMouseEvents = !open
        panel.keyable = open
        if !open, panel.isKeyWindow { panel.resignKey(); panel.orderOut(nil); panel.orderFrontRegardless() }  // hand key back to the app you were in
        withAnimation(open ? Tok.open : Tok.close) { model.isOpen = open; if !open { model.editing = false } }
        open ? installInputMonitors() : removeInputMonitors()
        updateBeat()
    }

    // MARK: - Pages: swipe and keys (docs/widget-hub.md §1.3)

    private func installInputMonitors() {
        guard inputMonitors.isEmpty else { return }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] e in
            let consumed = MainActor.assumeIsolated { self?.scroll(e) ?? false }
            return consumed ? nil : e
        }) { inputMonitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            let consumed = MainActor.assumeIsolated { self?.key(e) ?? false }
            return consumed ? nil : e
        }) { inputMonitors.append(m) }
    }

    private func removeInputMonitors() {
        inputMonitors.forEach(NSEvent.removeMonitor)
        inputMonitors.removeAll()
        swipe.reset(); model.swipe.offset = 0
    }

    /// Two-finger horizontal swipe (docs/widget-hub.md §1.3): the page follows the fingers with resistance, then commits
    /// past 60 pt of travel or springs back. Vertical scrolls and momentum pass through untouched.
    private func scroll(_ e: NSEvent) -> Bool {
        guard e.window === panel, e.hasPreciseScrollingDeltas else { return false }
        if !e.momentumPhase.isEmpty { return swipe.momentum(ended: e.momentumPhase.contains(.ended) || e.momentumPhase.contains(.cancelled)) }
        guard !e.phase.isEmpty else { return false }
        let phase: SwipeTracker.Phase = e.phase.contains(.began) || e.phase.contains(.mayBegin) ? .began
            : e.phase.contains(.ended) || e.phase.contains(.cancelled) ? .ended : .changed
        // Finger direction, whatever the natural-scrolling setting.
        let sign: CGFloat = e.isDirectionInvertedFromDevice ? 1 : -1
        let m = model!
        let r = swipe.feed(dx: e.scrollingDeltaX * sign, dy: e.scrollingDeltaY, phase: phase, followsFingers: !Tok.reduceMotion) { step in
            m.currentPage.flatMap { Pages.neighbour(of: $0, by: step, visible: m.visiblePages) } != nil
        }
        if let step = r.commit { model.go(by: step) }
        if r.settle { withAnimation(Tok.open) { model.swipe.offset = 0 } }
        else if let o = r.offset, o != model.swipe.offset { model.swipe.offset = o }
        return r.consumed
    }

    /// While the panel is key: ⌘[ / ⌘] page back and forward, ⌘1–⌘9 jump, Esc closes.
    private func key(_ e: NSEvent) -> Bool {
        guard e.window === panel else { return false }
        let mods = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if e.keyCode == 53 {                                                  // Esc: clears the Notes field first, then closes
            if model.currentPage == .notes, notes.isSearching { notes.draft = ""; return true }
            close(); return true
        }
        guard mods == .command, let c = e.charactersIgnoringModifiers else { return false }
        switch c {
        case "[": model.go(by: -1); return true
        case "]": model.go(by: 1); return true
        default:
            if let n = Int(c), n >= 1, model.visiblePages.indices.contains(n - 1) { model.go(to: model.visiblePages[n - 1]); return true }
            return false
        }
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

/// How far the open page is pulled by a swipe in progress. Separate from NotchModel so a swipe re-renders only the
/// wrapper that applies the offset, not the panel.
@MainActor
final class SwipeState: ObservableObject {
    @Published var offset: CGFloat = 0
}
