import Combine
import Foundation

/// What Settings → Agents shows: the engines belayd found and how to connect each (ADR 0025). Detection, status and the
/// sign-in plan are the core's decisions; this only renders them. Without the core, the pane says so.
@MainActor
final class AIAccounts: ObservableObject {
    private let link = CoreLink.shared
    var engines: [EngineRowDTO] { link.engines }
    var state: CoreLink.State { link.state }
    var signingIn: String? { link.signingIn }

    init() {
        link.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &bag)
    }
    private var bag = Set<AnyCancellable>()

    func refresh() { link.refresh() }
    func signIn(_ id: String) { link.signIn(id) }
    func cancel(_ id: String) { link.cancelSignIn(id) }
}
