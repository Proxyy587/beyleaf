import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// User preferences for the shell (appearance and behaviour only; product logic lives in belayd, ADR 0001).
/// Persisted in UserDefaults; every change applies live.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum MusicActivity: String, CaseIterable, Identifiable {
        case keep, brief, off
        var id: String { rawValue }
        var name: String { switch self { case .keep: "Keep showing"; case .brief: "Show briefly"; case .off: "Don't show" } }
    }

    /// The active theme (ADR 0015). Changing any field re-renders the notch.
    @Published var theme: Theme { didSet { if theme != oldValue { themeRevision &+= 1; saveTheme() } } }
    /// Bumped on every theme change; used as a view identity so every token is re-read.
    @Published private(set) var themeRevision = 0
    /// Themes the user saved under their own names.
    @Published private(set) var savedThemes: [Theme]
    /// Keep the notch open while Settings is in front, as a live preview.
    @Published var previewWhileEditing = true

    /// What the closed notch does while music plays (Dynamic Island style).
    @Published var musicActivity: MusicActivity { didSet { save(musicActivity.rawValue, "musicActivity") } }
    @Published var alertLowBattery: Bool { didSet { save(alertLowBattery, "alertLowBattery") } }
    @Published var alertWifi: Bool { didSet { save(alertWifi, "alertWifi") } }
    @Published var equalizerWhilePlaying: Bool { didSet { save(equalizerWhilePlaying, "equalizerWhilePlaying") } }
    @Published var haptics: Bool { didSet { save(haptics, "haptics") } }
    /// Seconds the pointer must rest on the notch before it opens (0 = instant).
    @Published var openDelay: Double { didSet { save(openDelay, "openDelay") } }
    /// Seconds after the pointer leaves before the notch closes (0 = instant).
    @Published var closeDelay: Double { didSet { save(closeDelay, "closeDelay") } }
    @Published var screenshotAutoCopy: Bool { didSet { save(screenshotAutoCopy, "screenshotAutoCopy") } }
    /// What the open notch shows, in the user's order (ADR 0019). Not part of the theme: a theme is only the look.
    @Published var widgets: [WidgetSetting] { didSet { if widgets != oldValue { saveWidgets() } } }
    /// Show a running timer in the closed notch (when music isn't playing) and flash when it ends.
    @Published var timerActivity: Bool { didSet { save(timerActivity, "timerActivity") } }
    /// Settings shows the essentials by default; theme, type, colour, surface and motion sit behind this.
    @Published var showAdvanced: Bool { didSet { save(showAdvanced, "showAdvancedSettings") } }

    private let d = UserDefaults.standard

    // MARK: Defaults (one place, used by init and by Settings' per-section resets)
    static let defaultMusicActivity = MusicActivity.keep

    func resetHover() { openDelay = 0; closeDelay = 0 }
    var hoverIsDefault: Bool { openDelay == 0 && closeDelay == 0 }
    func resetLiveActivities() {
        musicActivity = Self.defaultMusicActivity; equalizerWhilePlaying = true
        alertLowBattery = true; alertWifi = true; timerActivity = true
    }
    var liveActivitiesAreDefault: Bool {
        musicActivity == Self.defaultMusicActivity && equalizerWhilePlaying && alertLowBattery && alertWifi && timerActivity
    }

    // MARK: Widgets
    func resetWidgets() { widgets = WidgetSetting.defaults }
    var widgetsAreDefault: Bool { widgets == WidgetSetting.defaults }
    func isEnabled(_ kind: WidgetKind) -> Bool { widgets.first { $0.kind == kind }?.enabled ?? false }
    func setEnabled(_ kind: WidgetKind, _ on: Bool) {
        guard let i = widgets.firstIndex(where: { $0.kind == kind }), widgets[i].enabled != on else { return }
        widgets[i].enabled = on
    }
    /// Moves a widget one step among the *enabled* widgets, so ↑/↓ in the notch always visibly moves it.
    func moveWidget(_ kind: WidgetKind, by step: Int) {
        guard let i = widgets.firstIndex(where: { $0.kind == kind }) else { return }
        var j = i + step
        while widgets.indices.contains(j), !widgets[j].enabled { j += step }
        guard widgets.indices.contains(j) else { return }
        var w = widgets
        let item = w.remove(at: i)
        w.insert(item, at: j)
        widgets = w
    }
    func moveWidgets(from source: IndexSet, to destination: Int) {
        var w = widgets
        let moving = source.map { w[$0] }
        for i in source.sorted(by: >) { w.remove(at: i) }
        let target = destination - source.filter { $0 < destination }.count
        w.insert(contentsOf: moving, at: target)
        widgets = w
    }
    /// First enabled widget, last enabled widget: for disabling ↑/↓ at the ends.
    func canMove(_ kind: WidgetKind, by step: Int) -> Bool {
        guard let i = widgets.firstIndex(where: { $0.kind == kind }) else { return false }
        var j = i + step
        while widgets.indices.contains(j) { if widgets[j].enabled { return true }; j += step }
        return false
    }

    /// The theme a section reset returns to: the saved theme or preset the current one is named after, else Midnight.
    var themeBase: Theme {
        savedThemes.first { $0.name == theme.name } ?? Theme.presets.first { $0.name == theme.name } ?? .midnight
    }
    func resetTheme(_ group: Theme.Group) { var t = theme; t.copy(group, from: themeBase); theme = t }
    func themeIsDefault(_ group: Theme.Group) -> Bool { theme.matches(group, themeBase) }

    private init() {
        let savedTheme = d.data(forKey: "theme").flatMap(Theme.decode) ?? .midnight
        theme = savedTheme
        savedThemes = d.data(forKey: "savedThemes").flatMap(Theme.decodeList) ?? []
        musicActivity = MusicActivity(rawValue: d.string(forKey: "musicActivity") ?? "") ?? Self.defaultMusicActivity
        alertLowBattery = d.object(forKey: "alertLowBattery") as? Bool ?? true
        alertWifi = d.object(forKey: "alertWifi") as? Bool ?? true
        equalizerWhilePlaying = d.object(forKey: "equalizerWhilePlaying") as? Bool ?? true
        haptics = d.object(forKey: "haptics") as? Bool ?? true
        // Instant by default; an older "hoverDelay" preference carries over as the open delay.
        openDelay = d.object(forKey: "openDelay") as? Double ?? d.object(forKey: "hoverDelay") as? Double ?? 0
        closeDelay = d.object(forKey: "closeDelay") as? Double ?? 0
        screenshotAutoCopy = d.object(forKey: "screenshotAutoCopy") as? Bool ?? true
        showAdvanced = d.object(forKey: "showAdvancedSettings") as? Bool ?? false
        timerActivity = d.object(forKey: "timerActivity") as? Bool ?? true
        widgets = d.data(forKey: "widgets").flatMap(WidgetSetting.decode) ?? Self.migratedWidgets(from: savedTheme)
    }

    /// One-time move of the old theme rows (order and visibility) into widgets; new kinds are appended.
    private static func migratedWidgets(from theme: Theme) -> [WidgetSetting] {
        let old = theme.rows.compactMap { r in WidgetKind(rawValue: r.kind.rawValue).map { WidgetSetting(kind: $0, enabled: r.visible) } }
        return WidgetSetting.normalized(old)
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
        guard let data = try? Data(contentsOf: url), let t = Theme.decode(data) else {
            return "That file isn't a Belay theme. Export one from Settings to see the format."
        }
        theme = t
        return nil
    }

    private func saveTheme() { if let data = try? JSONEncoder().encode(theme) { d.set(data, forKey: "theme") } }
    private func persistSaved() { if let data = try? JSONEncoder().encode(savedThemes) { d.set(data, forKey: "savedThemes") } }
    private func save(_ value: Any, _ key: String) { d.set(value, forKey: key) }
    private func saveWidgets() { if let data = try? JSONEncoder().encode(widgets) { d.set(data, forKey: "widgets") } }
}
