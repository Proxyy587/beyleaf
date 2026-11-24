import SwiftUI

/// User preferences for the shell (appearance and behaviour only; product logic lives in belayd, ADR 0001).
/// Persisted in UserDefaults; every change applies live.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum Accent: String, CaseIterable, Identifiable {
        case blue, green, orange, pink, purple, graphite
        var id: String { rawValue }
        var name: String { rawValue.capitalized }
        var color: Color {
            switch self {
            case .blue: Color(red: 0.184, green: 0.482, blue: 0.949)
            case .green: Color(red: 0.357, green: 0.816, blue: 0.541)
            case .orange: Color(red: 1.0, green: 0.49, blue: 0.12)
            case .pink: Color(red: 1.0, green: 0.36, blue: 0.62)
            case .purple: Color(red: 0.55, green: 0.36, blue: 0.94)
            case .graphite: Color(white: 0.62)
            }
        }
    }

    enum Width: String, CaseIterable, Identifiable {
        case compact, standard, wide
        var id: String { rawValue }
        var name: String { rawValue.capitalized }
        var points: CGFloat { switch self { case .compact: 400; case .standard: 440; case .wide: 500 } }
    }

    enum Wing: String, CaseIterable, Identifiable {
        case climber, battery, time, none
        var id: String { rawValue }
        var name: String { self == .none ? "Nothing" : rawValue.capitalized }
    }

    enum HoverDelay: Double, CaseIterable, Identifiable {
        case instant = 0, short = 0.15, relaxed = 0.35
        var id: Double { rawValue }
        var name: String { switch self { case .instant: "Instant"; case .short: "Short"; case .relaxed: "Relaxed" } }
    }

    @Published var accent: Accent { didSet { save(accent.rawValue, "accent") } }
    @Published var width: Width { didSet { save(width.rawValue, "width") } }
    @Published var leftWing: Wing { didSet { save(leftWing.rawValue, "leftWing") } }
    @Published var rightWing: Wing { didSet { save(rightWing.rawValue, "rightWing") } }
    @Published var equalizerWhilePlaying: Bool { didSet { save(equalizerWhilePlaying, "equalizerWhilePlaying") } }
    @Published var haptics: Bool { didSet { save(haptics, "haptics") } }
    @Published var hoverDelay: HoverDelay { didSet { save(hoverDelay.rawValue, "hoverDelay") } }
    @Published var screenshotAutoCopy: Bool { didSet { save(screenshotAutoCopy, "screenshotAutoCopy") } }

    private let d = UserDefaults.standard

    private init() {
        accent = Accent(rawValue: d.string(forKey: "accent") ?? "") ?? .blue
        width = Width(rawValue: d.string(forKey: "width") ?? "") ?? .standard
        leftWing = Wing(rawValue: d.string(forKey: "leftWing") ?? "") ?? .climber
        rightWing = Wing(rawValue: d.string(forKey: "rightWing") ?? "") ?? .battery
        equalizerWhilePlaying = d.object(forKey: "equalizerWhilePlaying") as? Bool ?? true
        haptics = d.object(forKey: "haptics") as? Bool ?? true
        hoverDelay = HoverDelay(rawValue: d.object(forKey: "hoverDelay") as? Double ?? 0.15) ?? .short
        screenshotAutoCopy = d.object(forKey: "screenshotAutoCopy") as? Bool ?? true
    }

    private func save(_ value: Any, _ key: String) { d.set(value, forKey: key) }
}
