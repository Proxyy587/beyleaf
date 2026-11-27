import Foundation
import AppKit

// The shell's side of protocol v1 (docs/architecture.md §4): newline-delimited JSON over belayd's 0600 Unix socket.
// belayd decides; this file only sends requests and decodes replies. The row types below mirror
// `core/packages/protocol/src/{engines,envelope}.ts` BY HAND until the Swift codegen exists (ADR 0001): keep them in sync.

struct EngineStatusDTO: Decodable, Equatable {
    let id: String
    let name: String
    let installed: Bool
    let path: String?
    let version: String?
    let auth: String            // "signed-in" | "signed-out" | "unknown"
    let method: String?
    let plan: String?
    let verified: Bool
}

struct ConnectStepDTO: Decodable, Equatable {
    let kind: String            // "ready" | "install" | "signin"
    let command: String?
    let url: String?
    let certain: Bool?
}

struct EngineRowDTO: Decodable, Equatable, Identifiable {
    let status: EngineStatusDTO
    let step: ConnectStepDTO
    var id: String { status.id }
}

/// Crew and task shapes, hand-mirrored from core/packages/protocol/src/crew.ts and tasks.ts until codegen.
struct BuddyDTO: Decodable, Equatable, Identifiable {
    let id: String
    let name: String
    let sprite: String
    let job: String
    let tiers: [String]
    let autonomy: String
    let createdBy: String
}
struct StepDTO: Decodable, Equatable, Identifiable {
    let id: String
    let label: String
    let kind: String
    let status: String
    let amount: Double?
}
struct LimitsDTO: Decodable, Equatable {
    let maxSteps: Int
    let maxMinutes: Int
    let maxMoney: Double?
    let currency: String?
}
struct TaskDTO: Decodable, Equatable, Identifiable {
    let id: String
    let buddy: String
    let goal: String
    let status: String
    let steps: [StepDTO]
    let limits: LimitsDTO
    let moved: Double
    let note: String?
}
private struct RosterData: Decodable { let buddies: [BuddyDTO] }
private struct TaskData: Decodable { let task: TaskDTO }
private struct CreatedData: Decodable { let buddy: BuddyDTO; let by: String }
private struct RefusedData: Decodable { let why: String }
private struct EnginesData: Decodable { let engines: [EngineRowDTO] }
private struct SignInData: Decodable { let row: EngineRowDTO; let watching: Bool }
private struct Reply<T: Decodable>: Decodable { let id: String; let type: String; let data: T }
private struct Head: Decodable { let id: String; let type: String }

/// A blocking-read Unix socket on its own queues. Lines in, lines out.
private final class LineSocket: @unchecked Sendable {
    private var fd: Int32 = -1
    private let writeQueue = DispatchQueue(label: "app.belay.core.write")
    var onLine: (@Sendable (String) -> Void)?
    var onClose: (@Sendable () -> Void)?

    func open(path: String) -> Bool {
        let s = socket(AF_UNIX, SOCK_STREAM, 0)
        guard s >= 0 else { return false }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else { Darwin.close(s); return false }
        withUnsafeMutableBytes(of: &addr.sun_path) { $0.copyBytes(from: bytes + [0]) }
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(s, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard ok == 0 else { Darwin.close(s); return false }
        fd = s
        DispatchQueue.global(qos: .utility).async { [weak self] in self?.readLoop(s) }
        return true
    }

    private func readLoop(_ s: Int32) {
        var pending = Data()
        var chunk = [UInt8](repeating: 0, count: 65_536)
        while true {
            let n = read(s, &chunk, chunk.count)
            if n <= 0 { break }
            pending.append(chunk, count: n)
            while let nl = pending.firstIndex(of: 0x0A) {
                let line = String(decoding: pending[pending.startIndex..<nl], as: UTF8.self)
                pending.removeSubrange(pending.startIndex...nl)
                if !line.isEmpty { onLine?(line) }
            }
        }
        onClose?()
    }

    func send(_ line: String) {
        let s = fd
        guard s >= 0 else { return }
        writeQueue.async {
            let data = Array((line + "\n").utf8)
            var off = 0
            while off < data.count {
                let n = data.withUnsafeBytes { write(s, $0.baseAddress! + off, data.count - off) }
                if n <= 0 { return }
                off += n
            }
        }
    }

    func close() { if fd >= 0 { Darwin.close(fd); fd = -1 } }
}

/// The link to belayd. Started only when asked (`--core-dir`), so a build without the core runs exactly as before.
@MainActor
final class CoreLink: ObservableObject {
    static let shared = CoreLink()
    enum State { case off, connecting, ready }

    @Published private(set) var state: State = .off
    @Published private(set) var engines: [EngineRowDTO] = []
    /// The engine whose sign-in is open in Terminal, until the CLI reports it signed in (or the user cancels).
    @Published private(set) var signingIn: String?
    /// The crew as the core last reported it (beepo alone until you make a buddy), and the tasks it holds.
    @Published private(set) var buddies: [BuddyDTO] = []
    @Published private(set) var tasks: [TaskDTO] = []
    /// Why the core last said no (a full crew, a limit, a rule), shown once and cleared by the view that showed it.
    @Published var refusal: String?
    /// Who made the buddy that appeared last, when a buddy made it (you are shown it, never surprised by it).
    @Published private(set) var madeByBuddy: (buddy: String, by: String)?

    private var socket: LineSocket?
    private var process: Process?
    private var nextId = 0
    private var inFlight: [String: (String) -> Void] = [:]
    private var socketPath = ""

    /// `--core-dir <path to core/>` launches `bun packages/belayd/src/main.ts`; `--core-socket <path>` connects to one already running.
    func startIfRequested() {
        let a = CommandLine.arguments
        guard state == .off else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        socketPath = a.firstIndex(of: "--core-socket").flatMap { a.indices.contains($0 + 1) ? a[$0 + 1] : nil }
            ?? "\(home)/Library/Application Support/Belay/belayd.sock"
        if let i = a.firstIndex(of: "--core-dir"), a.indices.contains(i + 1) { launch(coreDir: a[i + 1], home: home) }
        else if !a.contains("--core-socket") { return }
        state = .connecting
        connect(attempt: 0)
    }

    func stop() {
        socket?.close()
        process?.terminate()
        process = nil
    }

    private func launch(coreDir: String, home: String) {
        guard let bun = ["\(home)/.bun/bin/bun", "/opt/homebrew/bin/bun", "/usr/local/bin/bun"].first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bun)
        p.arguments = ["\(coreDir)/packages/belayd/src/main.ts", "--socket", socketPath, "--exit-with-parent"]
        // Our stdin is the lifeline: when the app quits or dies the pipe closes and belayd exits (no orphan daemon).
        p.standardInput = Pipe()
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        // The app's own environment, as the user's session gave it: the vendors' CLIs need it to reach their own sign-in
        // store. belayd removes the API-key variables itself before it runs any engine (ADR 0025).
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = (env["PATH"] ?? "/usr/bin:/bin") + ":/opt/homebrew/bin:/usr/local/bin"
        p.environment = env
        try? p.run()
        process = p
    }

    private func connect(attempt: Int) {
        let s = LineSocket()
        s.onLine = { [weak self] line in Task { @MainActor in self?.handle(line) } }
        s.onClose = { [weak self] in Task { @MainActor in self?.state = .off; self?.signingIn = nil } }
        if s.open(path: socketPath) {
            socket = s
            state = .ready
            refresh()
            request("crew.list")
        } else if attempt < 20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.connect(attempt: attempt + 1) }
        } else {
            state = .off
        }
    }

    // MARK: requests

    private func request(_ type: String, _ data: [String: Any] = [:], reply: ((String) -> Void)? = nil) {
        guard let socket else { return }
        nextId += 1
        let id = String(nextId)
        if let reply { inFlight[id] = reply }
        let env: [String: Any] = ["v": 1, "id": id, "type": type, "data": data]
        if let json = try? JSONSerialization.data(withJSONObject: env), let line = String(data: json, encoding: .utf8) { socket.send(line) }
    }

    func refresh() {
        request("engines.list")
    }

    /// Ask the core what signing in takes, open the vendor's own command in a visible Terminal window, and let the core
    /// watch for the result. Belay never sees the code, the password or the token (ADR 0025).
    func signIn(_ id: String) {
        request("engines.signin", ["id": id])
    }

    // MARK: crew and tasks (the core decides; these only ask)

    func createBuddy(name: String, sprite: String, job: String, tiers: [String]) {
        request("crew.buddy.create", ["by": "you", "spec": ["name": name, "sprite": sprite, "job": job, "tiers": tiers]])
    }
    func removeBuddy(_ id: String) { request("crew.buddy.remove", ["by": "you", "id": id]) }
    func createTask(buddy: String, goal: String, maxMoney: Double?) {
        var data: [String: Any] = ["buddy": buddy, "goal": goal]
        if let maxMoney { data["limits"] = ["maxSteps": 30, "maxMinutes": 60, "maxMoney": maxMoney] }
        request("task.create", data)
    }
    func taskAction(_ id: String, _ action: String, paused: Bool? = nil) {
        var data: [String: Any] = ["id": id]
        if let paused { data["paused"] = paused }
        request("task.\(action)", data)
    }

    func cancelSignIn(_ id: String) {
        request("engines.cancel", ["id": id])
        if signingIn == id { signingIn = nil }
    }

    // MARK: replies

    private func handle(_ line: String) {
        guard let data = line.data(using: .utf8), let head = try? JSONDecoder().decode(Head.self, from: data) else { return }
        let dec = JSONDecoder()
        switch head.type {
        case "engines.list.result", "engines.updated":
            if let r = try? dec.decode(Reply<EnginesData>.self, from: data) {
                engines = r.data.engines
                // `--core-probe`: print what the shell decoded from belayd, then quit (a headless check of the link).
                if CommandLine.arguments.contains("--core-probe") {
                    for e in engines { print("core-probe", e.id, e.status.installed, e.status.auth, e.status.method ?? "-", e.status.plan ?? "-", e.step.kind) }
                    fflush(stdout)
                    NSApp.terminate(nil)
                }
                if head.type == "engines.updated", let s = signingIn, engines.first(where: { $0.id == s })?.status.auth == "signed-in" { signingIn = nil }
            }
        case "engines.signin.result":
            if let r = try? dec.decode(Reply<SignInData>.self, from: data) {
                upsert(r.data.row)
                if r.data.watching, let cmd = r.data.row.step.command {
                    signingIn = r.data.row.id
                    Self.openInTerminal(cmd, engine: r.data.row.id)
                }
            }
        case "crew.roster":
            if let r = try? dec.decode(Reply<RosterData>.self, from: data) { buddies = r.data.buddies }
        case "crew.created":
            if let r = try? dec.decode(Reply<CreatedData>.self, from: data), r.data.by != "you" { madeByBuddy = (r.data.buddy.name, r.data.by) }
        case "crew.refused":
            if let r = try? dec.decode(Reply<RefusedData>.self, from: data) { refusal = r.data.why }
        case "task.updated":
            if let r = try? dec.decode(Reply<TaskData>.self, from: data) {
                if let i = tasks.firstIndex(where: { $0.id == r.data.task.id }) { tasks[i] = r.data.task } else { tasks.append(r.data.task) }
            }
        default: break
        }
        inFlight.removeValue(forKey: head.id)?(line)
    }

    private func upsert(_ row: EngineRowDTO) {
        if let i = engines.firstIndex(where: { $0.id == row.id }) { engines[i] = row } else { engines.append(row) }
    }

    /// A `.command` file opens in Terminal: the user sees exactly what runs and types into the vendor's own prompt.
    private static func openInTerminal(_ command: String, engine: String) {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Belay", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let file = dir.appendingPathComponent("signin-\(engine).command")
        let script = "#!/bin/zsh\nclear\n\(command)\necho\necho \"Belay will notice when you are signed in. You can close this window.\"\n"
        do {
            try script.write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
            NSWorkspace.shared.open(file)
        } catch {}
    }
}
