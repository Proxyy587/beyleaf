import Foundation

// Notes widget logic and storage (docs/widget-hub.md §3.4). Foundation only, so the self-test can compile it.

struct Note: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var text: String
    var created: Date
}

enum NotesLogic {
    static let maxNotes = 5_000

    /// The field's text as a note: trimmed, or nil when there is nothing to save.
    static func capture(_ field: String) -> String? {
        let t = field.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func fold(_ s: String) -> String { s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }

    /// Newest first; with a query, only notes containing every word (case and accent insensitive), notes with a
    /// word that starts a word in the note first.
    static func search(_ notes: [Note], query: String) -> [Note] {
        let newest = notes.sorted { $0.created > $1.created }
        let words = fold(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return newest }
        func score(_ n: Note) -> Int? {
            let hay = fold(n.text)
            var s = 0
            for w in words {
                guard hay.contains(w) else { return nil }
                if hay.hasPrefix(w) || hay.contains(" " + w) { s += 1 }
            }
            return s
        }
        let scored = newest.compactMap { n in score(n).map { (n, $0) } }
        return scored.enumerated().sorted { a, b in a.element.1 != b.element.1 ? a.element.1 > b.element.1 : a.offset < b.offset }.map(\.element.0)
    }

    /// Adds a note, dropping the oldest past the cap.
    static func adding(_ note: Note, to notes: [Note]) -> [Note] {
        var out = notes + [note]
        if out.count > maxNotes { out.sort { $0.created < $1.created }; out.removeFirst(out.count - maxNotes) }
        return out
    }

    /// "now", "4 min", "3 h", "2 d".
    static func age(_ created: Date, now: Date) -> String {
        let s = max(0, now.timeIntervalSince(created))
        if s < 60 { return "now" }
        if s < 3600 { return "\(Int(s / 60)) min" }
        if s < 86_400 { return "\(Int(s / 3600)) h" }
        return "\(Int(s / 86_400)) d"
    }

    /// "12 NOTES", "1 NOTE", or "3 MATCH" while searching.
    static func count(total: Int, matches: Int?) -> String {
        if let m = matches { return m == 1 ? "1 MATCH" : "\(m) MATCH" }
        return total == 1 ? "1 NOTE" : "\(total) NOTES"
    }
}

/// `{"version":1,"notes":[{"id","text","created"}]}` at a file URL, written atomically.
struct NotesStorage {
    let url: URL

    static var defaultURL: URL {
        #if DEBUG
        // `--notes-file <path>`: a scratch file for screenshots and tests, so the user's notes are never touched.
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "--notes-file"), a.indices.contains(i + 1) { return URL(fileURLWithPath: a[i + 1]) }
        #endif
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Belay", isDirectory: true).appendingPathComponent("notes.json")
    }

    private struct File: Codable { var version: Int; var notes: [Note] }

    private static var encoder: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e }
    private static var decoder: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }

    enum LoadResult: Equatable { case notes([Note]); case missing; case corrupt }

    func load() -> LoadResult {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        guard let data = try? Data(contentsOf: url), let f = try? Self.decoder.decode(File.self, from: data), f.version == 1 else { return .corrupt }
        return .notes(f.notes)
    }

    /// Writes atomically. Returns false when it could not (the caller shows "NOT SAVED").
    func save(_ notes: [Note]) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(File(version: 1, notes: notes)).write(to: url, options: .atomic)
            return true
        } catch { return false }
    }

    /// Moves an unreadable file aside so a fresh one never overwrites it.
    func setCorruptAside(now: Date = Date()) {
        let aside = url.deletingLastPathComponent().appendingPathComponent("notes.json.bad-\(Int(now.timeIntervalSince1970))")
        try? FileManager.default.moveItem(at: url, to: aside)
    }
}
