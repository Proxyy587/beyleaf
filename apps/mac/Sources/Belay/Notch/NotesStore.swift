import Carbon.HIToolbox
import Foundation

/// The Notes widget's state: the notes on disk, the field's draft, and the Undo for a delete.
/// Loaded the first time the Notes page shows, not at launch (docs/widget-hub.md §3.4).
@MainActor
final class NotesStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    /// What's typed in the field: it filters the list, and Return saves it.
    @Published var draft = ""
    /// The last save failed: the field row says NOT SAVED and the text stays in the field.
    @Published private(set) var saveFailed = false
    /// A note deleted in the last 4 s, offered back with Undo.
    @Published private(set) var undoable: Note?
    /// Bumped to ask the field for focus (the capture shortcut).
    @Published private(set) var focusRequest = 0
    /// Set when the notch was opened by the shortcut: it closes after the next save.
    var closeAfterSave = false
    var onCaptured: (() -> Void)?

    private let storage: NotesStorage
    private var loaded = false
    private var undoTask: Task<Void, Never>?

    init(storage: NotesStorage = NotesStorage(url: NotesStorage.defaultURL)) { self.storage = storage }

    func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        switch storage.load() {
        case let .notes(n): notes = n
        case .missing: notes = []
        case .corrupt: storage.setCorruptAside(); notes = []
        }
    }

    func requestFocus() { focusRequest &+= 1 }

    /// Return in the field. Saves a non-empty draft; on failure the draft stays.
    func saveDraft() {
        loadIfNeeded()
        guard let text = NotesLogic.capture(draft) else { return }
        let next = NotesLogic.adding(Note(id: UUID(), text: text, created: Date()), to: notes)
        if storage.save(next) {
            notes = next; draft = ""; saveFailed = false
            if closeAfterSave { closeAfterSave = false; onCaptured?() }
        } else { saveFailed = true }
    }

    func delete(_ note: Note) {
        let next = notes.filter { $0.id != note.id }
        guard storage.save(next) else { saveFailed = true; return }
        notes = next; undoable = note
        undoTask?.cancel()
        undoTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.undoable = nil
        }
    }

    func undoDelete() {
        guard let n = undoable else { return }
        undoTask?.cancel(); undoable = nil
        let next = NotesLogic.adding(n, to: notes)
        if storage.save(next) { notes = next } else { saveFailed = true }
    }

    var matches: [Note] { NotesLogic.search(notes, query: draft) }
    var isSearching: Bool { !draft.trimmingCharacters(in: .whitespaces).isEmpty }
}

/// A global hotkey through Carbon's RegisterEventHotKey, which needs no Accessibility or Input Monitoring permission.
/// macOS 15+ refuses hotkeys whose only modifiers are ⌥ or ⌥⇧, so the default is ⌃⌥N.
@MainActor
final class GlobalHotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private static var action: (@MainActor () -> Void)?

    /// Registers ⌃⌥ + `keyCode`. Returns false when another app already owns the combination.
    func register(keyCode: UInt32 = UInt32(kVK_ANSI_N), action: @escaping @MainActor () -> Void) -> Bool {
        unregister()
        Self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { GlobalHotKey.action?() } }
            return noErr
        }, 1, &spec, nil, &handler)
        let id = EventHotKeyID(signature: OSType(0x424C4159), id: 1)   // 'BLAY'
        let status = RegisterEventHotKey(keyCode, UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &ref)
        if status != noErr { unregister() }
        return status == noErr
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
        ref = nil; handler = nil
    }
}
