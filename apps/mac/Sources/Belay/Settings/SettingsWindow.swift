import AppKit
import SwiftUI

/// A real macOS settings window (docs/design.md §11): sidebar sections, grouped forms, native controls, live changes.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let accounts = AIAccounts()

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(accounts: accounts))
            let w = NSWindow(contentViewController: host)
            w.title = "Belay Settings"
            w.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.toolbarStyle = .unified
            w.setContentSize(NSSize(width: 720, height: 480))
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        accounts.refresh()
        // The user asked for Settings, so taking focus is right. A dock-less app may be refused activation by macOS 14's
        // cooperative activation, so also order the window front explicitly.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General", appearance = "Appearance", screenshots = "Screenshots", accounts = "AI accounts", about = "About"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .screenshots: "camera.viewfinder"
        case .accounts: "person.crop.circle"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var accounts: AIAccounts
    @State private var section: SettingsSection? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $section) { s in
                Label(s.rawValue, systemImage: s.symbol).tag(s)
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            switch section ?? .general {
            case .general: GeneralPane()
            case .appearance: AppearancePane()
            case .screenshots: ScreenshotsPane()
            case .accounts: AccountsPane(accounts: accounts)
            case .about: AboutPane()
            }
        }
        .frame(minWidth: 680, minHeight: 440)
    }
}

private struct GeneralPane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Form {
            Section {
                Picker("Open on hover", selection: $s.hoverDelay) {
                    ForEach(AppSettings.HoverDelay.allCases) { Text($0.name).tag($0) }
                }
                Toggle("Haptics", isOn: $s.haptics)
            } footer: {
                Text("Haptics are felt on Force Touch trackpads while your finger rests on them.").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

private struct AppearancePane: View {
    @ObservedObject var s = AppSettings.shared
    var body: some View {
        Form {
            Section("Notch") {
                Picker("Open width", selection: $s.width) {
                    ForEach(AppSettings.Width.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Left of the camera", selection: $s.leftWing) {
                    ForEach(AppSettings.Wing.allCases) { Text($0.name).tag($0) }
                }
                Picker("Right of the camera", selection: $s.rightWing) {
                    ForEach(AppSettings.Wing.allCases) { Text($0.name).tag($0) }
                }
                Toggle("Show the equalizer while music plays", isOn: $s.equalizerWhilePlaying)
            }
            Section("Accent") {
                HStack(spacing: 12) {
                    ForEach(AppSettings.Accent.allCases) { a in
                        Button { s.accent = a } label: {
                            Circle().fill(a.color).frame(width: 20, height: 20)
                                .overlay(Circle().strokeBorder(.primary.opacity(s.accent == a ? 0.9 : 0), lineWidth: 2).padding(-4))
                        }
                        .buttonStyle(.plain)
                        .help(a.name)
                        .accessibilityLabel("\(a.name) accent")
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
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
        .formStyle(.grouped)
        .navigationTitle("Screenshots")
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
        .formStyle(.grouped)
        .navigationTitle("AI accounts")
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
        .formStyle(.grouped)
        .navigationTitle("About")
    }
}
