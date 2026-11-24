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
    @State private var section: SettingsSection? = .general

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

private struct SliderRow: View {
    let title: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    var step: Double = 0.01
    let format: (Double) -> String
    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: range, step: step).frame(maxWidth: 240)
                Text(format(value.wrappedValue)).monospacedDigit().foregroundStyle(.secondary).frame(width: 56, alignment: .trailing)
            }
        }
    }
}

// MARK: - Panes

private func delayLabel(_ s: Double) -> String { s < 0.025 ? "Instant" : "\(Int((s * 1000).rounded())) ms" }

private struct GeneralPane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Form {
            Section {
                SliderRow(title: "Open after hovering", value: $s.openDelay, range: 0...1, step: 0.05) { delayLabel($0) }
                SliderRow(title: "Close after leaving", value: $s.closeDelay, range: 0...1, step: 0.05) { delayLabel($0) }
                Toggle("Haptics", isOn: $s.haptics)
            } footer: {
                Text("Haptics are felt on Force Touch trackpads while your finger rests on them.").foregroundStyle(.secondary)
            }
            Section {
                Toggle("Keep the notch open while Settings is open", isOn: $s.previewWhileEditing)
                Toggle("Show advanced settings", isOn: $s.showAdvanced)
            } footer: {
                Text("Advanced settings add theme, typography, colours, surface and motion.").foregroundStyle(.secondary)
            }
        }
    }
}

private struct ThemePane: View {
    @ObservedObject var s = AppSettings.shared
    @State private var newName = ""
    @State private var importError: String?
    var body: some View {
        Form {
            Section("Presets") {
                ForEach(Theme.presets, id: \.name) { preset in
                    themeRow(preset, deletable: false)
                }
            }
            if !s.savedThemes.isEmpty {
                Section("Your themes") {
                    ForEach(s.savedThemes, id: \.name) { t in themeRow(t, deletable: true) }
                }
            }
            Section("Current · \(s.theme.name)") {
                HStack {
                    TextField("Name", text: $newName, prompt: Text("Theme name"))
                    Button("Save as theme") { s.saveCurrentTheme(as: newName); newName = "" }
                }
                HStack {
                    Button("Export…") { s.exportTheme() }
                    Button("Import…") { importError = s.importTheme() }
                    Spacer()
                    Button("Reset to Midnight") { s.apply(.midnight) }
                }
                if let importError { Text(importError).foregroundStyle(.red) }
            }
        }
    }

    private func themeRow(_ t: Theme, deletable: Bool) -> some View {
        HStack {
            Circle().fill(Color(hex: t.accent)).frame(width: 12, height: 12)
            Text(t.name)
            Text("\(t.uiFont == "System" ? "SF Pro" : t.uiFont) · \(t.background.name) · \(t.density.name)").foregroundStyle(.secondary)
            Spacer()
            if s.theme == t { Image(systemName: "checkmark").foregroundStyle(.secondary) }
            else { Button("Use") { s.apply(t) } }
            if deletable { Button("Delete") { s.deleteSavedTheme(named: t.name) } }
        }
    }
}

private struct TypographyPane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Form {
            Section("Fonts") {
                Picker("Interface font", selection: bind(\.uiFont)) {
                    ForEach(InstalledFonts.all, id: \.self) { Text($0 == "System" ? "System (SF Pro)" : $0).tag($0) }
                }
                Picker("Status and numbers font", selection: bind(\.monoFont)) {
                    ForEach(InstalledFonts.mono, id: \.self) { Text($0 == "System Mono" ? "System (SF Mono)" : $0).tag($0) }
                }
                SliderRow(title: "Text size", value: bind(\.textScale), range: 0.85...1.3) { "\(Int(($0 * 100).rounded()))%" }
            }
            Section("Status lines") {
                Toggle("Uppercase", isOn: bind(\.statusUppercase))
                SliderRow(title: "Letter spacing", value: bind(\.statusTracking), range: 0...2, step: 0.1) { String(format: "%.1f pt", $0) }
            }
        }
    }
}

private struct ColoursPane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Form {
            Section("Text") {
                ColorPicker("Text colour", selection: colour(\.ink), supportsOpacity: false)
                SliderRow(title: "Secondary text", value: bind(\.ink2Opacity), range: 0.4...0.9) { "\(Int(($0 * 100).rounded()))%" }
                SliderRow(title: "Tertiary text", value: bind(\.ink3Opacity), range: 0.25...0.7) { "\(Int(($0 * 100).rounded()))%" }
            }
            Section {
                ColorPicker("Accent", selection: colour(\.accent), supportsOpacity: false)
                ColorPicker("Live (playing, connected)", selection: colour(\.live), supportsOpacity: false)
            } footer: {
                Text("The accent marks selection and sliders. Live marks things that are running right now.").foregroundStyle(.secondary)
            }
        }
    }
}

private struct SurfacePane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Form {
            Section("Surface") {
                Picker("Open notch", selection: bind(\.background)) {
                    ForEach(Theme.Background.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                ColorPicker("Colour", selection: colour(\.backgroundColor), supportsOpacity: false)
                if s.theme.background == .glass {
                    SliderRow(title: "Glass tint", value: bind(\.glassTint), range: 0...0.9) { "\(Int(($0 * 100).rounded()))%" }
                }
                SliderRow(title: "Shadow", value: bind(\.shadow), range: 0...1) { "\(Int(($0 * 100).rounded()))%" }
            }
            Section {
                SliderRow(title: "Roundness", value: bind(\.roundness), range: 0.5...1.6) { "\(Int(($0 * 100).rounded()))%" }
            } footer: {
                Text("The closed notch always stays solid so it blends with the camera housing.").foregroundStyle(.secondary)
            }
        }
    }
}

private struct LayoutPane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Form {
            Section("Open notch") {
                SliderRow(title: "Width", value: bind(\.width), range: 360...560, step: 10) { "\(Int($0)) pt" }
                Picker("Density", selection: bind(\.density)) {
                    ForEach(Theme.Density.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("Rows") {
                ForEach(Array(s.theme.rows.enumerated()), id: \.element.id) { index, row in
                    HStack {
                        Toggle(row.kind.name, isOn: Binding(get: { s.theme.rows[index].visible }, set: { s.theme.rows[index].visible = $0 }))
                        Spacer()
                        Button { move(index, by: -1) } label: { Image(systemName: "chevron.up") }
                            .buttonStyle(.borderless).disabled(index == 0).accessibilityLabel("Move \(row.kind.name) up")
                        Button { move(index, by: 1) } label: { Image(systemName: "chevron.down") }
                            .buttonStyle(.borderless).disabled(index == s.theme.rows.count - 1).accessibilityLabel("Move \(row.kind.name) down")
                    }
                }
            }
            Section("Live activities") {
                Picker("While music plays", selection: $s.musicActivity) {
                    ForEach(AppSettings.MusicActivity.allCases) { Text($0.name).tag($0) }
                }
                Toggle("Music bars follow the beat", isOn: $s.equalizerWhilePlaying)
                Toggle("Charging", isOn: $s.alertCharging)
                Toggle("Low battery", isOn: $s.alertLowBattery)
                Toggle("Wi-Fi connected or lost", isOn: $s.alertWifi)
            }
            Section("Closed notch") {
                Picker("Size", selection: $s.closedStyle) {
                    ForEach(AppSettings.ClosedStyle.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                if s.closedStyle == .withInfo {
                Picker("Left of the camera", selection: $s.leftWing) {
                    ForEach(AppSettings.Wing.allCases) { Text($0.name).tag($0) }
                }
                Picker("Right of the camera", selection: $s.rightWing) {
                    ForEach(AppSettings.Wing.allCases) { Text($0.name).tag($0) }
                }
                }
            }
        }
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
            Section {
                Picker("Motion", selection: bind(\.motion)) {
                    ForEach(Theme.MotionPreference.allCases) { Text($0.name).tag($0) }
                }
                SliderRow(title: "Speed", value: bind(\.speed), range: 0.6...1.6) { String(format: "%.1f×", $0) }
                SliderRow(title: "Blur", value: bind(\.blur), range: 0...16, step: 1) { "\(Int($0)) pt" }
                SliderRow(title: "Bounce", value: bind(\.bounce), range: 0...0.3) { "\(Int(($0 * 100).rounded()))%" }
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
            } footer: {
                Text("Works wherever macOS saves your screenshots. The file is kept.").foregroundStyle(.secondary)
            }
        }
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
            } footer: {
                Text("Belay uses the agents you already have, signed in their own way. It never asks for or stores your passwords or tokens.")
                    .foregroundStyle(.secondary)
            }
            Section { Button("Check again") { accounts.refresh() } }
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
