import AppKit
import Foundation

/// What's playing in Music or Spotify.
///
/// Track changes arrive through the players' own distributed notifications, so nothing is polled and no permission is
/// needed to *read* them. Play/pause/skip use AppleScript, which asks for the Automation permission once per player.
/// Belay never launches a player that isn't already running.
@MainActor
final class NowPlaying: ObservableObject {
    enum Player: String { case music = "Music", spotify = "Spotify" }

    @Published private(set) var title: String?
    @Published private(set) var artist: String?
    @Published private(set) var isPlaying = false
    @Published private(set) var player: Player?

    private let bundleIDs: [Player: String] = [.music: "com.apple.Music", .spotify: "com.spotify.client"]
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = DistributedNotificationCenter.default()
        let names: [(String, Player)] = [("com.apple.Music.playerInfo", .music), ("com.spotify.client.PlaybackStateChanged", .spotify)]
        for (name, player) in names {
            let token = center.addObserver(forName: .init(name), object: nil, queue: .main) { [weak self] note in
                let info = note.userInfo ?? [:]
                let state = info["Player State"] as? String
                let name = info["Name"] as? String
                let artist = info["Artist"] as? String
                MainActor.assumeIsolated { self?.apply(player: player, state: state, title: name, artist: artist) }
            }
            observers.append(token)
        }
    }

    /// Ask a running player once for its current track (on launch / when the notch opens and we know nothing yet).
    func refreshIfUnknown() {
        guard title == nil, let running = runningPlayer() else { return }
        let script = """
        tell application "\(running.rawValue)"
            if player state is stopped then return "stopped"
            return (player state as text) & "|||" & (name of current track) & "|||" & (artist of current track)
        end tell
        """
        Task.detached {
            let result = Self.runAppleScript(script)
            await MainActor.run {
                guard let result, result != "stopped" else { return }
                let parts = result.components(separatedBy: "|||")
                guard parts.count == 3 else { return }
                self.apply(player: running, state: parts[0].capitalized, title: parts[1], artist: parts[2])
            }
        }
    }

    func playPause() { command("playpause") }
    func next() { command("next track") }
    func previous() { command("previous track") }

    private func command(_ verb: String) {
        guard let target = player ?? runningPlayer() else { return }
        let script = "tell application \"\(target.rawValue)\" to \(verb)"
        Task.detached { _ = Self.runAppleScript(script) }
        if verb == "playpause" { isPlaying.toggle() }
    }

    private func runningPlayer() -> Player? {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        if let p = player, let id = bundleIDs[p], running.contains(id) { return p }
        return [Player.spotify, .music].first { running.contains(bundleIDs[$0]!) }
    }

    private func apply(player: Player, state: String?, title: String?, artist: String?) {
        self.player = player
        isPlaying = (state == "Playing")
        if state == "Stopped" { self.title = nil; self.artist = nil; return }
        if let title { self.title = title }
        if let artist { self.artist = artist }
    }

    nonisolated private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result?.stringValue : nil
    }
}
