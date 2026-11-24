import SwiftUI

/// The whole notch: a black shape that springs between the hardware-notch size and the open panel, with compact "wings"
/// while closed and the expanded content while open.
struct NotchRoot: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var music: NowPlaying
    @ObservedObject var status: SystemStatus

    var body: some View {
        let open = model.isOpen
        let size = open ? model.openSize : model.closedSize
        let notchH = model.metrics.notchSize.height

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                background(open: open)
                    .frame(width: size.width, height: size.height)

                // Closed: little wings either side of the camera.
                HStack {
                    CompactLeadingView().frame(width: NotchModel.wing)
                    Spacer()
                    CompactTrailingView(music: music, status: status).frame(width: NotchModel.wing)
                }
                .frame(width: model.closedSize.width, height: notchH)
                .opacity(open ? 0 : 1)
                .scaleEffect(open ? 0.8 : 1)

                // Open: content below the notch line, measured so the shape fits it exactly.
                ExpandedView(music: music, status: status, shown: open)
                    .padding(.horizontal, NotchModel.openEar)
                    .padding(.top, notchH)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(GeometryReader { g in Color.clear.preference(key: ContentHeight.self, value: g.size.height - notchH) })
                    .frame(width: NotchModel.openWidth)
                    .opacity(open ? 1 : 0)
                    .allowsHitTesting(open)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .clipped()
            .shadow(color: .black.opacity(open ? 0.45 : 0), radius: open ? 18 : 0, y: open ? 8 : 0)
            .padding(.top, model.metrics.hasNotch ? 0 : 6)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onPreferenceChange(ContentHeight.self) { h in
            if h > 0, abs(h - model.openContentHeight) > 0.5 { model.openContentHeight = h }
        }
    }

    @ViewBuilder private func background(open: Bool) -> some View {
        if model.metrics.hasNotch {
            NotchShape(earRadius: open ? NotchModel.openEar : 6, bottomRadius: open ? 26 : 10).fill(.black)
        } else {
            RoundedRectangle(cornerRadius: open ? 24 : 13, style: .continuous).fill(.black)
        }
    }
}

private struct ContentHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
