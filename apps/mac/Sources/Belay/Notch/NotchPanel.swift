import AppKit
import SwiftUI

/// A borderless, non-activating panel pinned over the notch. It never becomes the active app (golden rule: never steal
/// focus) and passes clicks through while the notch is closed.
final class NotchPanel: NSPanel {
    init(rect: NSRect) {
        super.init(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false                 // SwiftUI draws the shadow, so it follows the shape
        level = .statusBar + 1            // above the menu bar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Lets buttons and sliders respond to the first click without activating Belay.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Measurements of the notch on a screen. Approach as in Perch's NotchGeometry (MIT), see third_party/perch/.
struct NotchMetrics: Equatable {
    var hasNotch: Bool
    var notchSize: CGSize        // hardware notch (or a virtual pill on screens without one)
    var screenFrame: NSRect

    @MainActor static func of(_ screen: NSScreen) -> NotchMetrics {
        if screen.safeAreaInsets.top > 0, let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
            return NotchMetrics(hasNotch: true,
                                notchSize: CGSize(width: screen.frame.width - l.width - r.width, height: screen.safeAreaInsets.top),
                                screenFrame: screen.frame)
        }
        return NotchMetrics(hasNotch: false, notchSize: CGSize(width: 190, height: 26), screenFrame: screen.frame)
    }
}
