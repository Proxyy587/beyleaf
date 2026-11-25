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
    /// What the open notch shows: pages of widgets, in the user's order (ADR 0021). Not part of the theme.
    @Published var pages: [PageSetting] { didSet { if pages != oldValue { savePages() } } }
    /// The page the notch opens on: the one the user last chose (docs/widget-hub.md §1.3).
    @Published var page: PageKind { didSet { if page != oldValue, persistsPages { save(page.rawValue, "notchPage") } } }
    /// Show a running timer in the closed notch (when music isn't playing) and flash when it ends.
    @Published var timerActivity: Bool { didSet { save(timerActivity, "timerActivity") } }
    /// Other time zones the Clock shows, by identifier, at most three (docs/widget-hub.md §3.1).
    @Published var clockZones: [String] { didSet { let c = ClockLogic.clean(clockZones); if c != clockZones { clockZones = c } else {
        if persistsPages { save(c, "clockZones") }
        // Zones show only in the clock's wide layout: adding the first one widens a small clock (the user's own edit).
        if oldValue.isEmpty, !c.isEmpty, span(of: .clock) == .small { setSpan(.clock, .wide) }
    } } }
    /// Show a running stopwatch in the closed notch (when neither music nor a timer is live).
    @Published var stopwatchActivity: Bool { didSet { save(stopwatchActivity, "stopwatchActivity") } }
    /// The city the Weather widget shows (typed in Settings; never Location). Nil until chosen.
    @Published var weatherCity: WeatherCity? {
        didSet {
            guard persistsWeather else { return }
            if let data = weatherCity.flatMap({ try? JSONEncoder().encode($0) }) { d.set(data, forKey: "weatherCity") } else { d.removeObject(forKey: "weatherCity") }
        }
    }
    @Published var weatherUnits: WeatherUnits { didSet { if persistsWeather { save(weatherUnits.rawValue, "weatherUnits") } } }
    /// Debug flags that set a city or forecast turn this off, so nothing they set is saved.
    var persistsWeather: Bool { persistsPages }
    /// Show "meeting soon" in the closed notch 5 minutes before an event.
    @Published var upcomingActivity: Bool { didSet { save(upcomingActivity, "upcomingActivity") } }
    /// ⌃⌥N opens the notch on Notes with the field focused (docs/widget-hub.md §3.4).
    @Published var notesShortcut: Bool { didSet { save(notesShortcut, "notesShortcut") } }
    /// Another app owns ⌃⌥N (set by the controller; not saved).
    @Published var notesShortcutTaken = false
    /// Hover the notch to open it (default), or click it. Click mode catches clicks only on the notch itself.
    @Published var openOnClick: Bool { didSet { save(openOnClick, "openOnClick") } }
    /// Compact (2 grid columns) or expanded (3: wider, with room for more widgets; they keep their size). Toggled from the band.
    @Published var expanded: Bool { didSet { if persistsPages { save(expanded, "notchExpanded") } } }
    /// How hard Belay may work to look smooth (Settings → General → Performance).
    @Published var performanceMode: PerformanceMode { didSet { save(performanceMode.rawValue, "performanceMode") } }
    /// Bumped when macOS Low Power Mode changes, so `performance` re-resolves for Auto.
    @Published private(set) var powerStateRevision = 0

    private let d = UserDefaults.standard

    // MARK: Defaults (one place, used by init and by Settings' per-section resets)
    static let defaultMusicActivity = MusicActivity.keep

    func resetHover() { openDelay = 0; closeDelay = 0; openOnClick = false }
    var hoverIsDefault: Bool { openDelay == 0 && closeDelay == 0 && !openOnClick }
    func resetLiveActivities() {
        musicActivity = Self.defaultMusicActivity; equalizerWhilePlaying = true
        alertLowBattery = true; alertWifi = true; timerActivity = true; stopwatchActivity = true; upcomingActivity = true
    }
    var liveActivitiesAreDefault: Bool {
        musicActivity == Self.defaultMusicActivity && equalizerWhilePlaying && alertLowBattery && alertWifi && timerActivity && stopwatchActivity && upcomingActivity
    }

    // MARK: Performance
    enum PerformanceMode: String, CaseIterable, Identifiable {
        case auto, efficient, smooth
        var id: String { rawValue }
        var name: String { switch self { case .auto: "Automatic"; case .efficient: "Save energy"; case .smooth: "Smoothest" } }
    }
    /// What the current mode allows right now. Auto saves energy in Low Power Mode and is smooth otherwise.
    struct Performance: Equatable {
        /// Cap for continuous animation (music bars). The display's own maximum (120 on ProMotion) when smooth.
        var maxFPS: Float
        /// Blur on reveals and text swaps (an offscreen pass per frame while animating).
        var blur: Bool
    }
    var performance: Performance {
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let saving = performanceMode == .efficient || (performanceMode == .auto && lowPower)
        let screenMax = Float(NSScreen.screens.map(\.maximumFramesPerSecond).max() ?? 60)
        return saving ? Performance(maxFPS: 30, blur: false) : Performance(maxFPS: max(60, screenMax), blur: true)
    }

    // MARK: Pages and widgets (ADR 0021)
    func resetWidgets() { pages = Pages.defaults }
    var widgetsAreDefault: Bool { pages == Pages.defaults }
    func pageSetting(_ kind: PageKind) -> PageSetting? { pages.first { $0.kind == kind } }
    func span(of kind: WidgetKind) -> WidgetSpan { Pages.span(of: kind, in: pages) }
    func setSpan(_ kind: WidgetKind, _ span: WidgetSpan) { var p = pages; Pages.setSpan(kind, span, in: &p); pages = p }
    /// Tap in the editor: the next size, as the current grid shows it.
    func cycleSpan(_ kind: WidgetKind, columns: Int) { var p = pages; Pages.cycleSpan(kind, columns: columns, in: &p); pages = p }
    func setEnabled(_ kind: WidgetKind, _ on: Bool) { var p = pages; Pages.setEnabled(kind, on, in: &p); pages = p }
    func moveWidget(_ kind: WidgetKind, by step: Int, skippingDisabled: Bool = true) {
        var p = pages; Pages.step(kind, by: step, skippingDisabled: skippingDisabled, in: &p); pages = p
    }
    func canMove(_ kind: WidgetKind, by step: Int, skippingDisabled: Bool = true) -> Bool {
        Pages.canStep(kind, by: step, skippingDisabled: skippingDisabled, in: pages)
    }
    func moveWidget(_ kind: WidgetKind, to page: PageKind, enabled: Bool = true) {
        var p = pages; Pages.move(kind, to: page, enabled: enabled, in: &p); pages = p
    }
    /// Reorders widgets within one page (Settings' drag list).
    func moveWidgets(on page: PageKind, from source: IndexSet, to destination: Int) {
        guard let i = pages.firstIndex(where: { $0.kind == page }) else { return }
        var p = pages
        p[i].widgets.move(fromOffsets: source, toOffset: destination)
        pages = p
    }
    /// Replaces one page's widget order (the notch editor commits a drag with this).
    func setOrder(_ kinds: [WidgetKind], on page: PageKind) {
        guard let i = pages.firstIndex(where: { $0.kind == page }) else { return }
        var p = pages
        let shown = kinds.compactMap { k in p[i].widgets.first { $0.kind == k } }
        p[i].widgets = shown + p[i].widgets.filter { !kinds.contains($0.kind) }
        pages = p
    }
    func movePages(from source: IndexSet, to destination: Int) { var p = pages; p.move(fromOffsets: source, toOffset: destination); pages = p }
    func setPageEnabled(_ kind: PageKind, _ on: Bool) {
        guard let i = pages.firstIndex(where: { $0.kind == kind }), pages[i].enabled != on else { return }
        pages[i].enabled = on
    }
    /// Every hidden widget, on any page (the editor's tray).
    var hiddenWidgets: [WidgetKind] { pages.flatMap { $0.widgets.filter { !$0.enabled }.map(\.kind) } }

    /// Debug builds: screenshot flags (`--page`, `--demo-pages`) change pages in memory only, never the user's saved ones.
    private(set) var persistsPages = true

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
        expanded = d.object(forKey: "notchExpanded") as? Bool ?? false
        openOnClick = d.object(forKey: "openOnClick") as? Bool ?? false
        performanceMode = PerformanceMode(rawValue: d.string(forKey: "performanceMode") ?? "") ?? .auto
        timerActivity = d.object(forKey: "timerActivity") as? Bool ?? true
        stopwatchActivity = d.object(forKey: "stopwatchActivity") as? Bool ?? true
        upcomingActivity = d.object(forKey: "upcomingActivity") as? Bool ?? true
        weatherCity = d.data(forKey: "weatherCity").flatMap { try? JSONDecoder().decode(WeatherCity.self, from: $0) }
        weatherUnits = WeatherUnits(rawValue: d.string(forKey: "weatherUnits") ?? "") ?? .auto
        notesShortcut = d.object(forKey: "notesShortcut") as? Bool ?? true
        let savedZones = ClockLogic.clean(d.stringArray(forKey: "clockZones") ?? [])
        clockZones = savedZones
        // Pages replace the single widget list (ADR 0021). Migrate once from `widgets` (or, older still, the theme's rows).
        let zonesShown = !savedZones.isEmpty
        pages = d.data(forKey: "pages").flatMap { Pages.decode($0, clockHasZones: zonesShown) }
            ?? Pages.migrated(from: d.data(forKey: "widgets").flatMap(WidgetSetting.decode) ?? Self.migratedWidgets(from: savedTheme), clockHasZones: zonesShown)
        page = PageKind(rawValue: d.string(forKey: "notchPage") ?? "") ?? .now
        if d.data(forKey: "pages") == nil { savePages() }
        #if DEBUG
        let a = CommandLine.arguments
        if a.contains("--demo-pages") || a.contains("--page") { persistsPages = false }
        // Debug zones are for this run only (persistsPages off stops the save).
        if a.contains("--weather-city") { persistsPages = false }   // the controller searches and sets it, in memory only
        if let i = a.firstIndex(of: "--clock-zones"), a.indices.contains(i + 1) { persistsPages = false; clockZones = ClockLogic.clean(a[i + 1].split(separator: ",").map(String.init)) }
        // `--enable-widget stopwatch`: turn a widget on for this run only (pages are not saved while it's given).
        for (i, arg) in a.enumerated() where arg == "--enable-widget" && a.indices.contains(i + 1) {
            guard let k = WidgetKind(rawValue: a[i + 1]) else { continue }
            persistsPages = false; var p = pages; Pages.setEnabled(k, true, in: &p); pages = p
        }
        // `--expanded`: the 3-column panel for this run only. `--span clock=1 --span notes=3`: sizes for this run only.
        if a.contains("--expanded") { persistsPages = false; expanded = true }
        for (i, arg) in a.enumerated() where arg == "--span" && a.indices.contains(i + 1) {
            let kv = a[i + 1].split(separator: "=").map(String.init)
            if kv.count == 2, let k = WidgetKind(rawValue: kv[0]), let n = Int(kv[1]), let sp = WidgetSpan(rawValue: n) {
                persistsPages = false; var p = pages; Pages.setSpan(k, sp, in: &p); pages = p
            }
        }
        if a.contains("--demo-pages") { var p = pages; Pages.move(.timer, to: .day, in: &p); pages = p }
        if let i = a.firstIndex(of: "--page"), a.indices.contains(i + 1), let k = PageKind(rawValue: a[i + 1]) { page = k }
        #endif
    }

    /// One-time move of the old theme rows (order and visibility) into widgets; new kinds are appended.
    /// Re-resolve Auto when Low Power Mode turns on or off.
    private var powerObserver: NSObjectProtocol?
    func observePowerState() {
        guard powerObserver == nil else { return }
        powerObserver = NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.powerStateRevision &+= 1 }
        }
    }

    private static func migratedWidgets(from theme: Theme) -> [WidgetSetting] {
        theme.rows.compactMap { r in WidgetKind(rawValue: r.kind.rawValue).map { WidgetSetting(kind: $0, enabled: r.visible) } }
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
    private func savePages() {
        guard persistsPages, let data = try? JSONEncoder().encode(pages) else { return }
        d.set(data, forKey: "pages")
    }
}
