import AppKit
import SwiftUI

/// A real macOS settings window (docs/design.md §11): sidebar sections, grouped forms, native controls, live changes.
/// While it's open, the notch stays open as a live preview (toggle in Theme).
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
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.toolbarStyle = .unified
            w.setContentSize(NSSize(width: 760, height: 560))
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

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General", theme = "Theme", typography = "Typography", colours = "Colours", surface = "Surface and shape",
         layout = "Layout", motion = "Motion", screenshots = "Screenshots", accounts = "AI accounts", about = "About"
    var id: String { rawValue }
    /// Shown to everyone. The rest (look and motion) appear with "Show advanced settings".
    static let essentials: [SettingsSection] = [.general, .layout, .screenshots, .accounts, .about]
    static let advanced: [SettingsSection] = [.theme, .typography, .colours, .surface, .motion]
    var isAdvanced: Bool { Self.advanced.contains(self) }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .theme: "swatchpalette"
        case .typography: "textformat"
        case .colours: "paintpalette"
        case .surface: "square.on.square"
        case .layout: "rectangle.grid.1x2"
        case .motion: "wind"
        case .screenshots: "camera.viewfinder"
        case .accounts: "person.crop.circle"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var accounts: AIAccounts
    @ObservedObject private var settings = AppSettings.shared
    @State private var section: SettingsSection? = SettingsView.initialSection
    /// Debug builds: `--settings-pane <Name>` opens that pane (for screenshots).
    private static var initialSection: SettingsSection {
        #if DEBUG
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "--settings-pane"), a.indices.contains(i + 1),
           let s = SettingsSection.allCases.first(where: { $0.rawValue.lowercased().hasPrefix(a[i + 1].lowercased()) }) { return s }
        #endif
        return .general
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                // Always a section, so the list keeps the same top inset when the advanced group appears.
                Section { ForEach(SettingsSection.essentials) { s in Label(s.rawValue, systemImage: s.symbol).tag(s) } }
                if settings.showAdvanced {
                    Section("Appearance") {
                        ForEach(SettingsSection.advanced) { s in Label(s.rawValue, systemImage: s.symbol).tag(s) }
                    }
                }
            }
            .navigationSplitViewColumnWidth(200)
            .onChange(of: settings.showAdvanced) { _, on in
                if !on, section?.isAdvanced == true { section = .general }
            }
        } detail: {
            Group {
                switch section ?? .general {
                case .general: GeneralPane()
                case .theme: ThemePane()
                case .typography: TypographyPane()
                case .colours: ColoursPane()
                case .surface: SurfacePane()
                case .layout: LayoutPane()
                case .motion: MotionPane()
                case .screenshots: ScreenshotsPane()
                case .accounts: AccountsPane(accounts: accounts)
                case .about: AboutPane()
                }
            }
            .formStyle(.grouped)
            .navigationTitle((section ?? .general).rawValue)
        }
        .frame(minWidth: 700, minHeight: 500)
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
        VStack(spacing: 8) {
            card.id(s.themeRevision)
            HStack {
                Text("Preview").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if replayable {
                    Button("Replay") {
                        shown = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { shown = true }
                    }
                    .buttonStyle(.borderless).controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var card: some View {
        let width = min(CGFloat(s.theme.width), 440)
        return VStack(alignment: .leading, spacing: Tok.s2) {
            HStack {
                Text(Date(), format: .dateTime.hour().minute()).font(Tok.digits).foregroundStyle(Tok.ink2)
                Spacer()
                Image(systemName: "gearshape").font(Tok.buttonIcon).foregroundStyle(Tok.ink)
            }
            .frame(height: 28)
            .blurReveal(shown, delay: 0.03)
            HStack(spacing: Tok.s3) {
                ZStack {
                    Tok.raised
                    Image(systemName: "music.note").font(.system(size: 20, weight: .medium)).foregroundStyle(Tok.ink2)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 48 * 0.22, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Track title").font(Tok.rowTitle).foregroundStyle(Tok.ink)
                    StatusLine(text: "Playing · Artist", live: true)
                }
                Spacer(minLength: 0)
            }
            .blurReveal(shown, delay: 0.05)
            HStack(spacing: Tok.s2) {
                Text("1:12").font(Tok.digits).foregroundStyle(Tok.ink3)
                ZStack(alignment: .leading) {
                    Capsule().fill(Tok.ink.opacity(0.14))
                    GeometryReader { g in Capsule().fill(Tok.ink).frame(width: g.size.width * 0.4) }
                }
                .frame(height: 3)
                Text("-1:48").font(Tok.digits).foregroundStyle(Tok.ink3)
            }
            .blurReveal(shown, delay: 0.075)
        }
        .padding(.horizontal, Tok.rOpenEar + Tok.s4)
        .padding(.top, Tok.s2)
        .padding(.bottom, Tok.s4)
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
        Form {
            Section {
                SliderRow(title: "Open after hovering", value: $s.openDelay, range: 0...1, step: 0.05, format: ms)
                SliderRow(title: "Close after leaving", value: $s.closeDelay, range: 0...1, step: 0.05, format: ms)
            } header: {
                ResetHeader(title: "Hover", isDefault: s.hoverIsDefault) { s.resetHover() }
            }
            Section {
                Toggle("Haptics", isOn: $s.haptics)
            } header: {
                ResetHeader(title: "Feel", isDefault: s.haptics) { s.haptics = true }
            } footer: {
                Text("Felt on Force Touch trackpads while your finger rests on them.").foregroundStyle(.secondary)
            }
            Section {
                Toggle("Keep the notch open while Settings is open", isOn: $s.previewWhileEditing)
                Toggle("Show advanced settings", isOn: $s.showAdvanced)
            } header: {
                ResetHeader(title: "Settings", isDefault: s.previewWhileEditing && !s.showAdvanced) {
                    s.previewWhileEditing = true; s.showAdvanced = false
                }
            } footer: {
                Text("Advanced settings add theme, typography, colours, surface and motion.").foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }
}

private struct ThemePane: View {
    @ObservedObject var s = AppSettings.shared
    @State private var newName = ""
    @State private var importError: String?
    var body: some View {
        Form {
            Section { NotchPreview() }
            Section("Presets") {
                ForEach(Theme.presets, id: \.name) { themeRow($0, deletable: false) }
            }
            if !s.savedThemes.isEmpty {
                Section("Your themes") {
                    ForEach(s.savedThemes, id: \.name) { themeRow($0, deletable: true) }
                }
            }
            Section {
                LabeledContent("Save as") {
                    HStack(spacing: 12) {
                        TextField("Theme name", text: $newName, prompt: Text("Theme name")).labelsHidden()
                        Button("Save") { s.saveCurrentTheme(as: newName); newName = "" }
                    }
                    .frame(width: controlWidth)
                }
                LabeledContent("File") {
                    HStack(spacing: 12) {
                        Button("Import…") { importError = s.importTheme() }
                        Button("Export…") { s.exportTheme() }
                    }
                }
                if let importError { Text(importError).foregroundStyle(.red) }
            } header: {
                ResetHeader(title: "Current: \(s.theme.name)", isDefault: s.theme == s.themeBase) {
                    var t = s.themeBase; t.rows = s.theme.rows; s.theme = t
                }
            } footer: {
                Text("Applying a theme changes the look; your rows stay as they are.").foregroundStyle(.secondary)
            }
        }
    }

    private func themeRow(_ t: Theme, deletable: Bool) -> some View {
        LabeledContent {
            HStack(spacing: 12) {
                if s.theme.name == t.name {
                    Image(systemName: "checkmark").foregroundStyle(.secondary).accessibilityLabel("In use")
                } else {
                    Button("Use") { s.apply(t) }
                }
                if deletable { Button("Delete") { s.deleteSavedTheme(named: t.name) } }
            }
        } label: {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: t.accent)).frame(width: 10, height: 10).accessibilityHidden(true)
                Text(t.name)
                Text("\(t.uiFont == "System" ? "SF Pro" : t.uiFont) · \(t.background.name) · \(t.density.name)")
                    .foregroundStyle(.secondary)
            }
        }
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
        Form {
            Section { NotchPreview() }
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
        Form {
            Section { NotchPreview() }
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
        Form {
            Section { NotchPreview() }
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
        Form {
            Section {
                SliderRow(title: "Width", value: bind(\.width), range: 360...560, step: 10) { "\(Int($0)) pt" }
                SegmentedRow(title: "Density", selection: bind(\.density), options: Theme.Density.allCases) { $0.name }
            } header: {
                ResetHeader(title: "Open notch", isDefault: s.themeIsDefault(.openNotch)) { s.resetTheme(.openNotch) }
            }
            Section {
                ForEach(Array(s.theme.rows.enumerated()), id: \.element.id) { index, row in
                    LabeledContent(row.kind.name) {
                        HStack(spacing: 4) {
                            Button { move(index, by: -1) } label: { Image(systemName: "chevron.up") }
                                .buttonStyle(.borderless).disabled(index == 0)
                                .accessibilityLabel("Move \(row.kind.name) up").help("Move up")
                            Button { move(index, by: 1) } label: { Image(systemName: "chevron.down") }
                                .buttonStyle(.borderless).disabled(index == s.theme.rows.count - 1)
                                .accessibilityLabel("Move \(row.kind.name) down").help("Move down")
                            Toggle(row.kind.name, isOn: Binding(get: { s.theme.rows[index].visible },
                                                                set: { s.theme.rows[index].visible = $0 }))
                                .labelsHidden().padding(.leading, 8)
                        }
                    }
                }
            } header: {
                ResetHeader(title: "Rows", isDefault: s.themeIsDefault(.rows)) { s.resetTheme(.rows) }
            } footer: {
                Text("Last screenshot appears only after Belay copies one.").foregroundStyle(.secondary)
            }
            Section {
                Picker("While music plays", selection: $s.musicActivity) {
                    ForEach(AppSettings.MusicActivity.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.menu)
                Toggle("Music bars follow the beat", isOn: $s.equalizerWhilePlaying)
                Toggle("Charging", isOn: $s.alertCharging)
                Toggle("Low battery", isOn: $s.alertLowBattery)
                Toggle("Wi-Fi connected or lost", isOn: $s.alertWifi)
            } header: {
                ResetHeader(title: "Live activities", isDefault: s.liveActivitiesAreDefault) { s.resetLiveActivities() }
            }
            Section {
                SegmentedRow(title: "Size", selection: $s.closedStyle, options: AppSettings.ClosedStyle.allCases) { $0.name }
                if s.closedStyle == .withInfo {
                    Picker("Left of the camera", selection: $s.leftWing) {
                        ForEach(AppSettings.Wing.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Picker("Right of the camera", selection: $s.rightWing) {
                        ForEach(AppSettings.Wing.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                ResetHeader(title: "Closed notch", isDefault: s.closedNotchIsDefault) { s.resetClosedNotch() }
            }
        }
        .toggleStyle(.switch)
    }

    private func move(_ i: Int, by d: Int) {
        let j = i + d
        guard s.theme.rows.indices.contains(j) else { return }
        s.theme.rows.swapAt(i, j)
    }
}

private struct MotionPane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Form {
            Section { NotchPreview(replayable: true) }
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

private struct ScreenshotsPane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Form {
            Section {
                Toggle("Copy new screenshots to the clipboard", isOn: $s.screenshotAutoCopy)
            } header: {
                ResetHeader(title: "Auto-copy", isDefault: s.screenshotAutoCopy) { s.screenshotAutoCopy = true }
            } footer: {
                Text("Works wherever macOS saves your screenshots. The file is kept.").foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }
}

private struct AccountsPane: View {
    @ObservedObject var accounts: AIAccounts
    var body: some View {
        Form {
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

private struct AboutPane: View {
    var body: some View {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        Form {
            Section {
                LabeledContent("Version", value: "\(v) (\(b))")
                LabeledContent("Licence", value: "MIT")
                LabeledContent("Built on", value: "Perch, Clicky, Avo, OpenMausBot")
            }
        }
    }
}
