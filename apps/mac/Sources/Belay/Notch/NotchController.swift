// Cursor polling cadence adapted from Perch (MIT), Sources/Perch/NotchController.swift @ 47ce905f. See third_party/perch/.
import AppKit
import Combine
import SwiftUI

/// UI state for the notch. Swift renders; when agent features arrive, *what* to show comes from belayd (ADR 0001).
@MainActor
final class NotchModel: ObservableObject {
    @Published var isOpen = false
    @Published var metrics: NotchMetrics
    /// Height of the open content, measured by SwiftUI.
    @Published var openContentHeight: CGFloat = 230
    @Published var openWidth: CGFloat = AppSettings.shared.width.points

    /// Room for the compact "wings" either side of the hardware notch.
    static let wing: CGFloat = 40

    init(metrics: NotchMetrics) { self.metrics = metrics }

    var closedSize: CGSize { CGSize(width: metrics.notchSize.width + 2 * Self.wing, height: metrics.notchSize.height) }
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
    private let settings = AppSettings.shared
    private var settingsSub: Any?
    var onOpenSettings: () -> Void = {}
    private var hoverSince: Date?
    private var model: NotchModel!
    private var panel: NotchPanel!

    private var pinned = false          // opened from the menu / --expand
    private var pointerVisited = false
    private var leftAt: Date?
    private var timer: Timer?
    private var fastPolling = true
    private var screenObserver: NSObjectProtocol?

    /// The panel is sized for the largest state; the SwiftUI shape animates inside it.
    private static let canvas = CGSize(width: 560, height: 360)

    func start(openOnLaunch: Bool) {
        let screen = Self.screen
        model = NotchModel(metrics: .of(screen))
        panel = NotchPanel(rect: frame(on: screen))
        let root = NotchRoot(model: model, music: music, status: status, shots: shots,
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
                withAnimation(Tok.open) { self.model.openWidth = self.settings.width.points }
                self.shots.apply()
            }
        }
        music.refreshIfUnknown()
        status.setActive(false)
        startPolling()
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
                if let s = hoverSince, Date().timeIntervalSince(s) >= settings.hoverDelay.rawValue { hoverSince = nil; pinned = false; setOpen(true) }
            } else { hoverSince = nil }
            return
        }
        if rectOnScreen(model.openSize, grow: 6).contains(p) {
            pointerVisited = true; leftAt = nil
        } else if !pinned || pointerVisited {
            if leftAt == nil { leftAt = Date() }
            if let t = leftAt, Date().timeIntervalSince(t) > 0.35 { pinned = false; setOpen(false) }
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
        status.setActive(open)
        panel.ignoresMouseEvents = !open
        withAnimation(open ? Tok.open : Tok.close) { model.isOpen = open }
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
