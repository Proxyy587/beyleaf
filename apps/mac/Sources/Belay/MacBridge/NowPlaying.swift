import AppKit
import Foundation

/// What's playing in Music or Spotify: track, artwork, progress, and controls.
///
/// Track changes arrive through the players' own distributed notifications (no polling, no permission to *read*).
/// Artwork, position and controls use AppleScript, which asks for the Automation permission once per player.
/// Belay never launches a player that isn't already running.
/// Planned: any-app now playing via mediaremote-adapter (BSD-3) — see docs/features-final.md.
@MainActor
final class NowPlaying: ObservableObject {
    enum Player: String { case music = "Music", spotify = "Spotify" }

    @Published private(set) var title: String?
    @Published private(set) var artist: String?
    @Published private(set) var isPlaying = false
    @Published private(set) var player: Player?
    @Published private(set) var artwork: NSImage?
    /// Seconds into the track / track length, refreshed while the notch is open.
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    /// Increments when a *new* track starts, so the notch can play its "new track" live activity.
    @Published private(set) var trackChange = 0

    private let bundleIDs: [Player: String] = [.music: "com.apple.Music", .spotify: "com.spotify.client"]
    private var observers: [NSObjectProtocol] = []
    private var progressTimer: Timer?
    private var artworkFor: String?

    init() {
        let center = DistributedNotificationCenter.default()
        let names: [(String, Player)] = [("com.apple.Music.playerInfo", .music), ("com.spotify.client.PlaybackStateChanged", .spotify)]
        for (name, player) in names {
            let token = center.addObserver(forName: .init(name), object: nil, queue: .main) { [weak self] note in
                let info = note.userInfo ?? [:]
                let state = info["Player State"] as? String
                let name = info["Name"] as? String
                let artist = info["Artist"] as? String
                let total = (info["Total Time"] as? Double).map { $0 / 1000 } ?? (info["Duration"] as? Double).map { $0 / 1000 }
                MainActor.assumeIsolated { self?.apply(player: player, state: state, title: name, artist: artist, duration: total) }
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
            return (player state as text) & "|||" & (name of current track) & "|||" & (artist of current track) & "|||" & (duration of current track)
        end tell
        """
        Task.detached {
            let result = Self.runAppleScript(script)?.stringValue
            await MainActor.run {
                guard let result, result != "stopped" else { return }
                let p = result.components(separatedBy: "|||")
                guard p.count == 4 else { return }
                var d = Double(p[3].replacingOccurrences(of: ",", with: ".")) ?? 0
                if running == .spotify { d /= 1000 }        // Spotify reports milliseconds
                self.apply(player: running, state: p[0].capitalized, title: p[1], artist: p[2], duration: d)
            }
        }
    }

    /// Track position while the open panel shows the progress bar.
    func setProgressActive(_ active: Bool) {
        progressTimer?.invalidate(); progressTimer = nil
        guard active else { return }
        readPosition()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.isPlaying, self.duration > 0 { self.position = min(self.duration, self.position + 1) }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        progressTimer = t
    }

    func playPause() { command("playpause") }
    func next() { command("next track") }
    func previous() { command("previous track") }

    func seek(toFraction f: Double) {
        guard let target = player, duration > 0 else { return }
        let seconds = max(0, min(duration, f * duration))
        position = seconds
        let script = "tell application \"\(target.rawValue)\" to set player position to \(seconds)"
        Task.detached { _ = Self.runAppleScript(script) }
    }

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

    private func apply(player: Player, state: String?, title: String?, artist: String?, duration: Double?) {
        let wasPlaying = isPlaying
        let oldTitle = self.title
        self.player = player
        isPlaying = (state == "Playing")
        if state == "Stopped" { self.title = nil; self.artist = nil; artwork = nil; artworkFor = nil; position = 0; return }
        if let title { self.title = title }
        if let artist { self.artist = artist }
        if let duration, duration > 0 { self.duration = duration }
        if self.title != oldTitle { position = 0 }
        if isPlaying && (self.title != oldTitle || !wasPlaying) { trackChange &+= 1 }
        if let t = self.title, artworkFor != t { loadArtwork(for: player, title: t) }
        readPosition()
    }

    private func readPosition() {
        guard let target = player else { return }
        let script = "tell application \"\(target.rawValue)\" to return player position"
        Task.detached {
            let v = Self.runAppleScript(script)?.stringValue.flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
            await MainActor.run { if let v { self.position = v } }
        }
    }

    private func loadArtwork(for player: Player, title: String) {
        artworkFor = title
        switch player {
        case .music:
            let script = "tell application \"Music\" to if (count of artworks of current track) > 0 then return data of artwork 1 of current track"
            Task.detached {
                let data = Self.runAppleScript(script)?.data
                await MainActor.run { if self.artworkFor == title { self.artwork = data.flatMap { NSImage(data: $0) } } }
            }
        case .spotify:
            let script = "tell application \"Spotify\" to return artwork url of current track"
            Task.detached {
                guard let s = Self.runAppleScript(script)?.stringValue, let url = URL(string: s), url.scheme == "https",
                      let (data, _) = try? await URLSession.shared.data(from: url) else { return }
                await MainActor.run { if self.artworkFor == title { self.artwork = NSImage(data: data) } }
            }
        }
    }

    nonisolated private static func runAppleScript(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }
}
