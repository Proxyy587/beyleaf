import AppKit
import SwiftUI

/// Everything about how Belay looks and moves, as one Codable value (ADR 0015).
/// `Tok` resolves every token from the active theme, so a user can change fonts, colours, surfaces, shapes, layout and
/// motion, and save or share the result as JSON. Presets follow docs/design.md; user edits are the user's call.
struct Theme: Codable, Equatable {
    var name: String

    // Typography
    var uiFont: String                 // font family, or "System"
    var monoFont: String               // fixed-pitch family, or "System Mono"
    var textScale: Double              // 0.85 … 1.3
    var statusUppercase: Bool
    var statusTracking: Double         // points

    // Colour (hex)
    var ink: String
    var ink2Opacity: Double
    var ink3Opacity: Double
    var accent: String
    var live: String

    // Surface
    var background: Background
    var backgroundColor: String
    var glassTint: Double              // 0 … 1 darkness over the blur
    var shadow: Double                 // 0 … 1

    // Shape and layout
    var width: Double                  // points, 360 … 560
    var roundness: Double              // 0.5 … 1.6 multiplier on corner radii
    var density: Density
    var rows: [RowSetting]

    // Motion
    var speed: Double                  // 0.6 … 1.6 multiplier (higher = faster)
    var blur: Double                   // 0 … 16 points of blur on reveals and swaps
    var bounce: Double                 // 0 … 0.3
    var motion: MotionPreference

    enum Background: String, Codable, CaseIterable, Identifiable { case solid, glass; var id: String { rawValue }
        var name: String { self == .solid ? "Solid" : "Glass" } }
    enum Density: String, Codable, CaseIterable, Identifiable { case compact, regular, comfortable; var id: String { rawValue }
        var name: String { rawValue.capitalized }
        var rowHeight: CGFloat { switch self { case .compact: 36; case .regular: 44; case .comfortable: 52 } } }
    enum MotionPreference: String, Codable, CaseIterable, Identifiable { case system, full, reduced; var id: String { rawValue }
        var name: String { switch self { case .system: "Follow system"; case .full: "Full"; case .reduced: "Reduced" } } }

    struct RowSetting: Codable, Equatable, Identifiable {
        var kind: RowKind
        var visible: Bool
        var id: RowKind { kind }
    }
    enum RowKind: String, Codable, CaseIterable, Identifiable {
        case nowPlaying, wifi, battery, volume, screenshot
        var id: String { rawValue }
        var name: String {
            switch self { case .nowPlaying: "Now playing"; case .wifi: "Wi-Fi"; case .battery: "Battery"; case .volume: "Volume"; case .screenshot: "Last screenshot" }
        }
    }

    static let defaultRows: [RowSetting] = RowKind.allCases.map { RowSetting(kind: $0, visible: true) }

    // MARK: Presets (each passes the anti-slop list in docs/design.md)

    static let midnight = Theme(
        name: "Midnight", uiFont: "System", monoFont: "System Mono", textScale: 1, statusUppercase: true, statusTracking: 0.8,
        ink: "#F5F5F3", ink2Opacity: 0.62, ink3Opacity: 0.40, accent: "#2F7BF2", live: "#5BD08A",
        background: .solid, backgroundColor: "#000000", glassTint: 0.55, shadow: 0.5,
        width: 440, roundness: 1, density: .regular, rows: defaultRows,
        speed: 1, blur: 6, bounce: 0.12, motion: .system)

    static let smoke: Theme = {
        var t = midnight
        t.name = "Smoke"; t.background = .glass; t.glassTint = 0.45; t.blur = 8; t.roundness = 1.2
        return t
    }()

    static let terminal: Theme = {
        var t = midnight
        t.name = "Terminal"; t.uiFont = "System Mono"; t.live = "#7CE38B"; t.accent = "#7CE38B"
        t.roundness = 0.6; t.density = .compact; t.blur = 0; t.bounce = 0; t.speed = 1.3
        return t
    }()

    static let soft: Theme = {
        var t = midnight
        t.name = "Soft"; t.textScale = 1.08; t.statusUppercase = false; t.statusTracking = 0
        t.roundness = 1.5; t.density = .comfortable; t.width = 480; t.blur = 10; t.bounce = 0.18; t.speed = 0.85
        return t
    }()

    static let presets: [Theme] = [midnight, smoke, terminal, soft]
}

// MARK: - Colour ⇄ hex

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0xF5F5F3
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    var hex: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        return String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }
}

// MARK: - Fonts installed on this Mac

enum InstalledFonts {
    static let all: [String] = ["System"] + NSFontManager.shared.availableFontFamilies.sorted()
    static let mono: [String] = {
        let names = NSFontManager.shared.availableFontNames(with: .fixedPitchFontMask) ?? []
        let families = Set(names.compactMap { NSFont(name: $0, size: 12)?.familyName })
        return ["System Mono"] + families.sorted()
    }()
}
