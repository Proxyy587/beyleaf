import AppKit
import Foundation

/// Copies every new screenshot to the clipboard (feature N1).
///
/// Uses a live Spotlight query on `kMDItemIsScreenCapture == 1` (set by macOS on every screenshot), so it works wherever
/// screenshots are saved. Verified on 2026-11-24 with a custom save location. Only files created after Belay started
/// are handled. If macOS saves screenshots to a protected folder such as Desktop, reading them may trigger a Files &
/// Folders prompt (UNVERIFIED).
@MainActor
final class Screenshots: ObservableObject {
    struct Copied: Equatable { let url: URL; let at: Date; let bytes: Int }

    /// The most recent screenshot Belay copied; drives the "Copied" wing and the open-panel row.
    @Published private(set) var lastCopied: Copied?
    /// True for 2 s after a copy: the closed notch shows a check. Cleared by a timer so the view always updates.
    @Published private(set) var justCopied = false
    private var clearTask: Task<Void, Never>?

    private let query = NSMetadataQuery()
    private var observer: NSObjectProtocol?
    private var seen = Set<String>()
    private let startedAt = Date()

    init() {
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1 AND kMDItemContentCreationDate > %@", startedAt as NSDate)
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        query.notificationBatchingInterval = 0.2
        observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { [weak self] note in
            let added = (note.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem]) ?? []
            let paths = added.compactMap { $0.value(forAttribute: NSMetadataItemPathKey) as? String }
            MainActor.assumeIsolated { self?.handle(paths) }
        }
        apply()
    }

    /// Start or stop following the setting.
    func apply() {
        if AppSettings.shared.screenshotAutoCopy { if !query.isStarted { query.start() } } else if query.isStarted { query.stop() }
    }

    /// Copy again (from the open-panel row).
    func copyAgain() { if let c = lastCopied { copy(c.url) } }

    func reveal() { if let c = lastCopied { NSWorkspace.shared.activateFileViewerSelecting([c.url]) } }

    private func handle(_ paths: [String]) {
        guard AppSettings.shared.screenshotAutoCopy else { return }
        for path in paths where !seen.contains(path) {
            seen.insert(path)
            copy(URL(fileURLWithPath: path))
        }
    }

    private func copy(_ url: URL) {
        guard let data = try? Data(contentsOf: url), let image = NSImage(data: data) else { return }
        let item = NSPasteboardItem()
        if url.pathExtension.lowercased() == "png" { item.setData(data, forType: .png) }
        if let tiff = image.tiffRepresentation { item.setData(tiff, forType: .tiff) }
        item.setString(url.absoluteString, forType: .fileURL)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([item])
        lastCopied = Copied(url: url, at: Date(), bytes: data.count)
        justCopied = true
        clearTask?.cancel()
        clearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { self?.justCopied = false }
        }
    }
}
