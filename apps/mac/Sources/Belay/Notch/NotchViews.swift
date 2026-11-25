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

    @ViewBuilder private func widget(_ p: PlacedWidget) -> some View {
        switch p.kind {
        case .nowPlaying:
            if music.title != nil { NowPlayingCard(music: music) } else { PlayerReadyCard(music: music, size: p.size) }
        case .timer: TimerCard(timer: timer, size: p.size)
        case .screenshot: if let c = shots.lastCopied { ScreenshotCard(copied: c, shots: shots, size: p.size) }
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
            Artwork(image: music.artwork, size: 56)
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
            .frame(height: 56)
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

    var body: some View {
        switch timer.state {
        case .idle:
            WidgetCard(size: size, status: "") {
                Image(systemName: "timer").font(Tok.icon).foregroundStyle(Tok.ink2)
            } title: {
                Text("Timer").font(Tok.rowTitle).foregroundStyle(Tok.ink)
            } actions: {
                presets
            }
        case .running, .paused:
            // One tick a second, only while this card is on screen.
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let p = timer.progress(at: ctx.date)
                WidgetCard(size: size, status: status(at: ctx.date), live: timer.isRunning) {
                    ProgressRing(fraction: p.fraction, lineWidth: 2.5).padding(2)
                } title: {
                    Text(countdown(p.remaining)).font(Tok.font(15, .semibold, mono: true)).foregroundStyle(Tok.ink)
                        .contentTransition(Tok.reduceMotion ? .identity : .numericText(countsDown: true))
                        .animation(Tok.reveal, value: Int(p.remaining.rounded(.up)))
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

    /// Presets as chips: three fit a tile, four a wide row.
    private var presets: some View {
        HStack(spacing: Tok.s1) {
            ForEach(size == .tile ? Array(NotchTimer.presets.prefix(3)) : NotchTimer.presets, id: \.self) { m in
                Chip(title: "\(m)m", label: "Start a \(m) minute timer") { timer.start(minutes: m) }
            }
        }
        .padding(.trailing, Tok.buttonInset)
    }

    private func status(at now: Date) -> String {
        switch timer.state {
        case let .running(end, _): "Ends " + end.formatted(date: .omitted, time: .shortened)
        case .paused: "Paused"
        default: ""
        }
    }
}

// MARK: - Last screenshot

struct ScreenshotCard: View {
    let copied: Screenshots.Copied
    @ObservedObject var shots: Screenshots
    let size: WidgetSize
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            WidgetCard(size: size, status: "\(relative(copied.at, now: ctx.date)) · \(ByteCountFormatter.string(fromByteCount: Int64(copied.bytes), countStyle: .file))") {
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

/// Every widget as one line: [symbol] name … ↑ ↓ [switch]. Changes apply live and the panel repacks as you go.
struct WidgetEditor: View {
    @ObservedObject var settings = AppSettings.shared
    var body: some View {
        VStack(alignment: .leading, spacing: Tok.s2) {
            VStack(spacing: 0) {
                ForEach(settings.widgets) { w in
                    HStack(spacing: Tok.s3) {
                        Image(systemName: w.kind.symbol).font(Tok.icon).foregroundStyle(w.enabled ? Tok.ink : Tok.ink3)
                            .frame(width: Tok.gutter)
                        Text(w.kind.name).font(Tok.rowTitle).foregroundStyle(w.enabled ? Tok.ink : Tok.ink3)
                        Spacer(minLength: Tok.s2)
                        IconButton(symbol: "chevron.up", label: "Move \(w.kind.name) up") {
                            settings.moveWidget(w.kind, by: -1, skippingDisabled: false)
                        }
                        .disabled(!settings.canMove(w.kind, by: -1, skippingDisabled: false))
                        IconButton(symbol: "chevron.down", label: "Move \(w.kind.name) down") {
                            settings.moveWidget(w.kind, by: 1, skippingDisabled: false)
                        }
                        .disabled(!settings.canMove(w.kind, by: 1, skippingDisabled: false))
                        NotchSwitch(isOn: Binding(get: { w.enabled }, set: { settings.setEnabled(w.kind, $0) }),
                                    label: "Show \(w.kind.name)")
                            .padding(.leading, Tok.s1)
                    }
                    .frame(height: Tok.rowHeight)
                }
            }
            .card(inset: Tok.s3)
            .padding(.vertical, -Tok.s1)
            Text("Widgets with nothing to show take no space.")
                .font(Tok.meta).foregroundStyle(Tok.ink3)
                .padding(.horizontal, Tok.s3)
        }
        .animation(Tok.open, value: settings.widgets)
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
        Button {
            Tok.haptic()
            action()
        } label: {
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
/// Ink, not live green: the bars are content, and green is kept for status text and dots (docs/design.md §3).
/// Static glyph under reduced motion, when the user turned the bars off, or when capture isn't available.
struct BeatBars: View {
    @ObservedObject var beat: MusicBeat
    var body: some View {
        if beat.state == .listening, !Tok.reduceMotion, AppSettings.shared.equalizerWhilePlaying {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<beat.levels.count, id: \.self) { i in
                    Capsule().fill(Tok.ink)
                        .frame(maxHeight: .infinity)
                        .scaleEffect(x: 1, y: CGFloat(0.2 + 0.8 * beat.levels[i]), anchor: .bottom)
                }
            }
            .scaleEffect(1 + 0.12 * CGFloat(beat.pulse), anchor: .bottom)
            .animation(.linear(duration: 1.0 / 30.0), value: beat.levels)
            .accessibilityLabel("Playing")
        } else {
            Image(systemName: "waveform").font(Tok.icon).foregroundStyle(Tok.ink2)
                .accessibilityLabel("Playing")
        }
    }
}
