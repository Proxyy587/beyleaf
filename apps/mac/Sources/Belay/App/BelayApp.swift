import AppKit

/// Belay's entry point. A menu-bar-less, dock-less agent app (LSUIElement); the notch is the UI.
/// v0.0 prototype: notch shell, music, Wi-Fi, battery, volume, time. No agent features yet.
@main
@MainActor
final class BelayApp: NSObject, NSApplicationDelegate {
    private var notch: NotchController?
    private var statusItem: NSStatusItem?

    static func main() {
        let app = NSApplication.shared
        let delegate = BelayApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchController()
        notch = controller
        controller.start(openOnLaunch: CommandLine.arguments.contains("--expand"))
        installStatusItem()
    }

    /// A small menu bar item so a dock-less app can still be quit and tested.
    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "figure.climbing", accessibilityDescription: "Belay")
            ?? NSImage(systemSymbolName: "circle.hexagongrid", accessibilityDescription: "Belay")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open notch", action: #selector(openNotch), keyEquivalent: "o").target = self
        menu.addItem(withTitle: "Close notch", action: #selector(closeNotch), keyEquivalent: "c").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Belay", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func openNotch() { notch?.open() }
    @objc private func closeNotch() { notch?.close() }
}
