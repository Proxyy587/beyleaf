import SwiftUI

// The expanded panel (docs/notch-research.md). Compact is a glance: one page at a time, dots at the bottom. Expanded is a
// workspace: every page named in a rail, a third column, a bar that keeps what needs you in view on every page, and on
// Agents a three-part layout (crew, conversation, tasks and schedule). Bigger would be the same thing larger; this is more.

/// What is waiting on you, on every page: one line with the buttons, and a count if there is more than one.
struct NeedsYouBar: View {
    @ObservedObject var store: BuddyStore
    var body: some View {
        if let t = store.tasks.filter({ $0.state.needsYou }).sorted(by: { $0.state.urgency < $1.state.urgency }).first {
            let more = store.needsYouCount - 1
            HStack(spacing: Tok.s2) {
                BuddyView(id: t.buddy, style: .smooth, mood: .idle, size: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(t.goal).font(Tok.rowTitle).foregroundStyle(Tok.ink).lineLimit(1).truncationMode(.tail)
                    StatusLine(text: t.state == .planOK ? "plan ready" : (t.current?.kind == "payment" ? "your turn to pay" : "needs your OK") + (more > 0 ? " · +\(more) more" : ""))
                }
                Spacer(minLength: Tok.s2)
                TaskActions(store: store, task: t)
            }
            .padding(.horizontal, Tok.s3).padding(.vertical, Tok.s2)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: Tok.rCard, style: .continuous).fill(Tok.warning.opacity(0.14)))
            .transition(Tok.reduceMotion ? .opacity : AnyTransition(.blurReplace))
            .accessibilityElement(children: .contain)
        }
    }
    static let height: CGFloat = 46
}

/// Down the left of the expanded panel: every page by name, the current one lit, a badge where something waits.
struct PageRail: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var buddies = BuddyStore.shared
    let pages: [PageKind]
    let current: PageKind?
    @State private var hover: PageKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(pages.enumerated()), id: \.element) { i, p in
                let on = p == current
                Button { model.go(to: p) } label: {
                    HStack(spacing: Tok.s2) {
                        Image(systemName: p.symbol).symbolVariant(on ? .fill : .none).font(Tok.icon)
                            .foregroundStyle(on ? Tok.ink : Tok.ink2).frame(width: Tok.gutter)
                        Text(p.name).font(Tok.rowTitle).foregroundStyle(on ? Tok.ink : Tok.ink2).lineLimit(1)
                        Spacer(minLength: 0)
                        if p == .agents, buddies.needsYouCount > 0 {
                            Text("\(buddies.needsYouCount)").font(Tok.font(11, .semibold)).foregroundStyle(Tok.notch)
                                .padding(.horizontal, 6).frame(height: 16).background(Capsule().fill(Tok.warning))
                                .accessibilityLabel("\(buddies.needsYouCount) need you")
                        }
                    }
                    .padding(.horizontal, Tok.s2).frame(height: 32)
                    .background(RoundedRectangle(cornerRadius: Tok.rThumb + 2, style: .continuous).fill(on ? Tok.hoverFill : hover == p ? Tok.raised : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("\(p.name)  ⌘\(i + 1)")
                .accessibilityLabel(p.name).accessibilityAddTraits(on ? .isSelected : [])
                .onHover { h in withAnimation(Tok.hover) { hover = h ? p : (hover == p ? nil : hover) } }
            }
            if model.editing, settings.canAddPage {
                Button { withAnimation(Tok.open) { if let p = settings.addPage() { settings.page = p } } } label: {
                    HStack(spacing: Tok.s2) {
                        Image(systemName: "plus").font(Tok.icon).foregroundStyle(Tok.ink3).frame(width: Tok.gutter)
                        Text("Add page").font(Tok.rowTitle).foregroundStyle(Tok.ink3)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Tok.s2).frame(height: 32).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel("Add a page")
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(Tok.open, value: current)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pages")
    }
}

/// Schedule a goal: what, how often, and when. When its time comes the core makes a task, and the task waits for your OK.
struct ScheduleForm: View {
    @ObservedObject var store: BuddyStore
    var close: () -> Void
    @State private var goal = ""
    @State private var every: RoutineRepeat = .daily
    @State private var time = "08:30"

    private var parsed: String? { every.needsTime ? BuddyLogic.parseTime(time) : "00:00" }
    private var valid: Bool { !goal.trimmingCharacters(in: .whitespaces).isEmpty && parsed != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Tok.s2) {
            BuddyField(placeholder: "What should \(store.current?.name ?? "beepo") do?", text: $goal, onSubmit: save)
            HStack(spacing: Tok.s1) {
                ForEach(RoutineRepeat.allCases, id: \.self) { r in
                    ToggleChip(title: r.title, on: every == r, help: r.title) { every = r }
                }
            }
            HStack(spacing: Tok.s2) {
                if every.needsTime {
                    Text("at").font(Tok.meta).foregroundStyle(Tok.ink3)
                    BuddyField(placeholder: "08:30", text: $time, onSubmit: save).frame(width: 74)
                }
                Spacer(minLength: 0)
                IconButton(symbol: "xmark", label: "Cancel", action: close)
                PillButton(title: "Schedule", action: save).opacity(valid ? 1 : 0.4).allowsHitTesting(valid)
            }
            if let n = store.notice { Text(n).font(Tok.meta).foregroundStyle(Tok.warning).lineLimit(2) }
        }
    }

    private func save() {
        guard valid, let t = parsed else { return }
        store.schedule(goal: goal, every: every, time: t)
        close()
    }
}

/// The right-hand part of the Agents workspace: two tabs, Tasks (what is being done) and Schedule (what will be), each with the
/// whole column to itself and its own way to add one.
struct PlanColumn: View {
    @ObservedObject var store: BuddyStore
    private enum Tab { case tasks, schedule }
    @State private var tab = Tab.tasks
    @State private var scheduling = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tok.s3) {
            HStack(spacing: Tok.s1) {
                ToggleChip(title: "Tasks\(count(store.tasks.count))", on: tab == .tasks, help: store.taskSummary) { withAnimation(Tok.hover) { tab = .tasks } }
                ToggleChip(title: "Schedule\(count(store.routines.count))", on: tab == .schedule, help: "Goals that run on a timer") { withAnimation(Tok.hover) { tab = .schedule } }
                Spacer(minLength: 0)
                if tab == .schedule {
                    IconButton(symbol: scheduling ? "minus" : "plus", label: scheduling ? "Close" : "Schedule something") { withAnimation(Tok.open) { scheduling.toggle() } }
                }
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Tok.s3) {
                    if tab == .tasks { tasks } else { schedule }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.bottom, Tok.s2)
            }
        }
        .card()
        .accessibilityElement(children: .contain)
    }

    private func count(_ n: Int) -> String { n == 0 ? "" : " \(n)" }

    @ViewBuilder private var tasks: some View {
        StatusLine(text: store.taskSummary)
        if store.tasks.isEmpty {
            hint("Nothing running. Press Task in the box beside this, then tell \(store.current?.name ?? "beepo") what to do.")
        }
        ForEach(store.tasks.sorted { $0.state.urgency < $1.state.urgency }) { TaskRow(store: store, task: $0, compact: true) }
    }

    @ViewBuilder private var schedule: some View {
        if scheduling { ScheduleForm(store: store) { withAnimation(Tok.open) { scheduling = false } }.transition(.opacity) }
        if store.routines.isEmpty && !scheduling {
            hint("Nothing scheduled. Press + to run a goal every day, on weekdays or every hour. Each time it comes round, a task is made and waits for your OK.")
        }
        TimelineView(.everyMinute) { ctx in
            VStack(alignment: .leading, spacing: Tok.s1) { ForEach(store.routines) { RoutineRow(store: store, routine: $0, now: ctx.date) } }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(Tok.meta).foregroundStyle(Tok.ink3).fixedSize(horizontal: false, vertical: true)
    }
}

/// Agents when expanded: crew and conversation on the left, tasks and schedule on the right, side by side.
struct AgentsWorkspace: View {
    @ObservedObject var store: BuddyStore
    static let height: CGFloat = 348
    var body: some View {
        HStack(alignment: .top, spacing: Tok.s2) {
            BuddiesCard(store: store, columns: 3)
            PlanColumn(store: store).frame(width: 222)
        }
        .frame(height: Self.height)
    }
}
