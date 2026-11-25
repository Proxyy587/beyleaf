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
    /// Widget cards on the open notch (dusk-feel §3: menus and cards 14).
    static var rCard: CGFloat { 14 * t.roundness }
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
    /// Press down quickly, release with a hair of overshoot (dusk-feel §4). Reduced motion: no scale at all.
    static var pressDown: Animation { .easeOut(duration: 0.12 / t.speed) }
    static var pressUp: Animation { .timingCurve(0.28, 1.4, 0.36, 1, duration: 0.2 / t.speed) }
    static var blur: CGFloat { reduceMotion ? 0 : CGFloat(t.blur) }

    // MARK: Feel
    /// Haptics mark *hover* moments only (the notch opening under your finger). Never on a click: the trackpad's own
    /// click already gives feedback, and a second buzz feels like a double tap (owner feedback, 2026-11-25).
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

extension View {
    /// A widget card: one tonal surface, no border, no shadow (dusk-feel §1).
    func card(inset: CGFloat = Tok.s3) -> some View {
        self.padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Tok.rCard, style: .continuous).fill(Tok.raised))
    }

    /// Scale-on-press feedback shared by every pressable thing on the notch.
    func pressable(_ pressed: Bool) -> some View {
        self.scaleEffect(pressed && !Tok.reduceMotion ? 0.94 : 1)
            .animation(pressed ? Tok.pressDown : Tok.pressUp, value: pressed)
    }
}

/// Re-renders its content every `seconds`, only while `active` (hidden views don't tick).
/// The schedule's anchor is fixed: `.periodic(from: .now, …)` restarts on every re-render and fires immediately,
/// which turns a 1 s tick into a continuous redraw (measured at 12% CPU).
struct Ticking<Content: View>: View {
    let seconds: TimeInterval
    var active = true
    @ViewBuilder let content: (Date) -> Content
    private static var anchor: Date { Date(timeIntervalSinceReferenceDate: 0) }
    var body: some View {
        if active {
            TimelineView(.periodic(from: Self.anchor, by: seconds)) { ctx in content(ctx.date) }
        } else {
            content(Date())
        }
    }
}

/// A thin progress ring (timer). Track at ink 14%, progress in ink.
struct ProgressRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 3
    var body: some View {
        ZStack {
            Circle().stroke(Tok.ink.opacity(0.14), lineWidth: lineWidth)
            Circle().trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(Tok.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(Tok.reveal, value: fraction)
        .accessibilityHidden(true)
    }
}

/// A small tonal pill that does one thing (timer presets). Mono digits, press scale.
struct Chip: View {
    let title: String
    let label: String
    let action: () -> Void
    @State private var hover = false
    @State private var pressed = false
    var body: some View {
        Button(action: action) {
            Text(title).font(Tok.digits).foregroundStyle(Tok.ink)
                .padding(.horizontal, Tok.s3).frame(height: Tok.button)
                .background(Capsule().fill(hover ? Tok.pressedFill : Tok.hoverFill))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pressable(pressed)
        .help(label).accessibilityLabel(label)
        .onHover { h in withAnimation(Tok.hover) { hover = h } }
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in pressed = true }.onEnded { _ in pressed = false })
    }
}

/// The one primary action: a neutral pill that inverts the surface (ink fill, notch-coloured text; dusk-feel §2).
struct PillButton: View {
    let title: String
    let action: () -> Void
    @State private var hover = false
    @State private var pressed = false
    var body: some View {
        Button(action: action) {
            Text(title).font(Tok.font(12, .medium)).foregroundStyle(Tok.notch)
                .padding(.horizontal, Tok.s3).frame(height: 24)
                .background(Capsule().fill(Tok.ink.opacity(hover ? 0.885 : 1)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pressable(pressed)
        .accessibilityLabel(title)
        .onHover { h in withAnimation(Tok.hover) { hover = h } }
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in pressed = true }.onEnded { _ in pressed = false })
    }
}

/// On/off for the notch's own surface. Native switches turn grey in a non-key panel, so this one is drawn from
/// tokens: on is an ink track with a notch-coloured knob (the same inversion as PillButton).
struct NotchSwitch: View {
    @Binding var isOn: Bool
    let label: String
    var body: some View {
        Button { isOn.toggle() } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Tok.ink : Tok.ink.opacity(0.18))
                Circle().fill(isOn ? Tok.notch : Tok.ink).padding(2)
            }
            .frame(width: 30, height: 18)
            .animation(Tok.pressUp, value: isOn)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
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
