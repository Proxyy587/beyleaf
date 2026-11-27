import SwiftUI

// Making a buddy and watching its tasks (docs/buddies.md §2a, §6a). Nothing here makes anything on its own: a buddy exists
// because you pressed Create, and a task runs only after you approve its plan.

/// A pill that is either on or off.
private struct ToggleChip: View {
    let title: String
    let on: Bool
    let help: String
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Text(title).font(Tok.font(12, .medium)).foregroundStyle(on ? Tok.notch : Tok.ink2)
                .padding(.horizontal, Tok.s3).frame(height: 24)
                .background(Capsule().fill(on ? Tok.ink : hover ? Tok.pressedFill : Tok.hoverFill))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(help).accessibilityLabel(title).accessibilityAddTraits(on ? .isSelected : [])
        .onHover { h in withAnimation(Tok.hover) { hover = h } }
    }
}

/// A plain text field on a tonal capsule: the same field everywhere in the buddy cards.
struct BuddyField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void = {}
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain).font(Tok.body).foregroundStyle(Tok.ink)
            .onSubmit(onSubmit)
            .padding(.horizontal, Tok.s3)
            .frame(minHeight: Tok.button + 2)
            .background(Capsule().fill(Tok.hoverFill))
            .accessibilityLabel(placeholder)
    }
}

/// The new-buddy form: a face, a name, a job, how far it may reach. The core checks the rules and says why if it can't.
struct NewBuddyForm: View {
    @ObservedObject var store: BuddyStore
    var close: () -> Void
    @State private var name = ""
    @State private var job = ""
    @State private var face: BuddyID?
    @State private var reach: Set<String> = ["observe"]

    private var chosen: BuddyID? { face ?? store.freeCharacters.first }
    private var valid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && chosen != nil }

    private let levels: [(key: String, title: String, help: String)] = [
        ("observe", "Look", "Can see your screen and read what's open"),
        ("errands", "Errands", "Can open apps, files and links"),
        ("hands", "Hands", "Can click and type for you, asking first"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Tok.s3) {
            HStack(spacing: Tok.s2) {
                Text("New buddy").font(Tok.rowTitle).foregroundStyle(Tok.ink)
                StatusLine(text: "made by you")
                Spacer(minLength: 0)
                IconButton(symbol: "xmark", label: "Cancel", action: close)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tok.s1) {
                    ForEach(store.freeCharacters) { c in
                        Button { withAnimation(Tok.hover) { face = c } } label: {
                            BuddyView(id: c, size: 28).padding(5)
                                .background(Circle().fill(chosen == c ? Tok.hoverFill : .clear))
                        }
                        .buttonStyle(.plain).accessibilityLabel(c.rawValue)
                    }
                }
            }
            HStack(spacing: Tok.s2) {
                BuddyField(placeholder: "Name", text: $name)
                BuddyField(placeholder: "What it does", text: $job, onSubmit: create)
            }
            HStack(spacing: Tok.s1) {
                Text("Can").font(Tok.meta).foregroundStyle(Tok.ink3).padding(.trailing, Tok.s1)
                ForEach(levels, id: \.key) { l in
                    ToggleChip(title: l.title, on: reach.contains(l.key), help: l.help) {
                        if reach.contains(l.key) { reach.remove(l.key) } else { reach.insert(l.key) }
                        reach.insert("observe")
                    }
                }
                Spacer(minLength: Tok.s2)
                if let n = store.notice { Text(n).font(Tok.meta).foregroundStyle(Tok.warning).lineLimit(2).multilineTextAlignment(.trailing) }
                PillButton(title: "Create", action: create).opacity(valid ? 1 : 0.4).allowsHitTesting(valid)
            }
        }
    }

    private func create() {
        guard valid, let c = chosen else { return }
        store.create(name: name, job: job, character: c, reach: TierOrder.keys.filter { reach.contains($0) })
        close()
    }
}

private enum TierOrder { static let keys = ["observe", "errands", "hands", "sandbox"] }

/// The Tasks widget: what each buddy is working toward, and what is waiting on you.
struct TasksCard: View {
    @ObservedObject var store: BuddyStore
    let columns: Int

    var body: some View {
        let rows = Array(store.tasks.sorted { $0.state.urgency < $1.state.urgency }.prefix(columns >= 3 ? 4 : columns == 2 ? 3 : 1))
        VStack(alignment: .leading, spacing: Tok.s2) {
            HStack(spacing: Tok.s2) {
                Image(systemName: "checklist").font(Tok.icon).foregroundStyle(Tok.ink2).frame(width: Tok.gutter, height: Tok.gutter)
                Text("Tasks").font(Tok.rowTitle).foregroundStyle(Tok.ink)
                Spacer(minLength: Tok.s2)
                StatusLine(text: summary, live: false)
            }
            if columns > 1 { ForEach(rows) { row($0) } }
        }
        .card()
    }

    private var summary: String {
        let n = store.needsYouCount
        if n > 0 { return "\(n) need\(n == 1 ? "s" : "") you" }
        let a = store.activeTasks.count
        return a == 0 ? "none running" : "\(a) running"
    }

    private func row(_ t: TaskEntry) -> some View {
        let face = BuddyView(id: t.buddy, style: .smooth, mood: t.state == .done ? .happy : .idle, size: 22, eyeColor: t.state == .running ? Tok.live : nil)
        return HStack(alignment: .top, spacing: Tok.s2) {
            face.padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.goal).font(Tok.body).foregroundStyle(t.state.isFinished ? Tok.ink3 : Tok.ink).lineLimit(1).truncationMode(.tail)
                StatusLine(text: statusText(t), live: t.state == .running)
                if let note = t.note, t.state.needsYou || t.state == .blocked || t.state == .stopped || t.state == .failed {
                    Text(note).font(Tok.meta).foregroundStyle(t.state == .blocked ? Tok.warning : Tok.ink2).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Tok.s2)
            actions(t)
        }
        .frame(minHeight: Tok.button)
    }

    private func statusText(_ t: TaskEntry) -> String {
        var parts = [t.state.label]
        if let step = t.current { parts.append(step.label) }
        if let p = BuddyLogic.progress(done: t.done, total: t.steps.count), t.state != .done { parts.append(p) }
        if t.moved > 0 || t.maxMoney != nil, let max = t.maxMoney {
            parts.append("\(BuddyLogic.money(t.moved, currency: nil)) of \(BuddyLogic.money(max, currency: t.currency))")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private func actions(_ t: TaskEntry) -> some View {
        switch t.state {
        case .planOK:
            HStack(spacing: Tok.s1) { PillButton(title: "Approve plan") { store.act(t.id, "approve") }; IconButton(symbol: "xmark", label: "Cancel task") { store.act(t.id, "deny") } }
        case .needsYou:
            if t.current?.kind == "payment" {
                HStack(spacing: Tok.s1) { PillButton(title: "I paid") { store.act(t.id, "approve") }; IconButton(symbol: "stop.fill", label: "Stop task") { store.act(t.id, "stop") } }
            } else {
                HStack(spacing: Tok.s1) { PillButton(title: "Allow") { store.act(t.id, "approve") }; IconButton(symbol: "xmark", label: "Skip this step") { store.act(t.id, "deny") } }
            }
        case .running, .planning, .paused:
            IconButton(symbol: "stop.fill", label: "Stop task") { store.act(t.id, "stop") }
        default:
            EmptyView()
        }
    }
}
