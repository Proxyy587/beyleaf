import AppKit
import os

/// Belay's entry point. A dock-less agent app (LSUIElement); the notch is the UI.
/// v0.0 prototype: notch shell, music, Wi-Fi, battery, volume, screenshot auto-copy, Settings. No agent features yet.
@main
@MainActor
final class BelayApp: NSObject, NSApplicationDelegate {
    private var notch: NotchController?
    private var statusItem: NSStatusItem?
    private let settingsWindow = SettingsWindowController()

    static func main() {
        #if DEBUG
        Logger(subsystem: "app.belay.mac", category: "perf").notice("main \(msSinceProcessStart(), privacy: .public) ms after launch")
        #endif
        let app = NSApplication.shared
        let delegate = BelayApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        BeepoMark.renderIconIfAsked()
        #if DEBUG
        let perf = Logger(subsystem: "app.belay.mac", category: "perf")
        perf.notice("didFinishLaunching \(Self.msSinceProcessStart(), privacy: .public) ms")
        defer { perf.notice("setup done \(Self.msSinceProcessStart(), privacy: .public) ms") }
        #endif
        AppSettings.shared.observePowerState()
        let controller = NotchController()
        controller.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        // Live preview: keep the notch open while Settings is open.
        settingsWindow.onShow = { [weak controller] in if AppSettings.shared.previewWhileEditing { controller?.open() } }
        settingsWindow.onClose = { [weak controller] in if AppSettings.shared.previewWhileEditing { controller?.close() } }
        notch = controller
        controller.start(openOnLaunch: CommandLine.arguments.contains("--expand"))
        installStatusItem()
        CoreLink.shared.startIfRequested()
        BuddyStore.shared.attach(CoreLink.shared)
        if CommandLine.arguments.contains("--settings") { settingsWindow.show() }
        #if DEBUG
        BuddyReviewWindow.showIfRequested()
        #endif
        // Launch time from process start to here (docs/performance.md budget: < 300 ms). Counts only.
        DispatchQueue.main.async {
            Logger(subsystem: "app.belay.mac", category: "perf").notice("ready \(Self.msSinceProcessStart(), privacy: .public) ms after launch")
        }
    }

    func applicationWillTerminate(_ notification: Notification) { CoreLink.shared.stop() }

    private static func msSinceProcessStart() -> Int {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return -1 }
        let start = info.kp_proc.p_starttime
        let started = Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000
        return Int((Date().timeIntervalSince1970 - started) * 1000)
    }

    /// A small menu bar item so a dock-less app can be opened, configured and quit.
    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = BeepoMark.menuBarImage()
        let menu = NSMenu()
        menu.addItem(withTitle: "Open notch", action: #selector(openNotch), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Belay", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func openNotch() { notch?.open() }
    @objc private func openSettings() { settingsWindow.show() }
}
