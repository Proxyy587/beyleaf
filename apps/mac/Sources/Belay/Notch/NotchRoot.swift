import SwiftUI

/// The whole notch: a black shape that springs between the hardware-notch size and the open panel, with settings-driven
/// wings while closed and the open panel while open.
struct NotchRoot: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var music: NowPlaying
    @ObservedObject var status: SystemStatus
    @ObservedObject var shots: Screenshots
    @ObservedObject var timer: NotchTimer
    @ObservedObject var activities: ActivityCenter
    var beat: MusicBeat
    @ObservedObject var settings = AppSettings.shared
    var openSettings: () -> Void
    var openFromClick: () -> Void = {}

    /// Room either side of the camera in the open panel, for the band (inside the ears and the card inset).
    private var bandSide: CGFloat { (model.openWidth - model.metrics.notchSize.width) / 2 - Tok.rOpenEar - Tok.s2 }
    /// Put the band beside the camera when there's room (expand, edit and Settings need 3 × 28 pt); otherwise it's
    /// the panel's first line, below the notch line.
    private var headerInBand: Bool { model.metrics.hasNotch && bandSide >= 3 * Tok.button + Tok.s2 }

    var body: some View {
        let open = model.isOpen
        let size = open ? model.openSize : model.closedSize
        let notchH = model.metrics.notchSize.height

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                background(open: open).frame(width: size.width, height: size.height)

                HStack(spacing: 0) {
                    wing(.leading).frame(width: model.wingWidth)
                    Spacer(minLength: 0)
                    wing(.trailing).frame(width: model.wingWidth)
                }
                .frame(width: model.metrics.notchSize.width + 2 * model.wingWidth, height: notchH)
                .id(settings.themeRevision)
                .opacity(open || !model.wingsVisible ? 0 : 1)
                .blur(radius: open || !model.wingsVisible ? Tok.blur : 0)
                .animation(Tok.reveal, value: open)

                if headerInBand {
                    NotchBand(model: model, openSettings: openSettings)
                        .frame(width: model.openWidth - 2 * (Tok.rOpenEar + Tok.s2), height: notchH)
                        .blurReveal(open, delay: 0.03)
                        .allowsHitTesting(open)
                        .id(settings.themeRevision)
                }

                ExpandedView(model: model, music: music, shots: shots, timer: timer, shown: open, showBand: !headerInBand, openSettings: openSettings)
                    .padding(.horizontal, Tok.rOpenEar)
                    .padding(.top, notchH)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(GeometryReader { g in Color.clear.preference(key: ContentHeight.self, value: g.size.height - notchH) })
                    .frame(width: model.openWidth)
                    // Resolve the panel's layout once and move it as a unit while the shape springs around it.
                    .geometryGroup()
                    .allowsHitTesting(open)
                    .id(settings.themeRevision)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            // Click mode's target: exists only while closed, so it never competes with the open panel's controls.
            .overlay {
                if !open && settings.openOnClick {
                    Color.clear.contentShape(Rectangle()).onTapGesture { openFromClick() }
                        .accessibilityAddTraits(.isButton).accessibilityLabel("Open Belay")
                }
            }
            .clipped()
            .shadow(color: .black.opacity(open ? Tok.shadow : 0), radius: open ? 20 : 0, y: open ? 10 : 0)
            .padding(.top, model.metrics.hasNotch ? 0 : Tok.s2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onPreferenceChange(PagesShown.self) { v in
            if v.visible != model.visiblePages { model.visiblePages = v.visible }
            if v.current != model.currentPage { model.currentPage = v.current }
        }
        .onPreferenceChange(ContentHeight.self) { h in
            if h > 0, abs(h - model.openContentHeight) > 0.5 { model.openContentHeight = h }
        }
    }

    @ViewBuilder private func wing(_ side: HorizontalEdge) -> some View {
        // Wings exist only for live activities: at rest the closed notch fits the hardware exactly (ui-inventory §1.1).
        if let a = activities.current {
            ActivityWing(activity: a, side: side, music: music, shots: shots, beat: beat, timer: timer)
                .blurSwap(on: a)
        }
    }

    @ViewBuilder private func background(open: Bool) -> some View {
        if model.metrics.hasNotch {
            // Closed: no outward flare, so the shape sits exactly on the hardware notch; bottom corners match it.
            surface(open: open, shape: NotchShape(earRadius: open ? Tok.rOpenEar : 0, bottomRadius: open ? Tok.rOpenBottom : 9))
        } else {
            surface(open: open, shape: RoundedRectangle(cornerRadius: open ? Tok.rOpenBottom : 13, style: .continuous))
        }
    }

    /// Solid: the theme colour. Glass: behind-window blur with a tint. Closed is always solid, so the notch
    /// still merges with the hardware camera housing.
    /// Where the solid band ends, as a fraction of the open height (the notch line).
    private var bandStop: CGFloat { model.metrics.notchSize.height / max(1, model.openSize.height) }

    @ViewBuilder private func surface<S: Shape>(open: Bool, shape: S) -> some View {
        ZStack {
            if Tok.isGlass {
                GlassBackground().clipShape(shape).opacity(open ? 1 : 0)
                shape.fill(Tok.notch.opacity(open ? Tok.glassTint : 1))
                // Solid band behind the camera housing, fading out below the notch line, so glass still merges with the
                // hardware notch (functional, not decorative).
                shape.fill(LinearGradient(stops: [.init(color: Tok.notch, location: 0),
                                                  .init(color: Tok.notch, location: bandStop),
                                                  .init(color: Tok.notch.opacity(0), location: min(1, bandStop * 1.8))],
                                          startPoint: .top, endPoint: .bottom))
                    .opacity(open ? 1 : 0)
            } else {
                shape.fill(Tok.notch)
            }
        }
        .animation(Tok.reveal, value: open)
    }
}

private struct ContentHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
