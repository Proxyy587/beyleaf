import SwiftUI

// The Buddies and Routines widgets on the Agents page (docs/buddies.md §3–§5). One card, three forms:
//   small (1 column)  the buddy and what it is doing
//   wide  (2 columns) compact: roster strip, last reply, one-line composer
//   full  (3 columns, expanded) roster beside the thread, tool steps as rows

@MainActor private extension BuddyRunState {
    /// Status colour only means status (design.md §3): working is live, needs you is warning, stopped is danger.
    var dot: Color? {
        switch self {
        case .working: Tok.live
        case .waiting: Tok.warning
        case .error: Tok.danger
        default: nil
        }
    }
    var mood: BuddyMood { self == .paused ? .sleep : self == .done ? .happy : .idle }
}

/// The sprite with a state dot. Still at rest; working turns the eyes live green.
private struct BuddyFace: View {
    let entry: BuddyEntry
    var size: CGFloat = 28
    var body: some View {
        BuddyView(id: entry.id, style: .smooth, mood: entry.state.mood, size: size,
                  eyeColor: entry.state == .working ? Tok.live : nil)
            .overlay(alignment: .topTrailing) {
                if let dot = entry.state.dot { Circle().fill(dot).frame(width: 7, height: 7).offset(x: 2, y: -2) }
            }
    }
}

struct BuddiesCard: View {
    @ObservedObject var store: BuddyStore
    /// Columns the card spans: 1, 2 or 3.
    let columns: Int
    @FocusState private var focused: Bool
    /// The new-buddy form is open in place of the chat.
    #if DEBUG
    @State private var creating = CommandLine.arguments.contains("--new-buddy")   // screenshots of the form
    #else
    @State private var creating = false
    #endif
    /// The composer sends a task (a goal that runs in steps you approve) instead of a chat message.
    @State private var taskMode = false
    @State private var limitText = ""
    @State private var confirmRemove: BuddyID?

    var body: some View {
        Group {
            if let current = store.current {
                if creating && columns > 1 {
                    NewBuddyForm(store: store) { withAnimation(Tok.open) { creating = false } }
                        .transition(Tok.reduceMotion ? .opacity : AnyTransition(.blurReplace))
                } else {
                    switch columns {
                    case 1: tile(current)
                    case 2: compact(current)
                    default: expanded(current)
                    }
                }
            }
        }
        .animation(Tok.open, value: creating)
        .card()
        .accessibilityElement(children: .contain)
    }

    // MARK: small
    private func tile(_ b: BuddyEntry) -> some View {
        Button { store.select(next(after: b.id)) } label: {
            HStack(spacing: Tok.s3) {
                BuddyFace(entry: b, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(b.name).font(Tok.rowTitle).foregroundStyle(Tok.ink).lineLimit(1)
                    StatusLine(text: BuddyLogic.statusText(b.state, detail: b.detail), live: b.state == .working)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(b.name), \(b.state.label)")
        .accessibilityHint("Next buddy")
    }

    private func next(after id: BuddyID) -> BuddyID {
        let ids = store.buddies.map(\.id)
        guard let i = ids.firstIndex(of: id) else { return id }
        return ids[(i + 1) % ids.count]
    }

    // MARK: wide (compact)
    private func compact(_ b: BuddyEntry) -> some View {
        VStack(alignment: .leading, spacing: Tok.s3) {
            roster(selected: b.id)
            lastReply(b)
            composer(b)
        }
    }

    private func roster(selected: BuddyID) -> some View {
        let strip = BuddyLogic.strip(count: store.buddies.count, selected: store.buddies.firstIndex { $0.id == selected } ?? 0, fit: 6)
        return HStack(spacing: Tok.s1) {
            ForEach(strip.visible, id: \.self) { i in
                let e = store.buddies[i]
                let on = e.id == selected
                Button { withAnimation(Tok.hover) { store.select(e.id) } } label: {
                    // The chosen buddy is named; the rest are faces, named on hover.
                    HStack(spacing: Tok.s2) {
                        BuddyFace(entry: e, size: 26)
                        if on { Text(e.name).font(Tok.rowTitle).foregroundStyle(Tok.ink).lineLimit(1).transition(.opacity) }
                    }
                    .padding(.vertical, 3).padding(.leading, 5).padding(.trailing, on ? Tok.s3 : 5)
                    .background(Capsule().fill(on ? Tok.hoverFill : .clear))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("\(e.name) · \(e.state.label)")
                .accessibilityLabel("\(e.name), \(e.state.label)")
            }
            if strip.more > 0 { Text("+\(strip.more)").font(Tok.digits).foregroundStyle(Tok.ink3).padding(.leading, Tok.s1) }
            if store.canAddBuddy { addButton }
            Spacer(minLength: Tok.s2)
            if store.isDemo { StatusLine(text: "demo") }
        }
    }

    private func lastReply(_ b: BuddyEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            StatusLine(text: "\(b.name) · \(BuddyLogic.statusText(b.state, detail: b.detail))", live: b.state == .working)
            if let line = store.thread(b.id).last(where: { $0.from != nil }) {
                Text(line.text).font(Tok.body).foregroundStyle(Tok.ink).lineLimit(2).truncationMode(.tail)
            } else {
                Text(b.job).font(Tok.body).foregroundStyle(Tok.ink2).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Two presses, so a slip never removes a buddy (and the tasks it is running).
    @ViewBuilder private func removeButton(_ b: BuddyEntry) -> some View {
        if confirmRemove == b.id {
            PillButton(title: "Remove \(b.name)?") { withAnimation(Tok.open) { confirmRemove = nil; store.remove(b.id) } }
        } else {
            IconButton(symbol: "trash", label: "Remove \(b.name)") { withAnimation(Tok.hover) { confirmRemove = b.id } }
        }
    }

    private var addButton: some View {
        IconButton(symbol: "plus", label: "New buddy") { withAnimation(Tok.open) { creating = true } }
    }

    /// A field you can see is a field: a tonal capsule with the send button always in place, dimmed until there's text.
    /// The Task chip turns it into a task: the goal goes to the core, which plans it and waits for your OK.
    private func composer(_ b: BuddyEntry) -> some View {
        let empty = store.draft.trimmingCharacters(in: .whitespaces).isEmpty
        return HStack(spacing: Tok.s2) {
            Button { withAnimation(Tok.hover) { taskMode.toggle() } } label: {
                Text("Task").font(Tok.font(11, .medium)).foregroundStyle(taskMode ? Tok.notch : Tok.ink2)
                    .padding(.horizontal, Tok.s2).frame(height: 22)
                    .background(Capsule().fill(taskMode ? Tok.ink : Tok.hoverFill))
            }
            .buttonStyle(.plain)
            .help(taskMode ? "Sending a task: \(b.name) plans it and asks you before it runs" : "Send as a task instead of a message")
            .accessibilityLabel("Send as task").accessibilityAddTraits(taskMode ? .isSelected : [])
            TextField(taskMode ? "Tell \(b.name) what to do" : "Ask \(b.name)", text: $store.draft)
                .textFieldStyle(.plain).font(Tok.body).foregroundStyle(Tok.ink)
                .focused($focused)
                .onSubmit { if !empty { submit() } }
                .accessibilityLabel(taskMode ? "Task for \(b.name)" : "Ask \(b.name)")
            if taskMode {
                TextField("Limit", text: $limitText)
                    .textFieldStyle(.plain).font(Tok.digits).foregroundStyle(Tok.ink)
                    .multilineTextAlignment(.trailing).frame(width: 52)
                    .help("The most this task may spend. Leave empty if it spends nothing.")
                    .accessibilityLabel("Spending limit")
            }
            IconButton(symbol: "arrow.up.circle.fill", label: taskMode ? "Send task" : "Send", action: submit)
                .disabled(empty)
                .opacity(empty ? 0.5 : 1)
        }
        .padding(.leading, Tok.s2).padding(.trailing, 2)
        .frame(minHeight: Tok.button + 4)
        .background(Capsule().fill(Tok.hoverFill))
    }

    private func submit() {
        if taskMode {
            store.startTask(goal: store.draft, limit: BuddyLogic.parseLimit(limitText))
            store.draft = ""; limitText = ""; taskMode = false
        } else {
            store.send()
        }
    }

    // MARK: full (expanded)
    private func expanded(_ b: BuddyEntry) -> some View {
        HStack(alignment: .top, spacing: Tok.s4) {
            VStack(alignment: .leading, spacing: Tok.s1) {
                ForEach(BuddyLogic.ordered(store.buddies, state: \.state)) { e in
                    Button { withAnimation(Tok.hover) { store.select(e.id) } } label: {
                        HStack(spacing: Tok.s2) {
                            BuddyFace(entry: e, size: 24)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(e.name).font(Tok.rowTitle).foregroundStyle(Tok.ink).lineLimit(1)
                                StatusLine(text: BuddyLogic.statusText(e.state, detail: e.detail), live: e.state == .working)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, Tok.s1).padding(.horizontal, Tok.s2)
                        .background(RoundedRectangle(cornerRadius: Tok.rThumb, style: .continuous).fill(e.id == b.id ? Tok.hoverFill : .clear))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(e.name), \(e.state.label)")
                }
                if store.canAddBuddy {
                    Button { withAnimation(Tok.open) { creating = true } } label: {
                        HStack(spacing: Tok.s2) {
                            Image(systemName: "plus").font(Tok.icon).foregroundStyle(Tok.ink2).frame(width: 24, height: 24)
                            Text("New buddy").font(Tok.rowTitle).foregroundStyle(Tok.ink2)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, Tok.s1).padding(.horizontal, Tok.s2)
                    }
                    .buttonStyle(.plain).accessibilityLabel("New buddy")
                }
            }
            .frame(width: 184, alignment: .leading)
            VStack(alignment: .leading, spacing: Tok.s3) {
                HStack {
                    Text(b.name).font(Tok.title).foregroundStyle(Tok.ink)
                    Text(b.job).font(Tok.meta).foregroundStyle(Tok.ink3).lineLimit(1)
                    if b.madeBy != "you" { StatusLine(text: "made by \(b.madeBy)") }
                    Spacer(minLength: 0)
                    if store.isDemo { StatusLine(text: "demo") }
                    if b.id != .beepo { removeButton(b) }
                }
                thread(b)
                composer(b)
            }
        }
    }

    private func thread(_ b: BuddyEntry) -> some View {
        let lines = BuddyLogic.tail(store.thread(b.id), columns: 3)
        return VStack(alignment: .leading, spacing: Tok.s2) {
            if lines.isEmpty {
                Text("Nothing yet. Ask \(b.name) something.").font(Tok.body).foregroundStyle(Tok.ink3)
            }
            ForEach(lines) { line in
                VStack(alignment: .leading, spacing: 2) {
                    // Who is talking, when it isn't this thread's buddy (a hand-off).
                    if let f = line.from, f != b.id { StatusLine(text: f.rawValue) }
                    // Text, not bubbles: yours is quieter, a buddy's is full ink (docs/buddies.md §5).
                    Text(line.text).font(Tok.body).foregroundStyle(line.from == nil ? Tok.ink2 : Tok.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(line.steps) { StatusLine(text: $0.label) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Routines

struct RoutinesCard: View {
    @ObservedObject var store: BuddyStore
    let columns: Int

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            let rows = Array(store.routines.prefix(columns >= 3 ? 5 : columns == 2 ? 3 : 1))
            VStack(alignment: .leading, spacing: Tok.s2) {
                if columns == 1 {
                    HStack(spacing: Tok.s2) {
                        Image(systemName: "clock.arrow.circlepath").font(Tok.icon).foregroundStyle(Tok.ink2).frame(width: Tok.gutter)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(store.routines.count) routines").font(Tok.rowTitle).foregroundStyle(Tok.ink).lineLimit(1)
                            StatusLine(text: soonest(ctx.date))
                        }
                    }
                } else {
                    HStack(spacing: Tok.s2) {
                        Image(systemName: "clock.arrow.circlepath").font(Tok.icon).foregroundStyle(Tok.ink2).frame(width: Tok.gutter, height: Tok.gutter)
                        Text("Routines").font(Tok.rowTitle).foregroundStyle(Tok.ink)
                        Spacer(minLength: Tok.s2)
                        StatusLine(text: soonest(ctx.date))
                    }
                    ForEach(rows) { r in row(r, now: ctx.date) }
                }
            }
            .card()
        }
    }

    private func soonest(_ now: Date) -> String {
        guard let next = store.routines.filter({ !$0.paused }).compactMap(\.next).min() else { return "none scheduled" }
        return "next \(BuddyLogic.until(next, now: now))"
    }

    private func row(_ r: RoutineEntry, now: Date) -> some View {
        HStack(spacing: Tok.s2) {
            BuddyView(id: r.buddy, style: .smooth, mood: r.paused ? .sleep : .idle, size: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(r.goal).font(Tok.body).foregroundStyle(r.paused ? Tok.ink3 : Tok.ink).lineLimit(1).truncationMode(.tail)
                StatusLine(text: r.paused ? "\(r.when) · paused" : "\(r.when) · \(BuddyLogic.until(r.next, now: now))")
            }
            Spacer(minLength: Tok.s2)
            IconButton(symbol: r.paused ? "play.fill" : "pause.fill", label: r.paused ? "Resume routine" : "Pause routine") {
                withAnimation(Tok.open) { store.setPaused(r.id, !r.paused) }
            }
        }
        .frame(minHeight: Tok.button)
    }
}
