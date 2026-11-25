import Foundation
import CoreGraphics

// When the open notch may close because the pointer left it (docs/widget-hub.md §1.7, ADR 0023 follow-up). Foundation
// and CoreGraphics only, so the self-test compiles it alone with swiftc (scripts/widgets-selftest.sh).
//
// The notch is polled at 30 Hz. The old rule closed it the instant the pointer was 6 pt outside the panel's current
// rect, with a close delay that defaults to 0. A two-finger swipe, typing in Notes or dragging a card in edit mode all
// leave the pointer nearly still, but the panel's height changes between pages and the cursor drifts a few points, so
// it could close under the user's hands. These rules keep it open while the user is working with it.

enum HoverPolicy {
    /// Room around the open panel that still counts as "on it": generous at the sides and bottom, small at the top
    /// (the menu bar is not part of the panel).
    static let side: CGFloat = 20, bottom: CGFloat = 28, top: CGFloat = 6
    /// The shortest a genuine leave takes to close, whatever Settings says (0 would close on a pass of the cursor).
    static let minCloseDelay: TimeInterval = 0.3
    /// How long after the last scroll, key press or drag the notch counts as in use.
    static let interactionHold: TimeInterval = 1.5
    /// How long the tallest recent panel height keeps counting: a page change shrinks the panel while the pointer
    /// still rests where its bottom edge was.
    static let heightHold: TimeInterval = 1.2

    /// The area that counts as hovering the open panel. `panel` is its rect in screen coordinates (y up).
    static func hitRect(_ panel: CGRect) -> CGRect {
        CGRect(x: panel.minX - side, y: panel.minY - bottom, width: panel.width + 2 * side, height: panel.height + bottom + top)
    }

    static func closeDelay(setting: TimeInterval) -> TimeInterval { max(setting, minCloseDelay) }
}

/// Remembers the tallest panel height seen recently, so a page that is shorter than the one before doesn't pull the
/// hit area out from under a pointer that hasn't moved.
struct HeightHold {
    private var height: CGFloat = 0
    private var since: Date = .distantPast

    mutating func update(_ current: CGFloat, now: Date) -> CGFloat {
        if current >= height || now.timeIntervalSince(since) > HoverPolicy.heightHold { height = current; since = now }
        return max(current, height)
    }
    mutating func reset() { height = 0; since = .distantPast }
}

/// The close decision, fed once per poll with everything it needs (so it is a pure state machine over time).
struct HoverGuard {
    private(set) var leftAt: Date?
    private(set) var lastInteraction: Date?
    private(set) var pointerVisited = false

    /// Start of a new opening. A notch opened from a menu or `--expand` (`pinned`) stays until the pointer has been on it.
    mutating func reset(visited: Bool) { leftAt = nil; lastInteraction = nil; pointerVisited = visited }

    /// A scroll, key press or drag happened on the panel.
    mutating func interact(at now: Date) { lastInteraction = now; leftAt = nil }

    func isInteracting(at now: Date) -> Bool {
        lastInteraction.map { now.timeIntervalSince($0) < HoverPolicy.interactionHold } ?? false
    }

    /// - inside: the pointer is in the hit area (`HoverPolicy.hitRect`).
    /// - pinned: opened by something other than the pointer.
    /// - busy: a mouse button is down, a drag is in flight, or there is unsaved typing in the panel.
    /// - closeDelay: Settings' close delay.
    /// Returns true when the notch should close now.
    mutating func shouldClose(now: Date, inside: Bool, pinned: Bool, busy: Bool, closeDelay: TimeInterval) -> Bool {
        if inside { pointerVisited = true; leftAt = nil; return false }
        guard !pinned || pointerVisited else { return false }
        if busy || isInteracting(at: now) { leftAt = nil; return false }
        let since = leftAt ?? now
        leftAt = since
        return now.timeIntervalSince(since) >= HoverPolicy.closeDelay(setting: closeDelay)
    }
}
