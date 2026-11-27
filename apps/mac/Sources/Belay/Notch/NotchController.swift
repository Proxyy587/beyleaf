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

    /// One page's width plus nothing between pages: how far a page travels to replace its neighbour.
    var pageStride: CGFloat { openWidth - 2 * Tok.rOpenEar - (AppSettings.shared.expanded ? Tok.rail : 0) }

    /// Shows `page` and remembers it as the page the notch opens on. The pages slide: the new one arrives from the side
    /// you're going to while the old one leaves the other way, so a click, a key and a swipe all move the same way.
    func go(to page: PageKind) {
        guard page != currentPage, visiblePages.contains(page), let from = currentPage else { return }
        let step = (visiblePages.firstIndex(of: page) ?? 0) >= (visiblePages.firstIndex(of: from) ?? 0) ? 1 : -1
        pageStep = step
        swipe.token += 1
        let token = swipe.token
        if Tok.reduceMotion || !isOpen || editing {
            withAnimation(Tok.open) { AppSettings.shared.page = page }
            swipe.offset = 0; swipe.partner = nil
            return
        }
        // Phase one, unanimated: the new page becomes the page in place and the old one its neighbour, with the offset
        // chosen so nothing on screen moves (a swipe in progress already has the new page partway in).
        let travel = CGFloat(step) * pageStride
        var instant = Transaction(); instant.disablesAnimations = true
        withTransaction(instant) {
            AppSettings.shared.page = page
            swipe.partner = from; swipe.side = -step
            swipe.offset += travel
        }
        // Phase two, next turn of the run loop so phase one is drawn first: slide to rest.
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.slideToRest(token: token) }
        }
    }

    /// Springs the page in place back to rest and drops the neighbour once it has left.
    func slideToRest(token: Int? = nil) {
        if let token, token != swipe.token { return }
        swipe.token += 1
        let mine = swipe.token
        withAnimation(Tok.slide, completionCriteria: .logicallyComplete) {
            swipe.offset = 0
        } completion: { [weak self] in
            guard let self, self.swipe.token == mine else { return }
            self.swipe.partner = nil; self.swipe.side = 0
        }
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
    private var swipeWatchdog: DispatchWorkItem?

    #if DEBUG
    /// `--trace-input`: log scroll events and hover decisions to stderr.
    static let traceInput = CommandLine.arguments.contains("--trace-input")
    #endif
    private var pinned = false          // opened from the menu / --expand
    /// When the pointer leaving may close the notch (HoverLogic.swift): grace area, close delay, and "in use" holds.
    private var hover = HoverGuard()
    private var heightHold = HeightHold()
    private var timer: Timer?
    private var fastPolling = true
    private var screenObserver: NSObjectProtocol?

    /// The panel is sized for the largest state; the SwiftUI shape animates inside it.
    /// Large enough for the widest, tallest theme plus its shadow; transparent areas pass clicks through.
    private static let canvas = CGSize(width: 1010, height: NotchModel.canvasHeight)

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
        CalendarService.shared.start()   // loads only if access was already granted; never prompts
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
        // `--weather-city "London"`: a real search and forecast for this run only (nothing is saved).
        if let i = a.firstIndex(of: "--weather-city"), a.indices.contains(i + 1) {
            let name = a[i + 1]
            Task { @MainActor in self.settings.weatherCity = await WeatherService.shared.search(name)?.first }
        }
        if a.contains("--calendar-demo") { CalendarService.shared.loadDemo() }
        // `--buddies-demo`: sample buddies, thread and routines, in memory only (docs/buddies.md).
        if a.contains("--buddies-demo") { BuddyStore.shared.loadDemo() }
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

    func open() { pinned = true; setOpen(true) }
    /// Click mode: opened under the pointer, so it closes when the pointer leaves (like hover).
    func openFromClick() { pinned = false; setOpen(true) }
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
        // Open: stay open while the pointer is on the panel or its grace area, and while the user is working with it
        // (scrolling, typing, dragging); close only after a genuine leave (HoverLogic.swift).
        let now = Date()
        var size = model.openSize
        size.height = heightHold.update(size.height, now: now)
        let hit = HoverPolicy.hitRect(rectOnScreen(size, grow: 0))
        let busy = NSEvent.pressedMouseButtons != 0 || (panel.isKeyWindow && !notes.draft.isEmpty)
        let close = hover.shouldClose(now: now, inside: hit.contains(p), pinned: pinned, busy: busy, closeDelay: settings.closeDelay)
        #if DEBUG
        if Self.traceInput, close { FileHandle.standardError.write(Data("hover: closing, pointer \(p), hit \(hit)\n".utf8)) }
        #endif
        if close { pinned = false; setOpen(false) }
    }

    /// The notch shape's rect in screen coordinates (top-centred).
    private func rectOnScreen(_ size: CGSize, grow: CGFloat) -> NSRect {
        let f = model.metrics.screenFrame
        let top = model.metrics.hasNotch ? f.maxY : f.maxY - 6
        return NSRect(x: f.midX - size.width / 2, y: top - size.height, width: size.width, height: size.height).insetBy(dx: -grow, dy: -grow)
    }

    private func setOpen(_ open: Bool) {
        guard model.isOpen != open else { return }
        hover.reset(visited: !pinned)
        heightHold.reset()
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
        swipeWatchdog?.cancel(); swipe.reset(); model.swipe.token += 1; model.swipe.offset = 0; model.swipe.partner = nil
    }

    /// Whether an input event is for the open panel. DEBUG `--trace-input` also takes events with no window: the ones
    /// `scripts/synth-swipe.swift` posts to this process, which carry no window.
    private func isOurs(_ e: NSEvent) -> Bool {
        #if DEBUG
        if Self.traceInput, e.window == nil { return true }
        #endif
        return e.window === panel
    }

    /// Two-finger horizontal swipe (docs/widget-hub.md §1.3): the page follows the fingers with resistance, then commits
    /// past 60 pt of travel or springs back. Vertical scrolls and momentum pass through untouched.
    private func scroll(_ e: NSEvent) -> Bool {
        #if DEBUG
        if Self.traceInput { FileHandle.standardError.write(Data("scroll win=\(e.window === panel) precise=\(e.hasPreciseScrollingDeltas) phase=\(e.phase.rawValue) mom=\(e.momentumPhase.rawValue) dx=\(e.scrollingDeltaX) dy=\(e.scrollingDeltaY) offset=\(model.swipe.offset)\n".utf8)) }
        #endif
        guard isOurs(e) else { return false }
        hover.interact(at: Date())   // any scroll on the panel, vertical or horizontal, momentum included
        guard e.hasPreciseScrollingDeltas else { return false }
        if !e.momentumPhase.isEmpty { return swipe.momentum(ended: e.momentumPhase.contains(.ended) || e.momentumPhase.contains(.cancelled)) }
        guard !e.phase.isEmpty else { return false }
        let phase: SwipeTracker.Phase = e.phase.contains(.began) || e.phase.contains(.mayBegin) ? .began
            : e.phase.contains(.ended) || e.phase.contains(.cancelled) ? .ended : .changed
        // Finger direction, whatever the natural-scrolling setting.
        let sign: CGFloat = e.isDirectionInvertedFromDevice ? 1 : -1
        let m = model!
        let r = swipe.feed(dx: e.scrollingDeltaX * sign, dy: e.scrollingDeltaY, phase: phase, followsFingers: !Tok.reduceMotion,
                           width: m.pageStride, time: e.timestamp) { step in
            m.currentPage.flatMap { Pages.neighbour(of: $0, by: step, visible: m.visiblePages) } != nil
        }
        if let o = r.offset {
            // The neighbour rides in from the side the fingers are going to; at the end of the list there is none.
            let step = o < 0 ? 1 : -1
            let next = m.currentPage.flatMap { Pages.neighbour(of: $0, by: step, visible: m.visiblePages) }
            if m.swipe.partner != next || m.swipe.side != step { m.swipe.token += 1; m.swipe.partner = next; m.swipe.side = step }
            if o != m.swipe.offset { m.swipe.offset = o }
        }
        if r.settle {
            if let step = r.commit, let next = m.currentPage.flatMap({ Pages.neighbour(of: $0, by: step, visible: m.visiblePages) }) { m.go(to: next) }
            else { m.slideToRest() }
        }
        // The end of a gesture can go to another window if the pointer drifted off the panel, and then we never see it.
        // Without it the page would stay displaced: settle after a short silence.
        swipeWatchdog?.cancel()
        if model.swipe.offset != 0, !r.settle {
            let w = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.model.swipe.offset != 0 else { return }
                    self.swipe.reset()
                    self.model.slideToRest()
                }
            }
            swipeWatchdog = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: w)
        }
        return r.consumed
    }

    /// While the panel is key: ⌘[ / ⌘] page back and forward, ⌘1–⌘9 jump, Esc closes.
    private func key(_ e: NSEvent) -> Bool {
        guard isOurs(e) else { return false }
        hover.interact(at: Date())
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

/// How far the open page is pulled by a swipe or a slide in progress, and the neighbouring page that rides along. Separate
/// from NotchModel so a swipe re-renders only the strip that applies it, not the panel.
@MainActor
final class SwipeState: ObservableObject {
    /// Points the page in place has moved from rest (negative = towards the next page).
    @Published var offset: CGFloat = 0
    /// The page sliding in or out beside it, and the side it sits on (+1 right, -1 left). Only exists while moving, so a
    /// page that isn't on screen never ticks, polls or fetches.
    @Published var partner: PageKind?
    var side = 0
    /// Bumped by every new gesture or slide, so a finished slide can't clear a newer one's neighbour.
    var token = 0
}
