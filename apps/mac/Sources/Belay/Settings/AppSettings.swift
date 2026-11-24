import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// User preferences for the shell (appearance and behaviour only; product logic lives in belayd, ADR 0001).
/// Persisted in UserDefaults; every change applies live.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum ClosedStyle: String, CaseIterable, Identifiable {
        case exactFit, withInfo
        var id: String { rawValue }
        var name: String { self == .exactFit ? "Exact fit" : "With info beside" }
    }

    enum MusicActivity: String, CaseIterable, Identifiable {
        case keep, brief, off
        var id: String { rawValue }
        var name: String { switch self { case .keep: "Keep showing"; case .brief: "Show briefly"; case .off: "Don't show" } }
    }

    enum Wing: String, CaseIterable, Identifiable {
        case climber, battery, time, none
        var id: String { rawValue }
        var name: String { self == .none ? "Nothing" : rawValue.capitalized }
    }


    /// The active theme (ADR 0015). Changing any field re-renders the notch.
    @Published var theme: Theme { didSet { if theme != oldValue { themeRevision &+= 1; saveTheme() } } }
    /// Bumped on every theme change; used as a view identity so every token is re-read.
    @Published private(set) var themeRevision = 0
    /// Themes the user saved under their own names.
    @Published private(set) var savedThemes: [Theme]
    /// Keep the notch open while Settings is in front, as a live preview.
    @Published var previewWhileEditing = true

    /// Closed notch: exactly the hardware notch (default), or widened with info beside the camera.
    @Published var closedStyle: ClosedStyle { didSet { save(closedStyle.rawValue, "closedStyle") } }
    /// What the closed notch does while music plays (Dynamic Island style).
    @Published var musicActivity: MusicActivity { didSet { save(musicActivity.rawValue, "musicActivity") } }
    @Published var alertCharging: Bool { didSet { save(alertCharging, "alertCharging") } }
    @Published var alertLowBattery: Bool { didSet { save(alertLowBattery, "alertLowBattery") } }
    @Published var alertWifi: Bool { didSet { save(alertWifi, "alertWifi") } }
    @Published var leftWing: Wing { didSet { save(leftWing.rawValue, "leftWing") } }
    @Published var rightWing: Wing { didSet { save(rightWing.rawValue, "rightWing") } }
    @Published var equalizerWhilePlaying: Bool { didSet { save(equalizerWhilePlaying, "equalizerWhilePlaying") } }
    @Published var haptics: Bool { didSet { save(haptics, "haptics") } }
    /// Seconds the pointer must rest on the notch before it opens (0 = instant).
    @Published var openDelay: Double { didSet { save(openDelay, "openDelay") } }
    /// Seconds after the pointer leaves before the notch closes (0 = instant).
    @Published var closeDelay: Double { didSet { save(closeDelay, "closeDelay") } }
    @Published var screenshotAutoCopy: Bool { didSet { save(screenshotAutoCopy, "screenshotAutoCopy") } }
    /// Settings shows the essentials by default; theme, type, colour, surface and motion sit behind this.
    @Published var showAdvanced: Bool { didSet { save(showAdvanced, "showAdvancedSettings") } }

    private let d = UserDefaults.standard

    // MARK: Defaults (one place, used by init and by Settings' per-section resets)
    static let defaultClosedStyle = ClosedStyle.exactFit
    static let defaultMusicActivity = MusicActivity.keep
    static let defaultLeftWing = Wing.climber
    static let defaultRightWing = Wing.battery

    func resetHover() { openDelay = 0; closeDelay = 0 }
    var hoverIsDefault: Bool { openDelay == 0 && closeDelay == 0 }
    func resetLiveActivities() {
        musicActivity = Self.defaultMusicActivity; equalizerWhilePlaying = true
        alertCharging = true; alertLowBattery = true; alertWifi = true
    }
    var liveActivitiesAreDefault: Bool {
        musicActivity == Self.defaultMusicActivity && equalizerWhilePlaying && alertCharging && alertLowBattery && alertWifi
    }
    func resetClosedNotch() { closedStyle = Self.defaultClosedStyle; leftWing = Self.defaultLeftWing; rightWing = Self.defaultRightWing }
    var closedNotchIsDefault: Bool {
        closedStyle == Self.defaultClosedStyle && leftWing == Self.defaultLeftWing && rightWing == Self.defaultRightWing
    }

    /// The theme a section reset returns to: the saved theme or preset the current one is named after, else Midnight.
    var themeBase: Theme {
        savedThemes.first { $0.name == theme.name } ?? Theme.presets.first { $0.name == theme.name } ?? .midnight
    }
    func resetTheme(_ group: Theme.Group) { var t = theme; t.copy(group, from: themeBase); theme = t }
    func themeIsDefault(_ group: Theme.Group) -> Bool { theme.matches(group, themeBase) }

    private init() {
        theme = (d.data(forKey: "theme")).flatMap { try? JSONDecoder().decode(Theme.self, from: $0) } ?? .midnight
        savedThemes = (d.data(forKey: "savedThemes")).flatMap { try? JSONDecoder().decode([Theme].self, from: $0) } ?? []
        closedStyle = ClosedStyle(rawValue: d.string(forKey: "closedStyle") ?? "") ?? Self.defaultClosedStyle
        musicActivity = MusicActivity(rawValue: d.string(forKey: "musicActivity") ?? "") ?? Self.defaultMusicActivity
        alertCharging = d.object(forKey: "alertCharging") as? Bool ?? true
        alertLowBattery = d.object(forKey: "alertLowBattery") as? Bool ?? true
        alertWifi = d.object(forKey: "alertWifi") as? Bool ?? true
        leftWing = Wing(rawValue: d.string(forKey: "leftWing") ?? "") ?? Self.defaultLeftWing
        rightWing = Wing(rawValue: d.string(forKey: "rightWing") ?? "") ?? Self.defaultRightWing
        equalizerWhilePlaying = d.object(forKey: "equalizerWhilePlaying") as? Bool ?? true
        haptics = d.object(forKey: "haptics") as? Bool ?? true
        // Instant by default; an older "hoverDelay" preference carries over as the open delay.
        openDelay = d.object(forKey: "openDelay") as? Double ?? d.object(forKey: "hoverDelay") as? Double ?? 0
        closeDelay = d.object(forKey: "closeDelay") as? Double ?? 0
        screenshotAutoCopy = d.object(forKey: "screenshotAutoCopy") as? Bool ?? true
        showAdvanced = d.object(forKey: "showAdvancedSettings") as? Bool ?? false
    }

    // MARK: Themes

    /// Applying a preset changes the look, not what the notch shows: the user's rows (which, in what order) stay.
    func apply(_ preset: Theme) {
        var t = preset
        t.rows = theme.rows
        theme = t
    }

    func saveCurrentTheme(as name: String) {
        var t = theme
        t.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? "My theme" : name
        savedThemes.removeAll { $0.name == t.name }
        savedThemes.append(t)
        theme = t
        persistSaved()
    }

    func deleteSavedTheme(named name: String) {
        savedThemes.removeAll { $0.name == name }
        persistSaved()
    }

    func exportTheme() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(theme.name).belaytheme.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? enc.encode(theme).write(to: url)
    }

    /// Returns an error line for the UI, or nil on success.
    func importTheme() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let data = try? Data(contentsOf: url), let t = try? JSONDecoder().decode(Theme.self, from: data) else {
            return "That file isn't a Belay theme. Export one from Settings to see the format."
        }
        theme = t
        return nil
    }

    private func saveTheme() { if let data = try? JSONEncoder().encode(theme) { d.set(data, forKey: "theme") } }
    private func persistSaved() { if let data = try? JSONEncoder().encode(savedThemes) { d.set(data, forKey: "savedThemes") } }
    private func save(_ value: Any, _ key: String) { d.set(value, forKey: key) }
}
