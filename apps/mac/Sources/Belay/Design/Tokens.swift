import AppKit
import SwiftUI

/// Every colour, size, radius, font and animation Belay's UI uses (docs/design.md), resolved from the active theme
/// (ADR 0015). Views never hard-code these. Views that use them sit under `.id(settings.themeRevision)`, so any theme
/// change re-reads every token.
@MainActor
enum Tok {
    private static var t: Theme { AppSettings.shared.theme }

    // MARK: Colour
    static var notch: Color { Color(hex: t.backgroundColor) }
    static var ink: Color { Color(hex: t.ink) }
    static var ink2: Color { ink.opacity(t.ink2Opacity) }
    static var ink3: Color { ink.opacity(t.ink3Opacity) }
    static var raised: Color { ink.opacity(0.06) }
    static var hoverFill: Color { ink.opacity(0.08) }
    static var pressedFill: Color { ink.opacity(0.12) }
    static var hairline: Color { ink.opacity(0.10) }
    static var live: Color { Color(hex: t.live) }
    static var accent: Color { Color(hex: t.accent) }
    static let warning = Color(red: 1.0, green: 0.68, blue: 0.26)
    static let danger = Color(red: 1.0, green: 0.36, blue: 0.40)
    static var shadow: Double { t.shadow }
    static var isGlass: Bool { t.background == .glass }
    static var glassTint: Double { t.glassTint }

    // MARK: Type
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular, mono: Bool = false) -> Font {
        let s = size * t.textScale
        let family = mono ? t.monoFont : t.uiFont
        switch family {
        case "System": return .system(size: s, weight: weight)
        case "System Mono": return .system(size: s, weight: weight, design: .monospaced)
        default: return .custom(family, size: s).weight(weight)
        }
    }
    static var title: Font { font(15, .semibold) }
    static var rowTitle: Font { font(13, .medium) }
    static var body: Font { font(13) }
    static var meta: Font { font(12) }
    static var status: Font { font(10, mono: true) }
    static var statusTracking: CGFloat { t.statusTracking }
    static var statusUppercase: Bool { t.statusUppercase }
    static var digits: Font { font(12, .medium, mono: true) }
    static var icon: Font { .system(size: 14 * t.textScale, weight: .medium) }
    static var buttonIcon: Font { .system(size: 15 * t.textScale, weight: .medium) }

    // MARK: Shape
    static var rRow: CGFloat { 12 * t.roundness }
    static var rThumb: CGFloat { 6 * t.roundness }
    static var rOpenBottom: CGFloat { 24 * t.roundness }
    static var rOpenEar: CGFloat { min(18, 12 * t.roundness) }

    // MARK: Space and layout
    static let s1: CGFloat = 4, s2: CGFloat = 8, s3: CGFloat = 12, s4: CGFloat = 16, s5: CGFloat = 20, s6: CGFloat = 24
    static var rowHeight: CGFloat { t.density.rowHeight }
    static var gutter: CGFloat { 20 * t.textScale }
    static var button: CGFloat { 28 * min(1.15, t.textScale) }
    /// Space between an icon button's edge and its glyph. Buttons at a row's edge pull out by this much, so the glyph
    /// (not the invisible hit area) lines up with text and values above and below.
    static var buttonInset: CGFloat { (button - 15 * t.textScale) / 2 }
    static var openWidth: CGFloat { CGFloat(t.width) }

    // MARK: Motion (300 ms ceiling at speed 1; blur is subtle and off for reduced motion)
    static var reduceMotion: Bool {
        switch t.motion {
        case .system: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        case .full: false
        case .reduced: true
        }
    }
    static var open: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.34 / t.speed, dampingFraction: 1 - t.bounce)
    }
    static var close: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.28 / t.speed, dampingFraction: 1.0)
    }
    /// Live-activity morph: squash-and-stretch with a touch more bounce than opening (Dynamic Island feel).
    static var jelly: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.42 / t.speed, dampingFraction: max(0.55, 0.72 - t.bounce))
    }
    static var reveal: Animation { .easeOut(duration: (reduceMotion ? 0.1 : 0.2) / t.speed) }
    static var hover: Animation { .easeOut(duration: 0.12 / t.speed) }
    static var blur: CGFloat { reduceMotion ? 0 : CGFloat(t.blur) }

    // MARK: Feel
    static func haptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern = .generic) {
        guard AppSettings.shared.haptics else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}

/// Status line: mono, small, tracked; uppercase unless the theme says otherwise. Machine status only (docs/design.md §4).
struct StatusLine: View {
    let text: String
    var live = false
    var body: some View {
        Text(Tok.statusUppercase ? text.uppercased() : text)
            .font(Tok.status)
            .tracking(Tok.statusTracking)
            .foregroundStyle(live ? Tok.live : Tok.ink3)
            .lineLimit(1)
            .truncationMode(.tail)
            .blurSwap(on: text)
    }
}

extension View {
    /// Subtle blur-and-fade when `value` changes (track names, wing contents). No-op under reduced motion.
    func blurSwap<V: Hashable>(on value: V) -> some View {
        self.id(value)
            .transition(Tok.reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
            .animation(Tok.reveal, value: value)
    }

    /// Blur-in reveal for content appearing after the notch opens.
    func blurReveal(_ shown: Bool, delay: Double = 0) -> some View {
        self.opacity(shown ? 1 : 0)
            .blur(radius: shown ? 0 : Tok.blur)
            .scaleEffect(shown ? 1 : 0.97, anchor: .top)
            .animation(shown ? Tok.reveal.delay(delay) : Tok.reveal, value: shown)
    }
}

/// Behind-window blur for the "Glass" surface, masked to the notch shape by the caller.
struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.appearance = NSAppearance(named: .darkAqua)
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
