import AppKit
import SwiftUI

/// Every colour, size, radius, font and animation Belay's UI uses (docs/design.md). Views never hard-code these.
@MainActor
enum Tok {
    // MARK: Colour (§3)
    static let notch = Color.black
    static let inkBase = Color(red: 0.961, green: 0.961, blue: 0.953)          // #F5F5F3
    static let ink = inkBase
    static let ink2 = inkBase.opacity(0.62)
    static let ink3 = inkBase.opacity(0.40)
    static let raised = inkBase.opacity(0.06)
    static let hoverFill = inkBase.opacity(0.08)
    static let pressedFill = inkBase.opacity(0.12)
    static let hairline = inkBase.opacity(0.10)
    static let live = Color(red: 0.357, green: 0.816, blue: 0.541)             // #5BD08A
    static let warning = Color(red: 1.0, green: 0.68, blue: 0.26)
    static let danger = Color(red: 1.0, green: 0.36, blue: 0.40)
    static var accent: Color { AppSettings.shared.accent.color }

    // MARK: Type (§4)
    static let title = Font.system(size: 15, weight: .semibold)
    static let rowTitle = Font.system(size: 13, weight: .medium)
    static let body = Font.system(size: 13, weight: .regular)
    static let meta = Font.system(size: 12, weight: .regular)
    static let status = Font.system(size: 10, weight: .regular, design: .monospaced)
    static let statusTracking: CGFloat = 0.8                                     // ≈ +0.08em at 10 pt
    static let digits = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let icon = Font.system(size: 14, weight: .medium)
    static let buttonIcon = Font.system(size: 15, weight: .medium)

    // MARK: Shape (§5)
    static let rRow: CGFloat = 12
    static let rControl: CGFloat = 8
    static let rThumb: CGFloat = 6
    static let rOpenBottom: CGFloat = 24
    static let rOpenEar: CGFloat = 12

    // MARK: Space (§6)
    static let s1: CGFloat = 4, s2: CGFloat = 8, s3: CGFloat = 12, s4: CGFloat = 16, s5: CGFloat = 20, s6: CGFloat = 24
    static let rowHeight: CGFloat = 44
    static let gutter: CGFloat = 20
    static let button: CGFloat = 28

    // MARK: Motion (§7)
    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    static var open: Animation { reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.34, dampingFraction: 0.86) }
    static var close: Animation { reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.28, dampingFraction: 1.0) }
    static var reveal: Animation { .easeOut(duration: reduceMotion ? 0.1 : 0.18) }
    static let hover = Animation.easeOut(duration: 0.12)

    // MARK: Feel (§8)
    static func haptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern = .generic) {
        guard AppSettings.shared.haptics else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}

/// Status line: SF Mono 10, uppercase, tracked. Machine status only (docs/design.md §4).
struct StatusLine: View {
    let text: String
    var live = false
    var body: some View {
        Text(text.uppercased())
            .font(Tok.status)
            .tracking(Tok.statusTracking)
            .foregroundStyle(live ? Tok.live : Tok.ink3)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
