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

    var body: some View {
        Group {
            if let current = store.current {
                switch columns {
                case 1: tile(current)
                case 2: compact(current)
                default: expanded(current)
                }
            }
        }
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
        let strip = BuddyLogic.strip(count: store.buddies.count, selected: store.buddies.firstIndex { $0.id == selected } ?? 0, fit: 7)
        return HStack(spacing: Tok.s2) {
            ForEach(strip.visible, id: \.self) { i in
                let e = store.buddies[i]
                Button { withAnimation(Tok.hover) { store.select(e.id) } } label: {
                    BuddyFace(entry: e, size: 28)
                        .padding(Tok.s1)
                        .background(Circle().fill(e.id == selected ? Tok.hoverFill : .clear))
                }
                .buttonStyle(.plain)
                .help("\(e.name) · \(e.state.label)")
                .accessibilityLabel("\(e.name), \(e.state.label)")
            }
            if strip.more > 0 { Text("+\(strip.more)").font(Tok.digits).foregroundStyle(Tok.ink3) }
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

    private func composer(_ b: BuddyEntry) -> some View {
        HStack(spacing: Tok.s2) {
            TextField("Ask \(b.name)", text: $store.draft)
                .textFieldStyle(.plain).font(Tok.body).foregroundStyle(Tok.ink)
                .focused($focused)
                .onSubmit { store.send() }
                .accessibilityLabel("Ask \(b.name)")
            if !store.draft.isEmpty { IconButton(symbol: "arrow.up", label: "Send") { store.send() } }
        }
        .frame(minHeight: Tok.button)
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
            }
            .frame(width: 184, alignment: .leading)
            VStack(alignment: .leading, spacing: Tok.s3) {
                HStack {
                    Text(b.name).font(Tok.title).foregroundStyle(Tok.ink)
                    Text(b.job).font(Tok.meta).foregroundStyle(Tok.ink3).lineLimit(1)
                    Spacer(minLength: 0)
                    if store.isDemo { StatusLine(text: "demo") }
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
