import SwiftUI

// Making a buddy and watching its tasks (docs/buddies.md §2a, §6a). Nothing here makes anything on its own: a buddy exists
// because you pressed Create, and a task runs only after you approve its plan.

/// A pill that is either on or off.
struct ToggleChip: View {
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

/// The buttons a task can need from you: approve its plan, allow a spend, say you paid, or stop it.
struct TaskActions: View {
    @ObservedObject var store: BuddyStore
    let task: TaskEntry

    var body: some View {
        switch task.state {
        case .planOK:
            HStack(spacing: Tok.s1) { PillButton(title: "Approve plan") { store.act(task.id, "approve") }; IconButton(symbol: "xmark", label: "Cancel task") { store.act(task.id, "deny") } }
        case .needsYou:
            if task.current?.kind == "payment" {
                HStack(spacing: Tok.s1) { PillButton(title: "I paid") { store.act(task.id, "approve") }; IconButton(symbol: "stop.fill", label: "Stop task") { store.act(task.id, "stop") } }
            } else {
                HStack(spacing: Tok.s1) { PillButton(title: "Allow") { store.act(task.id, "approve") }; IconButton(symbol: "xmark", label: "Skip this step") { store.act(task.id, "deny") } }
            }
        case .running, .planning, .paused:
            IconButton(symbol: "stop.fill", label: "Stop task") { store.act(task.id, "stop") }
        default:
            EmptyView()
        }
    }
}

/// One task: who, what, how far, and what it waits for. `compact` puts the buttons under the text (a narrow column).
struct TaskRow: View {
    @ObservedObject var store: BuddyStore
    let task: TaskEntry
    var compact = false

    var body: some View {
        let t = task
        let text = VStack(alignment: .leading, spacing: 2) {
            Text(t.goal).font(Tok.body).foregroundStyle(t.state.isFinished ? Tok.ink3 : Tok.ink).lineLimit(compact ? 2 : 1).truncationMode(.tail)
            StatusLine(text: statusText(t), live: t.state == .running)
            if let note = t.note, t.state.needsYou || t.state == .blocked || t.state == .stopped || t.state == .failed {
                Text(note).font(Tok.meta).foregroundStyle(t.state == .blocked ? Tok.warning : Tok.ink2).lineLimit(3).fixedSize(horizontal: false, vertical: true)
            }
        }
        HStack(alignment: .top, spacing: Tok.s2) {
            BuddyView(id: t.buddy, style: .smooth, mood: t.state == .done ? .happy : .idle, size: 22, eyeColor: t.state == .running ? Tok.live : nil).padding(.top, 2)
            if compact {
                VStack(alignment: .leading, spacing: Tok.s1) { text; TaskActions(store: store, task: t) }
            } else {
                text
                Spacer(minLength: Tok.s2)
                TaskActions(store: store, task: t)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Tok.button, alignment: .topLeading)
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
}

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
                StatusLine(text: store.taskSummary)
            }
            if columns > 1 { ForEach(rows) { TaskRow(store: store, task: $0) } }
        }
        .card()
    }
}
