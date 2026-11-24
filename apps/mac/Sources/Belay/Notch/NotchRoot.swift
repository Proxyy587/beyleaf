import SwiftUI

/// The whole notch: a black shape that springs between the hardware-notch size and the open panel, with settings-driven
/// wings while closed and the open panel while open.
struct NotchRoot: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var music: NowPlaying
    @ObservedObject var status: SystemStatus
    @ObservedObject var shots: Screenshots
    @ObservedObject var settings = AppSettings.shared
    var openSettings: () -> Void

    var body: some View {
        let open = model.isOpen
        let size = open ? model.openSize : model.closedSize
        let notchH = model.metrics.notchSize.height

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                background(open: open).frame(width: size.width, height: size.height)

                HStack(spacing: 0) {
                    WingView(wing: settings.leftWing, side: .leading, music: music, status: status, shots: shots)
                        .frame(width: NotchModel.wing)
                    Spacer(minLength: 0)
                    WingView(wing: settings.rightWing, side: .trailing, music: music, status: status, shots: shots)
                        .frame(width: NotchModel.wing)
                }
                .frame(width: model.closedSize.width, height: notchH)
                .opacity(open ? 0 : 1)
                .animation(Tok.reveal, value: open)

                ExpandedView(music: music, status: status, shots: shots, shown: open, openSettings: openSettings)
                    .padding(.horizontal, Tok.rOpenEar)
                    .padding(.top, notchH)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(GeometryReader { g in Color.clear.preference(key: ContentHeight.self, value: g.size.height - notchH) })
                    .frame(width: model.openWidth)
                    .allowsHitTesting(open)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .clipped()
            .shadow(color: .black.opacity(open ? 0.5 : 0), radius: open ? 20 : 0, y: open ? 10 : 0)
            .padding(.top, model.metrics.hasNotch ? 0 : Tok.s2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onPreferenceChange(ContentHeight.self) { h in
            if h > 0, abs(h - model.openContentHeight) > 0.5 { model.openContentHeight = h }
        }
    }

    @ViewBuilder private func background(open: Bool) -> some View {
        if model.metrics.hasNotch {
            NotchShape(earRadius: open ? Tok.rOpenEar : 6, bottomRadius: open ? Tok.rOpenBottom : 10).fill(Tok.notch)
        } else {
            RoundedRectangle(cornerRadius: open ? Tok.rOpenBottom : 13, style: .continuous).fill(Tok.notch)
        }
    }
}

private struct ContentHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
