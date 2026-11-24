import AppKit

/// Belay's entry point. A dock-less agent app (LSUIElement); the notch is the UI.
/// v0.0 prototype: notch shell, music, Wi-Fi, battery, volume, screenshot auto-copy, Settings. No agent features yet.
@main
@MainActor
final class BelayApp: NSObject, NSApplicationDelegate {
    private var notch: NotchController?
    private var statusItem: NSStatusItem?
    private let settingsWindow = SettingsWindowController()

    static func main() {
        let app = NSApplication.shared
        let delegate = BelayApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchController()
        controller.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        // Live preview: keep the notch open while Settings is open.
        settingsWindow.onShow = { [weak controller] in if AppSettings.shared.previewWhileEditing { controller?.open() } }
        settingsWindow.onClose = { [weak controller] in if AppSettings.shared.previewWhileEditing { controller?.close() } }
        notch = controller
        controller.start(openOnLaunch: CommandLine.arguments.contains("--expand"))
        installStatusItem()
        if CommandLine.arguments.contains("--settings") { settingsWindow.show() }
    }

    /// A small menu bar item so a dock-less app can be opened, configured and quit.
    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "figure.climbing", accessibilityDescription: "Belay")
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
