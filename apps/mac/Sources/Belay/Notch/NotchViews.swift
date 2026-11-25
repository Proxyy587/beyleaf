import AppKit
import SwiftUI

// The open panel (docs/notch-widgets.md): the user's widgets, packed with no gaps, on tonal cards. Tokens only.

// MARK: - Open panel

struct ExpandedView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var music: NowPlaying
    @ObservedObject var shots: Screenshots
    @ObservedObject var timer: NotchTimer
    @ObservedObject var settings = AppSettings.shared
    var shown: Bool
    /// No notch (external display): the band is the panel's first line instead of sitting beside the camera.
    var showBand: Bool
    var openSettings: () -> Void
    @Namespace private var cards

    var body: some View {
        let rows = WidgetLayout.rows(entries)
        VStack(alignment: .leading, spacing: Tok.s2) {
            if showBand {
                NotchBand(model: model, openSettings: openSettings).blurReveal(shown, delay: 0.03)
            }
            if model.editing {
                WidgetEditor().transition(Tok.reduceMotion ? .opacity : AnyTransition(.blurReplace))
            } else if rows.isEmpty {
                EmptyLine(symbol: "square.grid.2x2", text: "No widgets") {
                    PillButton(title: "Edit widgets") { withAnimation(Tok.open) { model.editing = true } }
                }
                .padding(.horizontal, Tok.s3)
                .blurReveal(shown, delay: 0.05)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.first!.kind) { index, row in
                    HStack(spacing: Tok.s2) {
                        ForEach(row, id: \.kind) { placed in
                            widget(placed)
                                .matchedGeometryEffect(id: placed.kind, in: cards)
                                .contextMenu { menu(placed.kind) }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(Tok.reduceMotion ? .opacity : AnyTransition(.blurReplace))
                    .blurReveal(shown, delay: 0.05 + Double(index) * 0.025)
                }
            }
        }
        .animation(Tok.open, value: rows.map { $0.map(\.kind) })
        .animation(Tok.open, value: model.editing)
        .padding(.horizontal, Tok.s2)
        .padding(.bottom, Tok.s2)
    }

    /// The enabled widgets that have something to show right now, in the user's order, with their size.
    private var entries: [(kind: WidgetKind, size: WidgetSize)] {
        settings.widgets.filter(\.enabled).compactMap { w in
            switch w.kind {
            case .nowPlaying:
                if music.title != nil { return (w.kind, .wide) }
                return music.availablePlayer != nil ? (w.kind, .tile) : nil
            case .timer:
                return (w.kind, .tile)
            case .screenshot:
                guard let c = shots.lastCopied, Date().timeIntervalSince(c.at) < 30 * 60 else { return nil }
                return (w.kind, .tile)
            }
        }
    }

    @ViewBuilder private func widget(_ placed: PlacedWidget) -> some View {
        // Expanded: a pair of tiles has room for each one's full row layout, side by side.
        let p = settings.expanded ? PlacedWidget(kind: placed.kind, size: .wide) : placed
        switch p.kind {
        case .nowPlaying:
            if music.title != nil { NowPlayingCard(music: music) } else { PlayerReadyCard(music: music, size: p.size) }
        case .timer: TimerCard(timer: timer, size: p.size, ticking: shown)
        case .screenshot: if let c = shots.lastCopied { ScreenshotCard(copied: c, shots: shots, size: p.size, ticking: shown) }
        }
    }

    @ViewBuilder private func menu(_ kind: WidgetKind) -> some View {
        Button("Move up") { settings.moveWidget(kind, by: -1) }.disabled(!settings.canMove(kind, by: -1))
        Button("Move down") { settings.moveWidget(kind, by: 1) }.disabled(!settings.canMove(kind, by: 1))
        Button("Hide \(kind.name)") { settings.setEnabled(kind, false) }
        Divider()
        Button("Edit widgets…") { model.editing = true }
    }
}

/// The strip beside the camera: the brand slot on the left; edit and Settings on the right. Glyphs line up with the
/// cards' content edges (cards sit Tok.s2 in, content another Tok.s3).
struct NotchBand: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var settings = AppSettings.shared
    var openSettings: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            BrandSlot().padding(.leading, Tok.s3 - (Tok.button - 16) / 2)
            Spacer(minLength: 0)
            if model.editing {
                PillButton(title: "Done") { withAnimation(Tok.open) { model.editing = false } }
                    .padding(.trailing, Tok.s3)
                    .transition(Tok.reduceMotion ? .opacity : AnyTransition(.blurReplace))
            } else {
                HStack(spacing: 0) {
                    IconButton(symbol: settings.expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                               label: settings.expanded ? "Compact" : "Expand") {
                        withAnimation(Tok.open) { settings.expanded.toggle() }
                    }
                    IconButton(symbol: "square.grid.2x2", label: "Edit widgets") { withAnimation(Tok.open) { model.editing = true } }
                    IconButton(symbol: "gearshape", label: "Open Settings", action: openSettings)
                }
                .padding(.trailing, Tok.s3 - Tok.buttonInset)
                .transition(Tok.reduceMotion ? .opacity : AnyTransition(.blurReplace))
            }
        }
        .animation(Tok.reveal, value: model.editing)
    }
}

// MARK: - Widget anatomy

/// The two shapes every small widget takes (docs/notch-widgets.md §5):
/// - tile: [lead] title on one line, then [status … actions] on the next;
/// - wide: one row, [lead] title over status … actions.
/// Same content, so promotion from tile to wide is a real layout, not a stretched tile.
struct WidgetCard<Lead: View, Title: View, Actions: View>: View {
    let size: WidgetSize
    let status: String
    var live = false
    @ViewBuilder var lead: Lead
    @ViewBuilder var title: Title
    @ViewBuilder var actions: Actions

    var body: some View {
        Group {
            switch size {
            case .tile:
                VStack(alignment: .leading, spacing: Tok.s1) {
                    HStack(spacing: Tok.s2) {
                        lead.frame(width: Tok.gutter, height: Tok.gutter)
                        title.lineLimit(1).truncationMode(.tail)
                        Spacer(minLength: 0)
                    }
                    .frame(height: Tok.button)
                    HStack(spacing: 0) {
                        if !status.isEmpty { StatusLine(text: status, live: live) }
                        Spacer(minLength: Tok.s1)
                        actions
                    }
                    .frame(height: Tok.button)
                    .padding(.trailing, -Tok.buttonInset)
                }
            case .wide:
                HStack(spacing: Tok.s3) {
                    lead.frame(width: Tok.gutter, height: Tok.gutter)
                    VStack(alignment: .leading, spacing: 2) {
                        title.lineLimit(1).truncationMode(.tail)
                        if !status.isEmpty { StatusLine(text: status, live: live) }
                    }
                    Spacer(minLength: Tok.s2)
                    actions.padding(.trailing, -Tok.buttonInset)
                }
                .frame(minHeight: Tok.button)
            }
        }
        .card()
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Now playing

/// A track is known: artwork, title, artist and progress, with the controls on the title's line.
struct NowPlayingCard: View {
    @ObservedObject var music: NowPlaying
    var body: some View {
        HStack(spacing: Tok.s3) {
            Artwork(image: music.artwork, size: Tok.heroArt)
                .opacity(music.isPlaying ? 1 : 0.55)
                .animation(Tok.reveal, value: music.isPlaying)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Tok.s2) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(music.title ?? "").font(Tok.rowTitle).foregroundStyle(Tok.ink)
                            .lineLimit(1).truncationMode(.tail).blurSwap(on: music.title)
                        Text(music.artist ?? "").font(Tok.meta).foregroundStyle(Tok.ink2)
                            .lineLimit(1).truncationMode(.tail).blurSwap(on: music.artist)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 0) {
                        IconButton(symbol: "backward.fill", label: "Previous track") { music.previous() }
                        IconButton(symbol: music.isPlaying ? "pause.fill" : "play.fill", label: music.isPlaying ? "Pause" : "Play") { music.playPause() }
                        IconButton(symbol: "forward.fill", label: "Next track") { music.next() }
                    }
                    .padding(.trailing, -Tok.buttonInset)
                    .padding(.top, -Tok.s1)
                }
                Spacer(minLength: Tok.s1)
                if music.duration > 0 { ProgressBar(music: music) }
            }
            .frame(height: Tok.heroArt)
        }
        .card()
    }
}

/// A player is open but nothing is known or it's stopped: name it, offer Play.
struct PlayerReadyCard: View {
    @ObservedObject var music: NowPlaying
    let size: WidgetSize
    var body: some View {
        let player = music.availablePlayer
        WidgetCard(size: size, status: "Paused") {
            AppIcon(bundleID: player?.bundleID, fallback: "music.note")
        } title: {
            Text(player?.rawValue ?? "Music").font(Tok.rowTitle).foregroundStyle(Tok.ink)
        } actions: {
            IconButton(symbol: "play.fill", label: "Play") { music.playPause() }
        }
    }
}

/// Thin progress line; click or drag to seek. Times in small mono at either end.
struct ProgressBar: View {
    @ObservedObject var music: NowPlaying
    @State private var dragging: Double?
    @State private var hover = false
    var body: some View {
        let f = dragging ?? (music.duration > 0 ? music.position / music.duration : 0)
        HStack(spacing: Tok.s2) {
            Text(clock(f * music.duration)).font(Tok.status).foregroundStyle(Tok.ink3).monospacedDigit()
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tok.ink.opacity(0.14))
                    Capsule().fill(Tok.ink).frame(width: max(0, min(1, f)) * g.size.width)
                }
                .frame(height: hover || dragging != nil ? 5 : 3)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in dragging = max(0, min(1, v.location.x / g.size.width)) }
                    .onEnded { _ in if let d = dragging { music.seek(toFraction: d) }; dragging = nil })
                .onHover { h in withAnimation(Tok.hover) { hover = h } }
            }
            .frame(height: 12)
            Text("-" + clock(max(0, (1 - f) * music.duration))).font(Tok.status).foregroundStyle(Tok.ink3).monospacedDigit()
        }
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue(clock(f * music.duration))
    }
    private func clock(_ s: Double) -> String { let s = Int(s.rounded()); return String(format: "%d:%02d", s / 60, s % 60) }
}

// MARK: - Timer

struct TimerCard: View {
    @ObservedObject var timer: NotchTimer
    let size: WidgetSize
    var ticking = true

    var body: some View {
        switch timer.state {
        case .idle:
            WidgetCard(size: size, status: "") {
                Image(systemName: "timer").font(Tok.icon).foregroundStyle(Tok.ink2)
            } title: {
                Text("Timer").font(Tok.rowTitle).foregroundStyle(Tok.ink)
            } actions: {
                DurationPicker(timer: timer)
            }
        case .running, .paused:
            // One tick a second, only while the panel is open.
            Ticking(seconds: 1, active: ticking && timer.isRunning) { now in
                let p = timer.progress(at: now)
                WidgetCard(size: size, status: status(at: now), live: timer.isRunning) {
                    ProgressRing(fraction: p.fraction, lineWidth: 2.5).padding(2)
                } title: {
                    // No rolling-digit transition or ring animation per tick: together they cost ~10% CPU while
                    // open (measured 2026-11-25) for motion too small to see. Digits swap; the ring steps.
                    Text(countdown(p.remaining)).font(Tok.font(15, .semibold, mono: true)).foregroundStyle(Tok.ink)

                } actions: {
                    if timer.isRunning { IconButton(symbol: "pause.fill", label: "Pause timer") { timer.pause() } }
                    else { IconButton(symbol: "play.fill", label: "Resume timer") { timer.resume() } }
                    IconButton(symbol: "xmark", label: "Stop timer") { timer.stop() }
                }
            }
        case let .done(_, total):
            WidgetCard(size: size, status: "\(Int(total / 60)) min", live: true) {
                Image(systemName: "checkmark").font(Tok.icon).foregroundStyle(Tok.live)
            } title: {
                Text("Done").font(Tok.rowTitle).foregroundStyle(Tok.ink)
            } actions: {
                IconButton(symbol: "arrow.clockwise", label: "Restart timer") { timer.restart() }
                IconButton(symbol: "xmark", label: "Clear timer") { timer.stop() }
            }
        }
    }

    private func status(at now: Date) -> String {
        switch timer.state {
        case let .running(end, _): "Ends " + end.formatted(date: .omitted, time: .shortened)
        case .paused: "Paused"
        default: ""
        }
    }
}

/// − [25m] + ▶. Drag the number sideways to scrub; click ▶ (or the number) to start.
struct DurationPicker: View {
    @ObservedObject var timer: NotchTimer
    @State private var dragStart: Int?
    @State private var hover = false
    var body: some View {
        HStack(spacing: 0) {
            IconButton(symbol: "minus", label: "Shorter") { timer.minutes = NotchTimer.step(timer.minutes, by: -1) }
                .disabled(timer.minutes <= 1)
            Text("\(timer.minutes)m")
                .font(Tok.digits).foregroundStyle(Tok.ink)
                .contentTransition(Tok.reduceMotion ? .identity : .numericText())
                .animation(Tok.reveal, value: timer.minutes)
                .frame(minWidth: 40)
                .frame(height: Tok.button)
                .background(Capsule().fill(hover ? Tok.pressedFill : Tok.hoverFill))
                .contentShape(Capsule())
                .onHover { h in withAnimation(Tok.hover) { hover = h } }
                .gesture(DragGesture(minimumDistance: 2)
                    .onChanged { v in
                        let base = dragStart ?? timer.minutes
                        if dragStart == nil { dragStart = base }
                        var m = base
                        let steps = Int(v.translation.width / 8)
                        for _ in 0..<abs(steps) { m = NotchTimer.step(m, by: steps > 0 ? 1 : -1) }
                        if m != timer.minutes { timer.minutes = m }
                    }
                    .onEnded { _ in dragStart = nil })
                .onTapGesture { timer.start(minutes: timer.minutes) }
                .help("Drag to change, click to start")
                .accessibilityLabel("Timer length")
                .accessibilityValue("\(timer.minutes) minutes")
                .accessibilityAdjustableAction { d in
                    timer.minutes = NotchTimer.step(timer.minutes, by: d == .increment ? 1 : -1)
                }
            IconButton(symbol: "plus", label: "Longer") { timer.minutes = NotchTimer.step(timer.minutes, by: 1) }
                .disabled(timer.minutes >= 180)
            IconButton(symbol: "play.fill", label: "Start timer") { timer.start(minutes: timer.minutes) }
        }
    }
}

// MARK: - Last screenshot

struct ScreenshotCard: View {
    let copied: Screenshots.Copied
    @ObservedObject var shots: Screenshots
    let size: WidgetSize
    var ticking = true
    var body: some View {
        Ticking(seconds: 30, active: ticking) { now in
            WidgetCard(size: size, status: "\(relative(copied.at, now: now)) · \(ByteCountFormatter.string(fromByteCount: Int64(copied.bytes), countStyle: .file))") {
                Thumbnail(url: copied.url)
            } title: {
                Text(size == .tile ? "Copied" : "Screenshot copied").font(Tok.rowTitle).foregroundStyle(Tok.ink)
            } actions: {
                IconButton(symbol: "doc.on.doc", label: "Copy again") { shots.copyAgain() }
                IconButton(symbol: "folder", label: "Show in Finder") { shots.reveal() }
            }
        }
    }
    private func relative(_ d: Date, now: Date) -> String {
        let s = Int(now.timeIntervalSince(d))
        return s < 60 ? "Just now" : s < 3600 ? "\(s / 60) min" : "\(s / 3600) h"
    }
}

// MARK: - Edit mode

/// Arrange widgets by dragging (docs/notch-widgets.md §6). The cards are laid out with the same packing rule as the
/// panel; grab one and it lifts and follows the pointer while the others make room, then it snaps into the slot you
/// dropped it on. − hides a widget; hidden ones wait in the tray below, + brings them back.
struct WidgetEditor: View {
    @ObservedObject var settings = AppSettings.shared
    /// The order while a drag is in flight (enabled widgets only); committed on release.
    @State private var working: [WidgetKind]?
    @State private var dragging: WidgetKind?
    @State private var pointer: CGPoint = .zero
    @State private var grab: CGSize = .zero
    @State private var frames: [WidgetKind: CGRect] = [:]

    private var shown: [WidgetKind] { working ?? settings.widgets.filter(\.enabled).map(\.kind) }
    private var hidden: [WidgetKind] { settings.widgets.filter { !$0.enabled }.map(\.kind) }

    /// Each widget's natural size in the editor (its live size: Now playing is wide, the rest are tiles).
    private static func size(_ k: WidgetKind) -> WidgetSize { k == .nowPlaying ? .wide : .tile }

    var body: some View {
        let rows = WidgetLayout.rows(shown.map { ($0, Self.size($0)) })
        VStack(alignment: .leading, spacing: Tok.s2) {
            ForEach(Array(rows.enumerated()), id: \.element.first!.kind) { _, row in
                HStack(spacing: Tok.s2) {
                    ForEach(row, id: \.kind) { placed in
                        slot(placed)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            if !hidden.isEmpty {
                HStack(spacing: Tok.s1) {
                    ForEach(hidden) { k in
                        Chip(title: "+ \(k.name)", label: "Show \(k.name)") {
                            withAnimation(Tok.open) { settings.setEnabled(k, true) }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Tok.s1)
                .transition(Tok.reduceMotion ? .opacity : AnyTransition(.blurReplace))
            }
            Text(shown.isEmpty ? "Add a widget to show it in the notch." : "Drag to arrange. Small widgets pair up side by side.")
                .font(Tok.meta).foregroundStyle(Tok.ink3)
                .padding(.horizontal, Tok.s3)
        }
        .coordinateSpace(name: "editor")
        .onPreferenceChange(SlotFrames.self) { frames = $0 }
        .overlay(alignment: .topLeading) { lifted }
        .animation(Tok.open, value: shown)
        .animation(Tok.open, value: hidden)
    }

    /// A card in its slot. While it's the one being dragged, the slot shows a quiet placeholder instead.
    @ViewBuilder private func slot(_ p: PlacedWidget) -> some View {
        let isDragged = dragging == p.kind
        EditCard(kind: p.kind, size: p.size) {
            withAnimation(Tok.open) { settings.setEnabled(p.kind, false) }
        }
        .opacity(isDragged ? 0 : 1)
        .background(
            RoundedRectangle(cornerRadius: Tok.rCard, style: .continuous)
                .fill(Tok.ink.opacity(isDragged ? 0.04 : 0))
        )
        .background(GeometryReader { g in
            Color.clear.preference(key: SlotFrames.self, value: [p.kind: g.frame(in: .named("editor"))])
        })
        .gesture(drag(p.kind))
        .accessibilityAction(named: "Move up") { settings.moveWidget(p.kind, by: -1) }
        .accessibilityAction(named: "Move down") { settings.moveWidget(p.kind, by: 1) }
    }

    /// The card under the pointer while dragging: lifted, slightly larger, with the only shadow on the notch.
    @ViewBuilder private var lifted: some View {
        if let k = dragging, let f = frames[k] {
            EditCard(kind: k, size: f.width > 260 ? .wide : .tile, onHide: nil)
                .frame(width: f.width, height: f.height)
                .scaleEffect(Tok.reduceMotion ? 1 : 1.04)
                .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
                .offset(x: pointer.x - grab.width, y: pointer.y - grab.height)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private func drag(_ k: WidgetKind) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("editor"))
            .onChanged { v in
                if dragging == nil, let f = frames[k] {
                    working = shown
                    grab = CGSize(width: v.startLocation.x - f.minX, height: v.startLocation.y - f.minY)
                    withAnimation(Tok.hover) { dragging = k }
                }
                pointer = v.location
                reorder(k, to: v.location)
            }
            .onEnded { _ in
                if let order = working {
                    let rest = settings.widgets.filter { !order.contains($0.kind) }
                    let enabled = order.compactMap { kind in settings.widgets.first { $0.kind == kind } }
                    settings.widgets = enabled + rest
                }
                withAnimation(Tok.open) { dragging = nil; working = nil }
            }
    }

    /// Moves the dragged widget to the slot under the pointer. Only the inner part of a slot counts, so the order
    /// doesn't flap while the pointer sits on a boundary.
    private func reorder(_ k: WidgetKind, to point: CGPoint) {
        guard var order = working, let from = order.firstIndex(of: k) else { return }
        for (other, f) in frames where other != k {
            guard f.insetBy(dx: f.width * 0.2, dy: f.height * 0.2).contains(point), let to = order.firstIndex(of: other) else { continue }
            order.remove(at: from)
            order.insert(k, at: to)
            withAnimation(Tok.open) { working = order }
            return
        }
    }
}

private struct SlotFrames: PreferenceKey {
    static let defaultValue: [WidgetKind: CGRect] = [:]
    static func reduce(value: inout [WidgetKind: CGRect], nextValue: () -> [WidgetKind: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// A widget as it appears while arranging: its symbol and name on its card, a grab affordance, and − to hide.
struct EditCard: View {
    let kind: WidgetKind
    let size: WidgetSize
    var onHide: (() -> Void)?
    @State private var hover = false
    var body: some View {
        HStack(spacing: Tok.s2) {
            Image(systemName: kind.symbol).font(Tok.icon).foregroundStyle(Tok.ink).frame(width: Tok.gutter)
            Text(kind.name).font(Tok.rowTitle).foregroundStyle(Tok.ink).lineLimit(1)
            Spacer(minLength: 0)
            if let onHide {
                IconButton(symbol: "minus", label: "Hide \(kind.name)", action: onHide)
                    .padding(.trailing, -Tok.buttonInset)
            }
        }
        .frame(height: size == .wide ? 56 : Tok.button * 2)
        .card()
        .background(
            RoundedRectangle(cornerRadius: Tok.rCard, style: .continuous).fill(hover ? Tok.ink.opacity(0.03) : .clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: Tok.rCard, style: .continuous))
        .onHover { h in withAnimation(Tok.hover) { hover = h } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(kind.name)
    }
}

// MARK: - Building blocks

/// A one-line empty state: [bare symbol in the gutter] 12 [text in ink2] … [optional action].
struct EmptyLine<Action: View>: View {
    let symbol: String
    let text: String
    @ViewBuilder var action: Action
    var body: some View {
        HStack(spacing: Tok.s3) {
            Image(systemName: symbol).font(Tok.icon).foregroundStyle(Tok.ink3).frame(width: Tok.gutter)
            Text(text).font(Tok.body).foregroundStyle(Tok.ink2).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: Tok.s2)
            action
        }
        .frame(height: Tok.rowHeight)
        .accessibilityElement(children: .contain)
    }
}

extension EmptyLine where Action == EmptyView {
    init(symbol: String, text: String) { self.init(symbol: symbol, text: text) { EmptyView() } }
}

struct IconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled
    @State private var hover = false
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Tok.buttonIcon)
                .foregroundStyle(enabled ? Tok.ink : Tok.ink.opacity(0.25))
                .contentTransition(Tok.reduceMotion ? .identity : .symbolEffect(.replace))
                .frame(width: Tok.button, height: Tok.button)
                .background(Circle().fill(pressed ? Tok.pressedFill : hover && enabled ? Tok.hoverFill : .clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pressable(pressed)
        .help(label)
        .accessibilityLabel(label)
        .onHover { h in withAnimation(Tok.hover) { hover = h } }
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if enabled, !pressed { withAnimation(Tok.hover) { pressed = true } } }
            .onEnded { _ in withAnimation(Tok.hover) { pressed = false } })
    }
}

/// A real app's icon (the player, the terminal); falls back to a bare SF Symbol.
struct AppIcon: View {
    let bundleID: String?
    let fallback: String
    var body: some View {
        if let id = bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().interpolation(.high)
                .frame(width: Tok.gutter, height: Tok.gutter)
        } else {
            Image(systemName: fallback).font(Tok.icon).foregroundStyle(Tok.ink)
        }
    }
}

struct Thumbnail: View {
    let url: URL
    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                .frame(width: Tok.gutter, height: Tok.gutter)
                .clipShape(RoundedRectangle(cornerRadius: Tok.rThumb / 2, style: .continuous))
        } else {
            Image(systemName: "camera.viewfinder").font(Tok.icon).foregroundStyle(Tok.ink)
        }
    }
}

/// Music bars driven by the player's real audio (MusicBeat, ADR 0017): one bar per band, a small lift on each beat.
/// Drawn by Core Animation layers outside SwiftUI's update cycle (BeatBarsLayer): SwiftUI never re-renders per frame.
/// Ink, not live green: the bars are content, and green is kept for status text and dots (docs/design.md §3).
/// Static glyph under reduced motion, when the user turned the bars off, or when capture isn't available.
struct BeatBars: View {
    @ObservedObject var beat: MusicBeat
    var body: some View {
        if beat.state == .listening, !Tok.reduceMotion, AppSettings.shared.equalizerWhilePlaying {
            BeatBarsLayer(source: beat.output, ink: Tok.ink, maxFPS: AppSettings.shared.performance.maxFPS)
                .accessibilityLabel("Playing")
        } else {
            Image(systemName: "waveform").font(Tok.icon).foregroundStyle(Tok.ink2)
                .accessibilityLabel("Playing")
        }
    }
}
