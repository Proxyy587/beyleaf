import AppKit
import SwiftUI

/// Belay's motion and haptic vocabulary (docs/features.md §7). Springs only; haptics accent, never carry meaning alone.
enum Feel {
    static let open = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let close = Animation.spring(response: 0.32, dampingFraction: 0.9)
    static let tile = Animation.spring(response: 0.5, dampingFraction: 0.82)

    @MainActor static func tap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}
