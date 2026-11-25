import AppKit
import SwiftUI

/// Belay's settings (docs/design.md §11): five tabs in a pill bar, grouped forms, native controls, live changes.
/// While it's open, the notch stays open as a live preview (General → Settings).
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let accounts = AIAccounts()
    var onShow: () -> Void = {}
    var onClose: () -> Void = {}

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(accounts: accounts))
            let w = NSWindow(contentViewController: host)
            w.title = "Belay Settings"
            w.titleVisibility = .hidden
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.isMovableByWindowBackground = true
            w.setContentSize(NSSize(width: 640, height: 620))
            w.contentMinSize = NSSize(width: 640, height: 480)
            w.isReleasedWhenClosed = false
            w.isRestorable = false
            w.delegate = self
            w.center()
            // Sit below the open notch so the live preview never covers Settings.
            if let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main {
                let vf = screen.visibleFrame
                var f = w.frame
                f.origin.y = max(vf.minY + 20, vf.maxY - 340 - f.height)
                w.setFrame(f, display: false)
            }
            window = w
        }
        accounts.refresh()
        // The user asked for Settings, so taking focus is right. A dock-less app may be refused activation by macOS 14's
        // cooperative activation, so also order the window front explicitly.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        onShow()
    }

    func windowWillClose(_ notification: Notification) { onClose() }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General", widgets = "Widgets", appearance = "Appearance", agents = "Agents", about = "About"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .widgets: "square.grid.2x2"
        case .appearance: "paintbrush"
        case .agents: "terminal"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var accounts: AIAccounts
    @State private var tab: SettingsTab = SettingsView.initialTab
    /// Debug builds: `--settings-pane <name>` opens that tab (for screenshots).
    private static var initialTab: SettingsTab {
        #if DEBUG
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "--settings-pane"), a.indices.contains(i + 1),
           let t = SettingsTab.allCases.first(where: { $0.rawValue.lowercased().hasPrefix(a[i + 1].lowercased()) }) { return t }
        #endif
        return .general
    }

    var body: some View {
        VStack(spacing: 0) {
            PillTabs(selection: $tab)
                .padding(.top, 12)
                .padding(.bottom, 4)
            Group {
                switch tab {
                case .general: Form { GeneralPane() }
                case .widgets: Form { WidgetsPane() }
                case .appearance: AppearancePane()
                case .agents: Form { AccountsPane(accounts: accounts) }
                case .about: Form { AboutPane() }
                }
            }
            .formStyle(.grouped)
            .toggleStyle(.switch)
            .transition(.opacity)
            .id(tab)
        }
        .animation(.easeOut(duration: 0.15), value: tab)
        .frame(minWidth: 640, minHeight: 480)
    }
}

/// The tab bar: a quiet capsule track with the selected tab as a solid, inverted pill that slides between tabs
/// (dusk-feel §2). Keyboard: ⌘1…⌘5.
private struct PillTabs: View {
    @Binding var selection: SettingsTab
    @Namespace private var pill
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(SettingsTab.allCases.enumerated()), id: \.element) { index, t in
                let on = selection == t
                Button {
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.28)) { selection = t }
                } label: {
                    Label(t.rawValue, systemImage: t.symbol)
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(on ? Color(nsColor: .windowBackgroundColor) : Color.secondary)
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background {
                            if on { Capsule().fill(Color.primary).matchedGeometryEffect(id: "pill", in: pill) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }
}

/// Binding into a field of the active theme.
/// Writes only when the value really changed: controls that echo their value back on render (sliders snapping to a
/// step, colour pickers converting colour spaces) must not trigger endless theme updates.
@MainActor private func bind<V: Equatable>(_ kp: WritableKeyPath<Theme, V>) -> Binding<V> {
    Binding(get: { AppSettings.shared.theme[keyPath: kp] },
            set: { if AppSettings.shared.theme[keyPath: kp] != $0 { AppSettings.shared.theme[keyPath: kp] = $0 } })
}

@MainActor private func colour(_ kp: WritableKeyPath<Theme, String>) -> Binding<Color> {
    Binding(get: { Color(hex: AppSettings.shared.theme[keyPath: kp]) },
            set: { let hex = $0.hex; if AppSettings.shared.theme[keyPath: kp] != hex { AppSettings.shared.theme[keyPath: kp] = hex } })
}

// MARK: - Shared rows (docs/design.md §11): every pane uses these, so labels, values and controls line up.

/// Width of the control column for sliders and segmented controls, so they line up across panes.
private let controlWidth: CGFloat = 300
private let valueWidth: CGFloat = 64

/// [label] … [slider][value with units, right-aligned]. The one control for every number in Settings.
private struct SliderRow: View {
    let title: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    var step: Double = 0.01
    let format: (Double) -> String
    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 12) {
                // Snap in the binding rather than with `step:`, which draws a tick per step (noisy at fine steps).
                Slider(value: Binding(get: { value.wrappedValue },
                                      set: { value.wrappedValue = min(range.upperBound, max(range.lowerBound, ($0 / step).rounded() * step)) }),
                       in: range)
                    .labelsHidden()
                Text(format(value.wrappedValue)).monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: valueWidth, alignment: .trailing)
            }
            .frame(width: controlWidth)
        }
    }
}

/// [label] … [segmented control], same column width as sliders.
private struct SegmentedRow<V: Hashable & Identifiable>: View {
    let title: String
    let selection: Binding<V>
    let options: [V]
    let name: (V) -> String
    var body: some View {
        LabeledContent(title) {
            Picker(title, selection: selection) {
                ForEach(options) { Text(name($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .frame(width: controlWidth, alignment: .trailing)
        }
    }
}

/// A section header with a reset on the right. The reset only shows when the section differs from its default.
private struct ResetHeader: View {
    let title: String
    let isDefault: Bool
    let reset: () -> Void
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button("Reset", action: reset)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .opacity(isDefault ? 0 : 1)
                .disabled(isDefault)
                .accessibilityLabel("Reset \(title.lowercased())")
                .help("Reset \(title.lowercased()) to the theme's values")
        }
    }
}

private func ms(_ s: Double) -> String { s < 0.025 ? "Instant" : "\(Int((s * 1000).rounded())) ms" }
private func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }

/// A live, to-scale sample of the open notch, drawn with the current theme's tokens. It shows sample content, so it's
/// labelled as a preview; the real notch also stays open while Settings is open (General).
private struct NotchPreview: View {
    @ObservedObject var s = AppSettings.shared
    var replayable = false
    @State private var shown = true

    var body: some View {
        card.id(s.themeRevision)
            .overlay(alignment: .bottomTrailing) {
                if replayable {
                    Button("Replay") {
                        shown = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { shown = true }
                    }
                    .buttonStyle(.borderless).controlSize(.small)
                    .offset(y: 22)
                }
            }
            .padding(.vertical, 4)
            .accessibilityHint("A preview of the open notch with sample content")
    }

    private var card: some View {
        let width = min(CGFloat(s.theme.width), 440)
        return VStack(alignment: .leading, spacing: Tok.s2) {
            HStack(spacing: 0) {
                BrandSlot()
                Spacer()
                Image(systemName: "square.grid.2x2").font(Tok.buttonIcon).foregroundStyle(Tok.ink).frame(width: Tok.button)
                Image(systemName: "gearshape").font(Tok.buttonIcon).foregroundStyle(Tok.ink).frame(width: Tok.button)
            }
            .frame(height: 28)
            .blurReveal(shown, delay: 0.03)
            HStack(spacing: Tok.s3) {
                ZStack {
                    Tok.raised
                    Image(systemName: "music.note").font(.system(size: 20, weight: .medium)).foregroundStyle(Tok.ink2)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 56 * 0.22, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Track title").font(Tok.rowTitle).foregroundStyle(Tok.ink)
                    Text("Artist").font(Tok.meta).foregroundStyle(Tok.ink2)
                    Spacer(minLength: Tok.s1)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Tok.ink.opacity(0.14))
                        GeometryReader { g in Capsule().fill(Tok.ink).frame(width: g.size.width * 0.4) }
                    }
                    .frame(height: 3)
                }
                .frame(height: 56)
                Image(systemName: "pause.fill").font(Tok.buttonIcon).foregroundStyle(Tok.ink)
            }
            .card()
            .blurReveal(shown, delay: 0.05)
        }
        .padding(.horizontal, Tok.s2)
        .padding(.top, Tok.s1)
        .padding(.bottom, Tok.s2)
        .padding(.horizontal, Tok.rOpenEar)
        .frame(width: width)
        .background {
            let shape = NotchShape(earRadius: Tok.rOpenEar, bottomRadius: Tok.rOpenBottom)
            ZStack {
                if Tok.isGlass { Rectangle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark) }
                Tok.notch.opacity(Tok.isGlass ? Tok.glassTint : 1)
            }
            .clipShape(shape)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Notch preview")
    }
}

// MARK: - Panes

private struct GeneralPane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Group {
            Section {
                Picker("Open with", selection: $s.openOnClick) {
                    Text("Hover").tag(false)
                    Text("Click").tag(true)
                }
                .pickerStyle(.segmented)
                if !s.openOnClick {
                    SliderRow(title: "Open after hovering", value: $s.openDelay, range: 0...1, step: 0.05, format: ms)
                }
                SliderRow(title: "Close after leaving", value: $s.closeDelay, range: 0...1, step: 0.05, format: ms)
                Toggle("Haptic tick on open", isOn: $s.haptics)
            } header: {
                ResetHeader(title: "Notch", isDefault: s.hoverIsDefault && s.haptics) { s.resetHover(); s.haptics = true }
            } footer: {
                Text("The tick is felt on Force Touch trackpads when the notch opens under your finger. Clicks never buzz.")
                    .foregroundStyle(.secondary)
            }
            Section {
                SegmentedRow(title: "Mode", selection: $s.performanceMode, options: AppSettings.PerformanceMode.allCases) { $0.name }
                LiveCost()
            } header: {
                ResetHeader(title: "Performance", isDefault: s.performanceMode == .auto) { s.performanceMode = .auto }
            } footer: {
                Text(performanceFooter).foregroundStyle(.secondary)
            }
            Section {
                Picker("While music plays", selection: $s.musicActivity) {
                    ForEach(AppSettings.MusicActivity.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.menu)
                Toggle("Music bars follow the beat", isOn: $s.equalizerWhilePlaying)
                Toggle("Low battery", isOn: $s.alertLowBattery)
                Toggle("Internet lost or back", isOn: $s.alertWifi)
                Toggle("Timer", isOn: $s.timerActivity)
                Toggle("Stopwatch", isOn: $s.stopwatchActivity)
                Toggle("Upcoming events", isOn: $s.upcomingActivity)
            } header: {
                ResetHeader(title: "Live activities", isDefault: s.liveActivitiesAreDefault) { s.resetLiveActivities() }
            } footer: {
                Text("Moments that grow out of the closed notch, then get out of the way.").foregroundStyle(.secondary)
            }
            Section {
                Toggle("Copy new screenshots to the clipboard", isOn: $s.screenshotAutoCopy)
            } header: {
                ResetHeader(title: "Screenshots", isDefault: s.screenshotAutoCopy) { s.screenshotAutoCopy = true }
            } footer: {
                Text("Works wherever macOS saves your screenshots. The file is kept.").foregroundStyle(.secondary)
            }
            StartupSection()
            Section {
                Toggle("Keep the notch open while Settings is open", isOn: $s.previewWhileEditing)
            } header: {
                ResetHeader(title: "Settings", isDefault: s.previewWhileEditing) { s.previewWhileEditing = true }
            }
        }
    }
}

private extension GeneralPane {
    var performanceFooter: String {
        let p = s.performance
        let now = "Now: animation up to \(Int(p.maxFPS)) fps, blur \(p.blur ? "on" : "off")."
        switch s.performanceMode {
        case .auto: return "Smoothest normally; saves energy in Low Power Mode. " + now
        case .efficient: return "Caps animation at 30 fps and turns blur off. " + now
        case .smooth: return "Animation at your display's full rate. " + now
        }
    }
}

/// Open at login. Reads the real state from macOS each time the pane appears; never stores its own copy.
private struct StartupSection: View {
    @State private var on = LoginItem.isOn
    @State private var approval = LoginItem.needsApproval
    @State private var error: String?
    var body: some View {
        Section {
            Toggle("Open Belay at login", isOn: Binding(get: { on }, set: { want in
                error = LoginItem.set(want)
                on = LoginItem.isOn; approval = LoginItem.needsApproval
            }))
            if approval {
                LabeledContent("Needs your OK in System Settings") {
                    Button("Open Login Items…") { LoginItem.openSystemSettings() }
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
        } header: {
            Text("Startup")
        }
        .onAppear { on = LoginItem.isOn; approval = LoginItem.needsApproval }
    }
}

/// Belay's own CPU and memory, refreshed every 2 s while this row is on screen.
private struct LiveCost: View {
    @State private var last = ProcessStats.sample()
    @State private var text = "Measuring…"
    var body: some View {
        LabeledContent("Belay right now") {
            Text(text).monospacedDigit().foregroundStyle(.secondary)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                let now = ProcessStats.sample()
                let cpu = ProcessStats.cpuPercent(from: last, to: now)
                last = now
                let mb = Double(ProcessStats.memoryFootprint()) / 1_048_576
                text = String(format: "%.1f%% CPU · %.0f MB", cpu, mb)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Everything about the look: a live preview that stays put, themes as swatches, then one switcher for the rest.
private struct AppearancePane: View {
    enum Part: String, CaseIterable, Identifiable {
        case layout = "Layout", type = "Type", colour = "Colour", surface = "Surface", motion = "Motion"
        var id: String { rawValue }
    }
    @ObservedObject var s = AppSettings.shared
    @State private var part: Part = .layout

    var body: some View {
        VStack(spacing: 0) {
            NotchPreview(replayable: part == .motion)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            Form {
                ThemePane()
                Section {
                    Picker("Customize", selection: $part) {
                        ForEach(Part.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                switch part {
                case .layout: LayoutPane()
                case .type: TypographyPane()
                case .colour: ColoursPane()
                case .surface: SurfacePane()
                case .motion: MotionPane()
                }
            }
            .formStyle(.grouped)
        }
    }
}

private struct ThemePane: View {
    @ObservedObject var s = AppSettings.shared
    @State private var newName = ""
    @State private var importError: String?
    var body: some View {
        Group {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Theme.presets + s.savedThemes, id: \.name) { t in
                            ThemeSwatch(theme: t, selected: s.theme.name == t.name) { s.apply(t) }
                                .contextMenu {
                                    if s.savedThemes.contains(where: { $0.name == t.name }) {
                                        Button("Delete \(t.name)") { s.deleteSavedTheme(named: t.name) }
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                ResetHeader(title: "Theme", isDefault: s.theme == s.themeBase) { s.theme = s.themeBase }
            }
            Section {
                LabeledContent("Save current as") {
                    HStack(spacing: 8) {
                        TextField("Theme name", text: $newName, prompt: Text("My theme")).labelsHidden()
                        Button("Save") { s.saveCurrentTheme(as: newName); newName = "" }
                    }
                    .frame(width: controlWidth)
                }
                LabeledContent("Share") {
                    HStack(spacing: 8) {
                        Button("Import…") { importError = s.importTheme() }
                        Button("Export…") { s.exportTheme() }
                    }
                }
                if let importError { Text(importError).foregroundStyle(.red) }
            }
        }
    }
}

/// A theme as a tiny open notch in its own colours and face. Click to use it.
private struct ThemeSwatch: View {
    let theme: Theme
    let selected: Bool
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topLeading) {
                    if theme.background == .glass {
                        RoundedRectangle(cornerRadius: 10 * theme.roundness, style: .continuous)
                            .fill(LinearGradient(colors: [Color(white: 0.32), Color(white: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        RoundedRectangle(cornerRadius: 10 * theme.roundness, style: .continuous)
                            .fill(Color(hex: theme.backgroundColor).opacity(theme.glassTint))
                    } else {
                        RoundedRectangle(cornerRadius: 10 * theme.roundness, style: .continuous)
                            .fill(Color(hex: theme.backgroundColor))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 5 * theme.roundness, style: .continuous)
                            .fill(Color(hex: theme.ink).opacity(0.08))
                            .frame(height: 22)
                            .overlay(alignment: .leading) {
                                HStack(spacing: 4) {
                                    Text("Aa").font(fontSample(theme.uiFont, size: 10 * theme.textScale).weight(.semibold))
                                        .foregroundStyle(Color(hex: theme.ink))
                                    Capsule().fill(Color(hex: theme.live)).frame(width: 14, height: 3)
                                }
                                .padding(.horizontal, 6)
                            }
                        Capsule().fill(Color(hex: theme.ink).opacity(theme.ink3Opacity)).frame(width: 40, height: 3)
                    }
                    .padding(8)
                }
                .frame(width: 104, height: 58)
                .overlay {
                    RoundedRectangle(cornerRadius: 10 * theme.roundness + 3, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(hover ? 0.25 : 0.0), lineWidth: 2)
                        .padding(-3)
                }
                Text(theme.name).font(.system(size: 11, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
        .accessibilityLabel("\(theme.name) theme")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A font family name rendered in its own face (falls back to the system face if it can't be loaded).
private func fontSample(_ family: String, size: CGFloat = 13) -> Font {
    switch family {
    case "System": .system(size: size)
    case "System Mono": .system(size: size, design: .monospaced)
    default: .custom(family, size: size)
    }
}

private struct TypographyPane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Group {
            Section {
                Picker("Interface font", selection: bind(\.uiFont)) {
                    ForEach(InstalledFonts.all, id: \.self) { f in
                        Text(f == "System" ? "System (SF Pro)" : f).font(fontSample(f)).tag(f)
                    }
                }
                .pickerStyle(.menu)
                sample("Track title and labels", family: s.theme.uiFont)
                Picker("Status and numbers font", selection: bind(\.monoFont)) {
                    ForEach(InstalledFonts.mono, id: \.self) { f in
                        Text(f == "System Mono" ? "System (SF Mono)" : f).font(fontSample(f)).tag(f)
                    }
                }
                .pickerStyle(.menu)
                sample("PLAYING · 12:45 · 80%", family: s.theme.monoFont)
                SliderRow(title: "Text size", value: bind(\.textScale), range: 0.85...1.3, format: percent)
            } header: {
                ResetHeader(title: "Fonts", isDefault: s.themeIsDefault(.fonts)) { s.resetTheme(.fonts) }
            }
            Section {
                Toggle("Uppercase", isOn: bind(\.statusUppercase))
                SliderRow(title: "Letter spacing", value: bind(\.statusTracking), range: 0...2, step: 0.1) { String(format: "%.1f pt", $0) }
            } header: {
                ResetHeader(title: "Status lines", isDefault: s.themeIsDefault(.statusLines)) { s.resetTheme(.statusLines) }
            }
        }
        .toggleStyle(.switch)
    }

    /// The chosen face, live, right under its picker.
    private func sample(_ text: String, family: String) -> some View {
        LabeledContent("Sample") {
            Text(text).font(fontSample(family)).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}

private struct ColoursPane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Group {
            Section {
                ColorPicker("Text colour", selection: colour(\.ink), supportsOpacity: false)
                SliderRow(title: "Secondary text", value: bind(\.ink2Opacity), range: 0.4...0.9, format: percent)
                SliderRow(title: "Tertiary text", value: bind(\.ink3Opacity), range: 0.25...0.7, format: percent)
            } header: {
                ResetHeader(title: "Text", isDefault: s.themeIsDefault(.text)) { s.resetTheme(.text) }
            }
            Section {
                ColorPicker("Accent", selection: colour(\.accent), supportsOpacity: false)
                ColorPicker("Live", selection: colour(\.live), supportsOpacity: false)
            } header: {
                ResetHeader(title: "Accent and live", isDefault: s.themeIsDefault(.accents)) { s.resetTheme(.accents) }
            } footer: {
                Text("Accent marks selection and sliders. Live marks things running right now, such as playing.").foregroundStyle(.secondary)
            }
        }
    }
}

private struct SurfacePane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Group {
            Section {
                SegmentedRow(title: "Open notch", selection: bind(\.background), options: Theme.Background.allCases) { $0.name }
                ColorPicker("Colour", selection: colour(\.backgroundColor), supportsOpacity: false)
                if s.theme.background == .glass {
                    SliderRow(title: "Glass tint", value: bind(\.glassTint), range: 0...0.9, format: percent)
                }
                SliderRow(title: "Shadow", value: bind(\.shadow), range: 0...1, format: percent)
            } header: {
                ResetHeader(title: "Surface", isDefault: s.themeIsDefault(.surface)) { s.resetTheme(.surface) }
            } footer: {
                Text("The closed notch always stays solid so it blends with the camera housing.").foregroundStyle(.secondary)
            }
            Section {
                SliderRow(title: "Roundness", value: bind(\.roundness), range: 0.5...1.6, format: percent)
            } header: {
                ResetHeader(title: "Shape", isDefault: s.themeIsDefault(.shape)) { s.resetTheme(.shape) }
            }
        }
    }
}

private struct LayoutPane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Section {
            SliderRow(title: "Width", value: bind(\.width), range: 360...560, step: 10) { "\(Int($0)) pt" }
            SegmentedRow(title: "Density", selection: bind(\.density), options: Theme.Density.allCases) { $0.name }
        } header: {
            ResetHeader(title: "Open notch", isDefault: s.themeIsDefault(.openNotch)) { s.resetTheme(.openNotch) }
        }
    }
}

/// What the open notch shows (ADR 0021): which pages, in what order, and each page's widgets. Changes apply live.
private struct WidgetsPane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Group {
            Section {
                List {
                    ForEach(s.pages) { p in
                        HStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary).accessibilityHidden(true)
                            Label(p.kind.name, systemImage: p.kind.symbol)
                            Spacer()
                            Toggle(p.kind.name, isOn: Binding(get: { p.enabled }, set: { s.setPageEnabled(p.kind, $0) })).labelsHidden()
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove { s.movePages(from: $0, to: $1) }
                }
                .frame(height: CGFloat(s.pages.count) * 34 + 8)
                .scrollDisabled(true)
            } header: {
                ResetHeader(title: "Pages", isDefault: s.widgetsAreDefault) { s.resetWidgets() }
            } footer: {
                Text("Swipe with two fingers in the notch to change page. A page with nothing to show is skipped. Each widget has a size: small is one column, wide is two, full is a whole row. The notch has two columns, or three when expanded. Widgets stay as you arrange them.")
                    .foregroundStyle(.secondary)
            }
            ClockZonesSection()
            WeatherSection()
            Section {
                Toggle("Capture shortcut ⌃⌥N", isOn: $s.notesShortcut)
                if s.notesShortcut && s.notesShortcutTaken { Text("⌃⌥N is taken by another app.").foregroundStyle(Tok.warning) }
            } header: { Text("Notes") } footer: {
                Text("Opens the notch on Notes with the field ready. Needs no extra permission. Notes stay on this Mac.").foregroundStyle(.secondary)
            }
            ForEach(s.pages) { page in
                Section(page.kind.name) {
                    if page.widgets.isEmpty {
                        Text("No widgets. Move one here with its Page menu.").foregroundStyle(.secondary)
                    } else {
                        List {
                            ForEach(page.widgets) { w in
                                HStack(spacing: 10) {
                                    Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary).accessibilityHidden(true)
                                    Label(w.kind.name, systemImage: w.kind.symbol)
                                    Spacer()
                                    Menu {
                                        ForEach(w.kind.spans) { span in
                                            Button(span.name) { s.setSpan(w.kind, span) }.disabled(span == w.span)
                                        }
                                    } label: { Text(w.span.name) }
                                    .menuStyle(.borderlessButton).fixedSize()
                                    .accessibilityLabel("Size of \(w.kind.name)")
                                    Menu {
                                        ForEach(PageKind.allCases) { other in
                                            Button(other.name) { s.moveWidget(w.kind, to: other, enabled: w.enabled) }.disabled(other == page.kind)
                                        }
                                    } label: { Text(page.kind.name) }
                                    .menuStyle(.borderlessButton).fixedSize()
                                    .accessibilityLabel("Page for \(w.kind.name)")
                                    Toggle(w.kind.name, isOn: Binding(get: { w.enabled }, set: { s.setEnabled(w.kind, $0) })).labelsHidden()
                                }
                                .padding(.vertical, 2)
                            }
                            .onMove { s.moveWidgets(on: page.kind, from: $0, to: $1) }
                        }
                        .frame(height: CGFloat(page.widgets.count) * 34 + 8)
                        .scrollDisabled(true)
                    }
                }
            }
        }
        .toggleStyle(.switch)
    }
}

/// Weather → city (typed and searched, never Location) and units.
private struct WeatherSection: View {
    @ObservedObject var s = AppSettings.shared
    @State private var query = ""
    @State private var results: [WeatherCity] = []
    @State private var failed = false
    var body: some View {
        Section {
            if let c = s.weatherCity {
                HStack {
                    Text(c.label)
                    Spacer()
                    Button { s.weatherCity = nil } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless).accessibilityLabel("Remove \(c.name)")
                }
            }
            TextField(s.weatherCity == nil ? "Search for a city" : "Change city", text: $query)
                .task(id: query) {
                    // Debounced 300 ms; fetches only while you type.
                    failed = false
                    guard query.trimmingCharacters(in: .whitespaces).count >= 2 else { results = []; return }
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    if let r = await WeatherService.shared.search(query) { results = r } else { results = []; failed = true }
                }
            if failed { Text("Couldn't reach Open-Meteo.").foregroundStyle(Tok.warning) }
            ForEach(results, id: \.label) { c in
                Button(c.label) { s.weatherCity = c; query = ""; results = [] }.buttonStyle(.borderless)
            }
            Picker("Units", selection: $s.weatherUnits) { ForEach(WeatherUnits.allCases) { Text($0.name).tag($0) } }
        } header: {
            Text("Weather")
        } footer: {
            Text("Weather data by Open-Meteo.com (CC BY 4.0). Places from GeoNames (CC BY 4.0). Only the city's coordinates are sent; Belay never uses your location.")
                .foregroundStyle(.secondary)
        }
    }
}

/// Clock → other time zones (max 3): search the system's zone list by city, remove, reorder.
private struct ClockZonesSection: View {
    @ObservedObject var s = AppSettings.shared
    @State private var query = ""
    var body: some View {
        Section {
            ForEach(Array(s.clockZones.enumerated()), id: \.element) { i, id in
                HStack {
                    Text(ClockLogic.city(id))
                    Spacer()
                    Button { s.clockZones.swapAt(i, i - 1) } label: { Image(systemName: "chevron.up") }
                        .disabled(i == 0).accessibilityLabel("Move \(ClockLogic.city(id)) up")
                    Button { s.clockZones.remove(at: i) } label: { Image(systemName: "minus.circle") }
                        .accessibilityLabel("Remove \(ClockLogic.city(id))")
                }
                .buttonStyle(.borderless)
            }
            if s.clockZones.count < ClockLogic.maxZones {
                TextField("Add a city", text: $query)
                ForEach(ClockLogic.search(query).filter { !s.clockZones.contains($0) }.prefix(5), id: \.self) { id in
                    Button("\(ClockLogic.city(id)) (\(id))") { s.clockZones.append(id); query = "" }.buttonStyle(.borderless)
                }
            }
        } header: {
            Text("Clock: other time zones")
        } footer: {
            Text("Up to three. With none, the clock is a single large time. 24-hour follows the system.").foregroundStyle(.secondary)
        }
    }
}

private struct MotionPane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Group {
            Section {
                Picker("Motion", selection: bind(\.motion)) {
                    ForEach(Theme.MotionPreference.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.menu)
                SliderRow(title: "Speed", value: bind(\.speed), range: 0.6...1.6) { String(format: "%.1f×", $0) }
                SliderRow(title: "Blur", value: bind(\.blur), range: 0...16, step: 1) { "\(Int($0)) pt" }
                SliderRow(title: "Bounce", value: bind(\.bounce), range: 0...0.3, format: percent)
            } header: {
                ResetHeader(title: "Animation", isDefault: s.themeIsDefault(.motion)) { s.resetTheme(.motion) }
            } footer: {
                Text("Blur softens content as it appears and as text changes. Reduced motion turns blur and bounce off.").foregroundStyle(.secondary)
            }
        }
    }
}

private struct AccountsPane: View {
    @ObservedObject var accounts: AIAccounts
    var body: some View {
        Group {
            Section {
                ForEach(accounts.clis) { cli in
                    LabeledContent(cli.name) {
                        if !cli.checked { ProgressView().controlSize(.small) }
                        else if let v = cli.version { Text(v).foregroundStyle(.secondary).textSelection(.enabled) }
                        else if cli.path != nil { Text("Installed").foregroundStyle(.secondary) }
                        else { Text("Not found").foregroundStyle(.secondary) }
                    }
                }
            } header: {
                HStack {
                    Text("Command-line agents")
                    Spacer()
                    Button("Check again") { accounts.refresh() }.buttonStyle(.borderless).controlSize(.small)
                }
            } footer: {
                Text("Belay uses the agents you already have, signed in their own way. It never asks for or stores your passwords or tokens.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// beepo, the temporary logo. Hover lifts it, a click blinks, a double-click is a happy hop. Still otherwise.
private struct AboutBuddy: View {
    @State private var buddy = BuddyAnimator()
    var body: some View {
        BuddyView(id: .beepo, mood: buddy.mood, size: 64, hop: buddy.hop)
            .contentShape(Rectangle())
            .onHover { buddy.set($0 ? .hover : .idle) }
            .onTapGesture(count: 2) { buddy.cheer() }
            .onTapGesture { buddy.blink() }
            .help("beepo")
    }
}

private struct AboutPane: View {
    var body: some View {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        Group {
            Section {
                VStack(spacing: 8) {
                    AboutBuddy()
                    Text("Belay").font(.title3.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            Section {
                LabeledContent("Version", value: "\(v) (\(b))")
                LabeledContent("Licence", value: "MIT")
                LabeledContent("Built on", value: "Perch, Clicky, Avo, OpenMausBot")
            }
        }
    }
}
