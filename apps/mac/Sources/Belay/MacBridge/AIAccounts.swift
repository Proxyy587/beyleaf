import Foundation

/// Which agent CLIs are installed, for Settings → AI accounts (O3). Finds binaries and asks only `--version`.
/// Never reads credentials or session files (ADR 0004).
@MainActor
final class AIAccounts: ObservableObject {
    struct CLI: Identifiable, Equatable {
        let id: String          // binary name
        let name: String        // display name
        var path: String?
        var version: String?
        var checked = false
    }

    @Published private(set) var clis: [CLI] = [
        CLI(id: "claude", name: "Claude Code"),
        CLI(id: "codex", name: "Codex"),
    ]

    func refresh() {
        let names = clis.map(\.id)
        Task.detached {
            var found: [String: (String?, String?)] = [:]
            for name in names {
                let path = Self.locate(name)
                found[name] = (path, path.flatMap { Self.version(of: $0) })
            }
            await MainActor.run {
                self.clis = self.clis.map { c in
                    var c = c; c.path = found[c.id]?.0; c.version = found[c.id]?.1; c.checked = true; return c
                }
            }
        }
    }

    /// GUI apps don't inherit the shell's PATH, so look where installers put these.
    nonisolated private static func locate(_ name: String) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var dirs = ["/opt/homebrew/bin", "/usr/local/bin", "\(home)/.local/bin", "\(home)/.npm-global/bin", "\(home)/.bun/bin", "\(home)/.claude/local"]
        let nvm = "\(home)/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvm) {
            dirs += versions.sorted(by: >).map { "\(nvm)/\($0)/bin" }
        }
        return dirs.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    nonisolated private static func version(of path: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = ["--version"]
        // Minimal environment, PATH only (pattern from OpenMausBot's cli-probe, Apache-2.0): the binary's own folder
        // first so `#!/usr/bin/env node` finds the right node; nothing else is inherited, so no credentials leak in.
        let dir = (path as NSString).deletingLastPathComponent
        p.environment = ["PATH": "\(dir):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin", "HOME": FileManager.default.homeDirectoryForCurrentUser.path]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let deadline = Date().addingTimeInterval(5)
        while p.isRunning && Date() < deadline { usleep(50_000) }
        if p.isRunning { p.terminate(); return nil }
        let s = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return s.split(whereSeparator: \.isNewline).first.map { String($0).trimmingCharacters(in: .whitespaces) }
    }
}
