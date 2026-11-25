import AppKit
import SwiftUI

// The open panel (docs/notch-widgets.md): the user's widgets, packed with no gaps, on tonal cards. Tokens only.

// MARK: - Open panel

struct ExpandedView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var music: NowPlaying
    @ObservedObject var shots: Screenshots
    @ObservedObject var timer: NotchTimer
    @ObservedObject var stopwatch: NotchStopwatch
    @ObservedObject var notes: NotesStore
    @ObservedObject var weather = WeatherService.shared
    @ObservedObject var calendar = CalendarService.shared
    @ObservedObject var settings = AppSettings.shared
    var shown: Bool
    /// No notch (external display): the band is the panel's first line instead of sitting beside the camera.
    var showBand: Bool
    var openSettings: () -> Void

    var body: some View {
        // Pages with something to show (docs/widget-hub.md §1.2). While editing, every enabled page, so an empty one
        // can be filled.
        let visible = model.editing ? settings.pages.filter(\.enabled).map(\.kind) : Pages.visible(settings.pages) { isPresent($0) }
        let current = Pages.resolve(settings.page, visible: visible)
        let columns = WidgetLayout.columns(expanded: settings.expanded)
        let rows = current.map { WidgetLayout.rows(entries(on: $0), columns: columns) } ?? []
        VStack(alignment: .leading, spacing: Tok.s2) {
            if showBand {
                NotchBand(model: model, openSettings: openSettings).blurReveal(shown, delay: 0.03)
            }
            if model.editing {
                WidgetEditor(page: current ?? settings.page, columns: columns).transition(Tok.reduceMotion ? .opacity : AnyTransition(.blurReplace))
            } else if let current {
                // Only the visible page is in the view tree, so hidden pages can't tick, poll or fetch (§7).
                SwipeFollow(swipe: model.swipe) {
                    PageScroller(limit: model.maxContentHeight - chrome) {
                        VStack(alignment: .leading, spacing: Tok.s2) {
                            ForEach(Array(rows.enumerated()), id: \.element.first!.kind) { index, row in
                                SpanRow(columns: columns, spacing: Tok.s2) {
                                    ForEach(row, id: \.kind) { placed in
                                        widget(placed)
                                            .frame(minHeight: WidgetLayout.minHeight(placed.size, button: Tok.button, inset: Tok.s3), maxHeight: .infinity)
                                            .layoutValue(key: SpanColumns.self, value: placed.columns)
                                            .contextMenu { menu(placed.kind, on: current, columns: columns) }
                                    }
                                }
                                .transition(Tok.reduceMotion ? .opacity : AnyTransition(.blurReplace))
                                .blurReveal(shown, delay: 0.05 + Double(index) * 0.025)
                            }
                        }
                        .animation(Tok.open, value: rows.map { $0.map(\.kind) })
                    }
                }
                // Pages slide inside the card edges, so nothing hangs outside the panel mid-swipe.
                .clipped()
                .id(current)
                .transition(pageTransition)
            } else {
                EmptyLine(symbol: "square.grid.2x2", text: "No widgets") {
                    PillButton(title: "Edit widgets") { withAnimation(Tok.open) { model.editing = true } }
                }
                .padding(.horizontal, Tok.s3)
                .blurReveal(shown, delay: 0.05)
            }
        }
        .animation(Tok.open, value: current)
        .animation(Tok.open, value: model.editing)
        .padding(.horizontal, Tok.s2)
        .padding(.bottom, Tok.s2)
        .preference(key: PagesShown.self, value: PagesShown.Value(visible: visible, current: current))
    }

    /// Height the band and the bottom inset take, which the page area can't use.
    private var chrome: CGFloat { (showBand ? Tok.button + Tok.s2 : 0) + Tok.s2 }

    /// The new page slides in from the side you're going to, out of a slight blur; the old one leaves the other way.
    private var pageTransition: AnyTransition {
        if Tok.reduceMotion { return .opacity }
        let d = CGFloat(model.pageStep) * Tok.s6
        // Opacity and offset only: a blur pass over a whole scrolling page, on both the leaving and the arriving view, was
        // the heaviest thing in the transition and the one most likely to be interrupted mid-flight.
        return .asymmetric(insertion: AnyTransition.opacity.combined(with: .offset(x: d)),
                           removal: AnyTransition.opacity.combined(with: .offset(x: -d)))
    }

    /// Whether a widget has something to show right now (live or ready); `false` means gone, taking no space. Its size
    /// is the user's choice (its span), never decided here (ADR 0023).
    private func isPresent(_ kind: WidgetKind) -> Bool {
        switch kind {
        case .clock, .timer, .stopwatch, .notes: return true
        case .nowPlaying: return music.title != nil || music.availablePlayer != nil
        case .calendar:
            // A free day isn't news: with access and nothing in the next 24 h, the widget is gone.
            if calendar.access == .full { return !CalendarLogic.upcoming(calendar.events, now: Date()).isEmpty }
            return true
        case .weather:
            // Gone, not stale: offline with a forecast older than 3 hours takes no space (docs/widget-hub.md §3.7).
            if settings.weatherCity != nil, weather.failed, let f = weather.forecast, WeatherLogic.isTooStale(f, now: Date()) { return false }
            return true
        case .screenshot:
            guard let c = shots.lastCopied else { return false }
            return Date().timeIntervalSince(c.at) < 30 * 60
        }
    }

    /// The page's enabled widgets that have something to show right now, in the user's order, with the user's size.
    private func entries(on page: PageKind) -> [(kind: WidgetKind, span: WidgetSpan)] {
        (settings.pageSetting(page)?.widgets ?? []).filter { $0.enabled && isPresent($0.kind) }.map { ($0.kind, $0.span) }
    }

    @ViewBuilder private func widget(_ placed: PlacedWidget) -> some View {
        let p = placed
        switch p.kind {
        case .clock: ClockCard(zones: settings.clockZones, size: p.size, ticking: shown)
        case .nowPlaying:
            if music.title != nil { NowPlayingCard(music: music, size: p.size) } else { PlayerReadyCard(music: music, size: p.size) }
        case .timer: TimerCard(timer: timer, size: p.size, ticking: shown)
        case .stopwatch: StopwatchCard(stopwatch: stopwatch, size: p.size, ticking: shown)
        case .notes: NotesCard(notes: notes, columns: p.columns)
        case .calendar: CalendarCard(calendar: calendar, size: p.size, ticking: shown)
        case .weather: WeatherCard(weather: weather, city: settings.weatherCity, fahrenheit: settings.weatherUnits.isFahrenheit(), size: p.size, openSettings: openSettings)
        case .screenshot: if let c = shots.lastCopied { ScreenshotCard(copied: c, shots: shots, size: p.size, ticking: shown) }
        }
    }

    @ViewBuilder private func menu(_ kind: WidgetKind, on page: PageKind, columns: Int) -> some View {
        Menu("Size") {
            ForEach(kind.spans.filter { $0.rawValue <= columns }) { span in
                Button(span.name) { withAnimation(Tok.open) { settings.setSpan(kind, span) } }
                    .disabled(min(settings.span(of: kind).rawValue, columns) == span.rawValue)
            }
        }
        Button("Move up") { settings.moveWidget(kind, by: -1) }.disabled(!settings.canMove(kind, by: -1))
        Button("Move down") { settings.moveWidget(kind, by: 1) }.disabled(!settings.canMove(kind, by: 1))
        Menu("Move to") {
            ForEach(PageKind.allCases.filter { $0 != page }) { other in
                Button(other.name) { withAnimation(Tok.open) { settings.moveWidget(kind, to: other) } }
            }
        }
        Button("Hide \(kind.name)") { settings.setEnabled(kind, false) }
        Divider()
        Button("Edit widgets…") { model.editing = true }
    }
}

/// The pages the open panel shows and the one on screen, reported up to the model (dots, swipe, keys).
struct PagesShown: PreferenceKey {
    struct Value: Equatable { var visible: [PageKind] = []; var current: PageKind? }
    static let defaultValue = Value()
    static func reduce(value: inout Value, nextValue: () -> Value) { let n = nextValue(); if !n.visible.isEmpty { value = n } }
}

/// Applies the swipe-follow offset. Only this wrapper observes the swipe, so moving fingers never re-lays out the panel.
struct SwipeFollow<Content: View>: View {
    @ObservedObject var swipe: SwipeState
    @ViewBuilder var content: Content
    var body: some View {
        // Render-only: an offset and a fade, no layout per scroll event (docs/widget-hub.md §7).
        content.offset(x: swipe.offset).opacity(1 - Double(abs(swipe.offset)) / 120)
    }
}

/// A page's rows. Taller than the room, they scroll vertically (no scrollbar, edges fade to hint at more); otherwise
/// the area is exactly as tall as the rows, so the panel hugs them as before.
struct PageScroller<Content: View>: View {
    let limit: CGFloat
    @ViewBuilder var content: Content
    @State private var natural: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var edges = (top: false, bottom: false)

    var body: some View {
        let fit = PanelFit.fit(natural: natural, limit: limit)
        ScrollView(.vertical, showsIndicators: false) {
            content
                .background(GeometryReader { g in
                    Color.clear.preference(key: PageMetrics.self, value: PageMetrics.Value(height: g.size.height, offset: -g.frame(in: .named("page")).minY))
                })
        }
        .coordinateSpace(name: "page")
        .scrollDisabled(!fit.scrolls)
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: max(0, limit))
        .mask(fade(fit.scrolls))
        .onPreferenceChange(PageMetrics.self) { m in
            if abs(m.height - natural) > 0.5 { natural = m.height }
            let e = PanelFit.edges(offset: m.offset, natural: m.height, visible: min(m.height, limit))
            if e != edges { withAnimation(Tok.reveal) { edges = e } }
        }
    }

    /// Opaque, with a short fade on each edge that has more content beyond it.
    private func fade(_ scrolls: Bool) -> some View {
        let f = Tok.s5 / max(1, min(natural, limit))
        return LinearGradient(stops: [
            .init(color: scrolls && edges.top ? .clear : .black, location: 0),
            .init(color: .black, location: f),
            .init(color: .black, location: 1 - f),
            .init(color: scrolls && edges.bottom ? .clear : .black, location: 1),
        ], startPoint: .top, endPoint: .bottom)
    }
}

struct PageMetrics: PreferenceKey {
    struct Value: Equatable { var height: CGFloat = 0; var offset: CGFloat = 0 }
    static let defaultValue = Value()
    static func reduce(value: inout Value, nextValue: () -> Value) { value = nextValue() }
}

/// One dot per visible page, beside the brand slot (docs/widget-hub.md §1.4). Hidden with a single page.
struct PageDots: View {
    @ObservedObject var model: NotchModel
    @State private var hover: PageKind?
    var body: some View {
        let pages = model.visiblePages
        if pages.count > 1 {
            HStack(spacing: 0) {
                ForEach(pages) { p in
                    Button { model.go(to: p) } label: {
                        Circle()
                            .fill(p == model.currentPage ? Tok.ink : hover == p ? Tok.ink2 : Tok.ink3)
                            .frame(width: 6, height: 6)
                            .frame(width: 14, height: Tok.button)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(p.name)
                    .onHover { h in withAnimation(Tok.hover) { hover = h ? p : (hover == p ? nil : hover) } }
                }
            }
            .animation(Tok.hover, value: model.currentPage)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page")
            .accessibilityValue(value(pages))
            .accessibilityAdjustableAction { d in model.go(by: d == .increment ? 1 : -1) }
            .transition(.opacity)
        }
    }
    private func value(_ pages: [PageKind]) -> String {
        guard let c = model.currentPage, let i = pages.firstIndex(of: c) else { return "" }
        return "\(i + 1) of \(pages.count), \(c.name)"
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
            PageDots(model: model).padding(.leading, Tok.s1)
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
        .animation(Tok.reveal, value: model.visiblePages.count > 1)
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

/// A track is known. Wide: artwork, title, artist and progress, with the controls on the title's line. Tile: artwork,
/// title and artist (truncated), and play/pause.
struct NowPlayingCard: View {
    @ObservedObject var music: NowPlaying
    var size: WidgetSize = .wide
    var body: some View {
        if size == .tile { tile } else { wide }
    }

    private var tile: some View {
        HStack(spacing: Tok.s2) {
            Artwork(image: music.artwork, size: 44)
                .opacity(music.isPlaying ? 1 : 0.55)
                .animation(Tok.reveal, value: music.isPlaying)
            VStack(alignment: .leading, spacing: 2) {
                Text(music.title ?? "").font(Tok.rowTitle).foregroundStyle(Tok.ink)
                    .lineLimit(1).truncationMode(.tail).blurSwap(on: music.title)
                Text(music.artist ?? "").font(Tok.meta).foregroundStyle(Tok.ink2)
                    .lineLimit(1).truncationMode(.tail).blurSwap(on: music.artist)
            }
            Spacer(minLength: 0)
            IconButton(symbol: music.isPlaying ? "pause.fill" : "play.fill", label: music.isPlaying ? "Pause" : "Play") { music.playPause() }
                .padding(.trailing, -Tok.buttonInset)
        }
        .card()
        .frame(maxHeight: .infinity)
    }

    private var wide: some View {
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
        .frame(maxHeight: .infinity)
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

// MARK: - Clock

/// Large local time and date; with other zones, up to three more on the right (docs/widget-hub.md §3.1).
/// Ticks once a minute, on the minute, and only while its page is on screen.
struct ClockCard: View {
    let zones: [String]
    let size: WidgetSize
    var ticking = true

    var body: some View {
        Ticking(seconds: 60, active: ticking) { now in
            let is24 = ClockLogic.system24Hour
            HStack(alignment: .center, spacing: Tok.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ClockLogic.time(now, in: .current, is24: is24)).font(Tok.display).foregroundStyle(Tok.ink)
                    StatusLine(text: ClockLogic.dateLine(now), live: false)
                }
                if size == .wide, !zones.isEmpty {
                    Spacer(minLength: Tok.s3)
                    Grid(alignment: .leading, horizontalSpacing: Tok.s2, verticalSpacing: 2) {
                        ForEach(zones, id: \.self) { id in
                            if let z = TimeZone(identifier: id) { zoneRow(id, z, now, is24) }
                        }
                    }
                    .fixedSize()
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ClockLogic.spoken(now, zones: zones, is24: is24))
        }
        .frame(maxHeight: .infinity)
    }

    private func zoneRow(_ id: String, _ z: TimeZone, _ now: Date, _ is24: Bool) -> some View {
        GridRow {
            Text(ClockLogic.city(id)).font(Tok.meta).foregroundStyle(Tok.ink2).lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: 110, alignment: .trailing).gridColumnAlignment(.trailing)
            Text(ClockLogic.time(now, in: z, is24: is24)).font(Tok.digits).foregroundStyle(Tok.ink)
            Text(ClockLogic.note(now, zone: z)).font(Tok.status).foregroundStyle(Tok.ink3)
        }
    }
}

// MARK: - Calendar

/// The next events and how long until the first; Join when a video link is found. Asked for access once, on click.
struct CalendarCard: View {
    @ObservedObject var calendar: CalendarService
    let size: WidgetSize
    var ticking = true

    var body: some View {
        switch calendar.access {
        case .notDetermined:
            ready(status: "", label: "Calendar") {
                PillButton(title: "Show events") { Task { await calendar.requestAccess() } }
            }
        case .writeOnly:
            ready(status: "Needs full access", label: "Calendar needs full access") { PillButton(title: "Open Settings", action: Self.openPrivacy) }
        case .denied:
            ready(status: "Access is off", label: "Calendar access is off") { PillButton(title: "Open Settings", action: Self.openPrivacy) }
        case .full:
            // Countdown text changes once a minute, only while this page is on screen.
            Ticking(seconds: 60, active: ticking) { now in live(now) }
                .task { calendar.refresh() }
        }
    }

    private func ready<A: View>(status: String, label: String, @ViewBuilder action: () -> A) -> some View {
        WidgetCard(size: size, status: status) {
            Image(systemName: "calendar").font(Tok.icon).foregroundStyle(Tok.ink2)
        } title: {
            Text("Calendar").font(Tok.rowTitle).foregroundStyle(Tok.ink)
        } actions: { action() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private func live(_ now: Date) -> some View {
        let is24 = ClockLogic.system24Hour
        let list = CalendarLogic.upcoming(calendar.events, now: now, limit: size == .tile ? 1 : 3)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, e in
                if size == .tile { tileEvent(e, now: now, is24: is24) } else {
                let link = CalendarLogic.joinLink(url: e.url, location: e.location, notes: e.notes)
                HStack(spacing: Tok.s2) {
                    Circle().fill(Color(hex: e.colorHex)).frame(width: 8, height: 8).frame(width: Tok.gutter)
                    Text(e.title).font(Tok.rowTitle).foregroundStyle(Tok.ink).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: Tok.s2)
                    if index == 0, let c = CalendarLogic.countdown(e, now: now) {
                        Text(c).font(Tok.status).foregroundStyle(CalendarLogic.isImminent(e, now: now) ? Tok.live : Tok.ink2)
                    }
                    Text(CalendarLogic.timeRange(e, is24: is24)).font(Tok.status).foregroundStyle(Tok.ink3)
                    if let link { IconButton(symbol: "video", label: "Join call") { NSWorkspace.shared.open(link) } }
                }
                .frame(height: Tok.button)
                .padding(.trailing, link == nil ? 0 : -Tok.buttonInset)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(CalendarLogic.spoken(e, now: now, is24: is24))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card()
    }

    /// The tile shows only the next event: its title and join on one line, its countdown and time on the next.
    private func tileEvent(_ e: CalEvent, now: Date, is24: Bool) -> some View {
        let link = CalendarLogic.joinLink(url: e.url, location: e.location, notes: e.notes)
        return VStack(alignment: .leading, spacing: Tok.s1) {
            HStack(spacing: Tok.s2) {
                Circle().fill(Color(hex: e.colorHex)).frame(width: 8, height: 8).frame(width: Tok.gutter)
                Text(e.title).font(Tok.rowTitle).foregroundStyle(Tok.ink).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .frame(height: Tok.button)
            HStack(spacing: Tok.s2) {
                if let c = CalendarLogic.countdown(e, now: now) {
                    Text(c).font(Tok.status).foregroundStyle(CalendarLogic.isImminent(e, now: now) ? Tok.live : Tok.ink2).lineLimit(1)
                }
                Text(CalendarLogic.timeRange(e, is24: is24)).font(Tok.status).foregroundStyle(Tok.ink3).lineLimit(1)
                Spacer(minLength: 0)
                if let link { IconButton(symbol: "video", label: "Join call") { NSWorkspace.shared.open(link) } }
            }
            .frame(height: Tok.button)
            .padding(.trailing, link == nil ? 0 : -Tok.buttonInset)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(CalendarLogic.spoken(e, now: now, is24: is24))
    }

    private static func openPrivacy() {
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") { NSWorkspace.shared.open(u) }
    }
}

// MARK: - Weather

/// Temperature now, today's range, and (wide) when rain starts. Open-Meteo asks for a link wherever its data shows.
struct WeatherCard: View {
    @ObservedObject var weather: WeatherService
    let city: WeatherCity?
    let fahrenheit: Bool
    let size: WidgetSize
    var openSettings: () -> Void

    var body: some View {
        Group {
            if let city {
                if let f = weather.forecast {
                    live(city, f)
                } else if weather.failed {
                    WidgetCard(size: size, status: "Couldn't reach Open-Meteo") {
                        Image(systemName: "cloud.sun").font(Tok.icon).foregroundStyle(Tok.ink2)
                    } title: {
                        Text("Weather").font(Tok.rowTitle).foregroundStyle(Tok.ink)
                    } actions: {
                        PillButton(title: "Retry") { Task { await weather.retry(for: city) } }
                    }
                } else {
                    WidgetCard(size: size, status: "\(city.name.uppercased()) · LOADING") {
                        Image(systemName: "cloud.sun").font(Tok.icon).foregroundStyle(Tok.ink2)
                    } title: {
                        Text("Weather").font(Tok.rowTitle).foregroundStyle(Tok.ink)
                    } actions: { EmptyView() }
                }
            } else {
                WidgetCard(size: size, status: "") {
                    Image(systemName: "cloud.sun").font(Tok.icon).foregroundStyle(Tok.ink2)
                } title: {
                    Text("Weather").font(Tok.rowTitle).foregroundStyle(Tok.ink)
                } actions: {
                    PillButton(title: "Choose city", action: openSettings)
                }
            }
        }
        // Fetch only while this card is on screen (the Day page), and only when the forecast is older than 30 minutes.
        .task(id: city) { if let city { await weather.refreshIfNeeded(for: city) } }
    }

    private func live(_ city: WeatherCity, _ f: WeatherForecast) -> some View {
        let now = Date()
        return WidgetCard(size: size, status: WeatherLogic.status(city: city, f, fahrenheit: fahrenheit, offline: weather.failed)) {
            Image(systemName: WeatherLogic.condition(f.code).symbol).font(Tok.icon).foregroundStyle(Tok.ink)
        } title: {
            Text(WeatherLogic.degrees(f.temperature, fahrenheit: fahrenheit)).font(Tok.title).foregroundStyle(Tok.ink)
        } actions: {
            if size == .wide { Text(WeatherLogic.rainHint(f, now: now)).font(Tok.body).foregroundStyle(Tok.ink2).padding(.trailing, Tok.s2) }
            Button { if let u = URL(string: "https://open-meteo.com") { NSWorkspace.shared.open(u) } } label: {
                Text("Open-Meteo").font(Tok.status).foregroundStyle(Tok.ink3).padding(.horizontal, Tok.s2).frame(height: Tok.button)
            }
            .buttonStyle(.plain).help("Weather data by Open-Meteo.com (CC BY 4.0)")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WeatherLogic.spoken(city: city, f, fahrenheit: fahrenheit, now: now))
    }
}

// MARK: - Notes

/// One field captures and searches: typing filters the list, Return saves. Always ready, wide only.
struct NotesCard: View {
    @ObservedObject var notes: NotesStore
    /// Columns the card spans: more columns, more notes (2, 3, 5).
    let columns: Int
    @FocusState private var focused: Bool

    var body: some View {
        let shown = Array(notes.matches.prefix(columns >= 3 ? 5 : columns == 2 ? 3 : 2))
        VStack(alignment: .leading, spacing: Tok.s2) {
            HStack(spacing: Tok.s2) {
                Image(systemName: "square.and.pencil").font(Tok.icon).foregroundStyle(Tok.ink2)
                    .frame(width: Tok.gutter, height: Tok.gutter)
                TextField("Capture a note", text: $notes.draft)
                    .textFieldStyle(.plain).font(Tok.body).foregroundStyle(Tok.ink)
                    .focused($focused)
                    .onSubmit { notes.saveDraft() }
                    .accessibilityLabel("Capture a note")
                Spacer(minLength: Tok.s1)
                if notes.saveFailed {
                    StatusLine(text: "Not saved", live: false).foregroundStyle(Tok.warning)
                } else if let undo = notes.undoable {
                    PillButton(title: "Undo") { withAnimation(Tok.open) { notes.undoDelete() } }
                        .help("Restore \"\(undo.text.prefix(40))\"")
                } else if columns > 1 {
                    StatusLine(text: NotesLogic.count(total: notes.notes.count, matches: notes.isSearching ? notes.matches.count : nil), live: false)
                }
            }
            .frame(minHeight: Tok.button)
            if !shown.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(shown) { note in
                        NoteRow(note: note, delete: { withAnimation(Tok.open) { notes.delete(note) } })
                            .transition(Tok.reduceMotion ? .opacity : AnyTransition(.blurReplace))
                    }
                }
                .animation(Tok.open, value: shown.map(\.id))
            }
        }
        .card()
        .onAppear {
            notes.loadIfNeeded()   // read the first time the page shows, never at launch
            if notes.closeAfterSave { focused = true }
        }
        .onChange(of: notes.focusRequest) { focused = true }
    }
}

private struct NoteRow: View {
    let note: Note
    let delete: () -> Void
    @State private var hover = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: Tok.s2) {
            Text(note.text).font(Tok.body).foregroundStyle(Tok.ink).lineLimit(1).truncationMode(.tail)
                .help(note.text)
            Spacer(minLength: Tok.s2)
            if hover {
                IconButton(symbol: copied ? "checkmark" : "doc.on.doc", label: "Copy") {
                    // A user action, so it may write the clipboard.
                    NSPasteboard.general.clearContents(); NSPasteboard.general.setString(note.text, forType: .string)
                    copied = true
                }
                IconButton(symbol: "trash", label: "Delete", action: delete)
            } else {
                TimelineView(.everyMinute) { ctx in
                    Text(NotesLogic.age(note.created, now: ctx.date)).font(Tok.status).foregroundStyle(Tok.ink3)
                }
            }
        }
        .frame(height: Tok.button)
        .padding(.trailing, hover ? -Tok.buttonInset : 0)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(Tok.hover) { hover = h; if !h { copied = false } } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(note.text)
        .accessibilityAction(named: "Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(note.text, forType: .string) }
        .accessibilityAction(named: "Delete", delete)
    }
}

// MARK: - Stopwatch

/// Ready: one action. Running or paused: elapsed time, lap and pause (or reset and resume). Wide adds the last three laps.
struct StopwatchCard: View {
    @ObservedObject var stopwatch: NotchStopwatch
    let size: WidgetSize
    var ticking = true

    var body: some View {
        let s = stopwatch.state
        if s.isReady {
            WidgetCard(size: size, status: "") {
                Image(systemName: "stopwatch").font(Tok.icon).foregroundStyle(Tok.ink2)
            } title: {
                Text("Stopwatch").font(Tok.rowTitle).foregroundStyle(Tok.ink)
            } actions: {
                IconButton(symbol: "play.fill", label: "Start stopwatch") { stopwatch.start() }
            }
        } else {
            // One tick a second while running, only while the page is visible. Paused shows hundredths and never ticks.
            Ticking(seconds: 1, active: ticking && s.isRunning) { now in
                let e = stopwatch.elapsed(at: now)
                WidgetCard(size: size, status: s.isRunning ? "Running" : "Paused", live: s.isRunning) {
                    Image(systemName: "stopwatch").font(Tok.icon).foregroundStyle(s.isRunning ? Tok.live : Tok.ink2)
                } title: {
                    Text(s.isRunning ? StopwatchFormat.elapsed(e) : StopwatchFormat.precise(e))
                        .font(Tok.font(15, .semibold, mono: true)).foregroundStyle(Tok.ink)
                } actions: {
                    if size == .wide, !s.recentLaps.isEmpty {
                        VStack(alignment: .trailing, spacing: 2) {
                            ForEach(s.recentLaps, id: \.number) { lap in
                                HStack(spacing: Tok.s2) {
                                    Text("Lap \(lap.number)").font(Tok.status).foregroundStyle(Tok.ink3)
                                    Text(StopwatchFormat.precise(lap.time)).font(Tok.digits).foregroundStyle(Tok.ink)
                                }
                            }
                        }
                        .padding(.trailing, Tok.buttonInset + Tok.s2)
                    }
                    if s.isRunning {
                        IconButton(symbol: "flag.fill", label: "Lap") { stopwatch.lap() }
                        IconButton(symbol: "pause.fill", label: "Pause stopwatch") { stopwatch.pause() }
                    } else {
                        IconButton(symbol: "arrow.counterclockwise", label: "Reset stopwatch") { stopwatch.reset() }
                        IconButton(symbol: "play.fill", label: "Resume stopwatch") { stopwatch.resume() }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(StopwatchFormat.spoken(e, running: s.isRunning))
            }
        }
    }
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

/// Arrange widgets (docs/notch-widgets.md §6, ADR 0023). The cards sit in the same span grid as the panel; grab one and
/// it lifts and follows the pointer while the others make room, then it snaps into the slot you dropped it on. Tap a
/// card to change its size. − hides a widget; hidden ones wait in the tray below, + brings them back.
struct WidgetEditor: View {
    /// The page being arranged; the dots still switch pages while editing.
    let page: PageKind
    /// The grid's columns (2, or 3 when expanded).
    let columns: Int
    @ObservedObject var settings = AppSettings.shared
    /// The order while a drag is in flight (enabled widgets only); committed on release.
    @State private var working: [WidgetKind]?
    @State private var dragging: WidgetKind?
    @State private var pointer: CGPoint = .zero
    @State private var grab: CGSize = .zero
    @State private var frames: [WidgetKind: CGRect] = [:]

    private var shown: [WidgetKind] { working ?? (settings.pageSetting(page)?.widgets ?? []).filter(\.enabled).map(\.kind) }
    /// Hidden widgets from every page: + puts one on this page (how widgets move between pages in the notch).
    private var hidden: [WidgetKind] { settings.hiddenWidgets }

    var body: some View {
        let rows = WidgetLayout.rows(shown.map { ($0, settings.span(of: $0)) }, columns: columns)
        VStack(alignment: .leading, spacing: Tok.s2) {
            ForEach(Array(rows.enumerated()), id: \.element.first!.kind) { _, row in
                SpanRow(columns: columns, spacing: Tok.s2) {
                    ForEach(row, id: \.kind) { placed in
                        slot(placed).layoutValue(key: SpanColumns.self, value: placed.columns)
                    }
                }
            }
            if !hidden.isEmpty {
                HStack(spacing: Tok.s1) {
                    ForEach(hidden) { k in
                        Chip(title: "+ \(k.name)", label: "Show \(k.name) on \(page.name)") {
                            withAnimation(Tok.open) { settings.moveWidget(k, to: page) }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Tok.s1)
                .transition(Tok.reduceMotion ? .opacity : AnyTransition(.blurReplace))
            }
            Text(shown.isEmpty ? "Add a widget to show it on \(page.name)." : "Drag to arrange. Tap a widget to change its size.")
                .font(Tok.meta).foregroundStyle(Tok.ink3)
                .padding(.horizontal, Tok.s3)
        }
        .coordinateSpace(name: "editor")
        .onPreferenceChange(SlotFrames.self) { frames = $0 }
        .overlay(alignment: .topLeading) { lifted }
        .animation(Tok.open, value: shown)
        .animation(Tok.open, value: hidden)
        .animation(Tok.open, value: shown.map { settings.span(of: $0) })
        .id(page)
    }

    /// A card in its slot. While it's the one being dragged, the slot shows a quiet placeholder instead.
    @ViewBuilder private func slot(_ p: PlacedWidget) -> some View {
        let isDragged = dragging == p.kind
        EditCard(kind: p.kind, span: settings.span(of: p.kind), columns: columns,
                 onCycle: { withAnimation(Tok.open) { settings.cycleSpan(p.kind, columns: columns) } },
                 onHide: { withAnimation(Tok.open) { settings.setEnabled(p.kind, false) } })
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
            EditCard(kind: k, span: settings.span(of: k), columns: columns, onCycle: nil, onHide: nil)
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
                if let order = working { settings.setOrder(order, on: page) }
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

/// A widget as it appears while arranging: its symbol and name on its card, its size, and − to hide. Tap to change size.
struct EditCard: View {
    let kind: WidgetKind
    let span: WidgetSpan
    let columns: Int
    var onCycle: (() -> Void)?
    var onHide: (() -> Void)?
    @State private var hover = false
    var body: some View {
        HStack(spacing: Tok.s2) {
            Image(systemName: kind.symbol).font(Tok.icon).foregroundStyle(Tok.ink).frame(width: Tok.gutter)
            Text(kind.name).font(Tok.rowTitle).foregroundStyle(Tok.ink).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 0)
            SpanGlyph(span: span, columns: columns)
            if let onHide {
                IconButton(symbol: "minus", label: "Hide \(kind.name)", action: onHide)
                    .padding(.trailing, -Tok.buttonInset)
            }
        }
        .frame(height: 56)
        .card()
        .background(
            RoundedRectangle(cornerRadius: Tok.rCard, style: .continuous).fill(hover ? Tok.ink.opacity(0.03) : .clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: Tok.rCard, style: .continuous))
        .onHover { h in withAnimation(Tok.hover) { hover = h } }
        .onTapGesture { onCycle?() }
        .help("Tap to change size (now \(span.name.lowercased()))")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(kind.name), \(span.name.lowercased())")
        .accessibilityAction(named: "Change size") { onCycle?() }
    }
}

/// The widget's size at a glance: one cell per grid column, filled for the columns it takes.
struct SpanGlyph: View {
    let span: WidgetSpan
    let columns: Int
    var body: some View {
        let taken = min(span.rawValue, columns)
        HStack(spacing: 2) {
            ForEach(0..<columns, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Tok.ink.opacity(i < taken ? 0.7 : 0.2))
                    .frame(width: 6, height: 10)
            }
        }
        .accessibilityHidden(true)
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

// MARK: - Span grid

/// How many grid columns a cell takes (set with `.layoutValue`).
struct SpanColumns: LayoutValueKey { static let defaultValue = 1 }

/// One row of the panel's grid: every column the same width, each child as wide as its span, all as tall as the tallest.
/// Columns the row doesn't use stay empty (ADR 0023: the user's arrangement is never re-packed).
struct SpanRow: Layout {
    var columns: Int
    var spacing: CGFloat

    private func cell(_ subview: LayoutSubview, _ column: CGFloat) -> CGFloat {
        let n = CGFloat(min(max(1, subview[SpanColumns.self]), columns))
        return column * n + spacing * (n - 1)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? CGFloat(columns) * 200
        let column = WidgetLayout.columnWidth(inner: width, columns: columns, gap: spacing)
        let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: cell($0, column), height: nil)).height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let column = WidgetLayout.columnWidth(inner: bounds.width, columns: columns, gap: spacing)
        var x = bounds.minX
        for subview in subviews {
            let w = cell(subview, column)
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(width: w, height: bounds.height))
            x += w + spacing
        }
    }
}
