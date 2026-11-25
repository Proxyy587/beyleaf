import SwiftUI

/// A Belay buddy at any size (16–256 pt and beyond), in either style, in any mood.
///
/// - Smooth art is vector paths traced from the reference sheet, scaled as geometry, so it is sharp at every size.
/// - Pixel art is drawn cell by cell with anti-aliasing off. That is nearest-neighbour scaling: edges land on device
///   pixels with no blur, and every motion moves whole cells.
/// - `eyeColor` overrides the eyes (the notch uses it for "live"). `tint` draws the whole buddy in one colour with
///   its eyes cut out of it, for monochrome places.
/// - `hop` plays one happy hop each time it changes (see `BuddyAnimator`).
///
/// Nothing animates at rest: motion happens only when `mood` or `hop` changes, and lasts at most 280 ms.
struct BuddyView: View {
    let id: BuddyID
    var style: BuddyStyle = .smooth
    var mood: BuddyMood = .idle
    var size: CGFloat = 64
    var eyeColor: Color?
    var tint: Color?
    var hop: Int = 0

    var body: some View {
        Group {
            switch style {
            case .smooth: SmoothBuddy(art: BuddyArt.smooth(id), mood: mood, size: size, eyeColor: eyeColor, tint: tint, hop: hop)
            case .pixel: PixelBuddy(art: BuddyArt.pixel(id), mood: mood, size: size, eyeColor: eyeColor, tint: tint, hop: hop)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(id.rawValue)
    }
}

/// A path in art units, scaled into the view.
private struct ArtShape: Shape {
    let path: Path
    let scale: CGFloat
    func path(in rect: CGRect) -> Path { path.applying(CGAffineTransform(scaleX: scale, y: scale)) }
}

private struct SmoothBuddy: View {
    let art: BuddyArt.Smooth
    let mood: BuddyMood
    let size: CGFloat
    let eyeColor: Color?
    let tint: Color?
    let hop: Int

    var body: some View {
        let k = size / max(art.size.width, art.size.height)
        let w = art.size.width * k, h = art.size.height * k
        let eyes = eyeColor ?? (tint != nil ? Color.black : art.eyeColor)
        let happy = mood == .happy
        let hopHeight = Tok.reduceMotion ? 0 : h * 0.1
        ZStack(alignment: .topLeading) {
            ForEach(art.layers.indices, id: \.self) { i in
                let layer = art.layers[i]
                if layer.clipped {
                    ArtShape(path: layer.path, scale: k).fill(tint ?? layer.color)
                        .clipShape(ArtShape(path: art.silhouette, scale: k))
                } else {
                    ArtShape(path: layer.path, scale: k).fill(tint ?? layer.color)
                }
            }
            Group {
                ArtShape(path: art.eyes, scale: k).fill(eyes)
                    .scaleEffect(x: 1, y: mood.eyesClosed ? 0.1 : 1, anchor: UnitPoint(x: 0.5, y: art.eyeCenterY / art.size.height))
                    .opacity(happy ? 0 : 1)
                ArtShape(path: art.happyEyes, scale: k)
                    .stroke(eyes, style: StrokeStyle(lineWidth: art.eyeWidth * 0.78 * k, lineCap: .round))
                    .opacity(happy ? 1 : 0)
            }
            .offset(x: mood.look * art.eyeWidth * 0.75 * k)
            .animation(Tok.blink, value: mood)
        }
        .frame(width: w, height: h)
        .offset(y: mood == .hover ? -h * 0.04 : 0)
        .animation(Tok.lift, value: mood)
        .keyframeAnimator(initialValue: 0.0, trigger: hop) { content, v in
            content.offset(y: -v * hopHeight)
        } keyframes: { _ in
            CubicKeyframe(1, duration: Tok.hopHalf)
            CubicKeyframe(0, duration: Tok.hopHalf)
        }
    }
}

private struct PixelBuddy: View {
    let art: BuddyArt.Pixel
    let mood: BuddyMood
    let size: CGFloat
    let eyeColor: Color?
    let tint: Color?
    let hop: Int

    /// Room above the art for the hover lift (1 cell) and the hop (2 cells).
    private static let headroom = 3

    var body: some View {
        let cell = size / CGFloat(max(art.width, art.height))
        let room = CGFloat(Self.headroom) * cell
        let steps = Tok.reduceMotion ? 0.0 : 2.0
        // The hop moves the finished drawing by whole cells, rounded to whole points so it never resamples.
        canvas(cell: cell)
            .frame(width: size, height: size + room)
            .keyframeAnimator(initialValue: 0.0, trigger: hop) { content, v in
                content.offset(y: -((v * steps).rounded() * cell).rounded())
            } keyframes: { _ in
                CubicKeyframe(1, duration: Tok.hopHalf)
                CubicKeyframe(0, duration: Tok.hopHalf)
            }
            .frame(width: size, height: size, alignment: .bottom)
    }

    private func canvas(cell: CGFloat) -> some View {
        let tintCG = tint.map { NSColor($0).cgColor }
        let eyeCG = eyeColor.map { NSColor($0).cgColor } ?? (tint != nil ? CGColor(gray: 0, alpha: 1) : nil)
        let look = Int(mood.look)
        let lift = mood == .hover ? 1 : 0
        let eyes = mood == .happy ? art.eyesHappy : (mood.eyesClosed ? art.eyesClosed : art.eyesOpen)
        let eyesMove = mood != .happy
        return Canvas { ctx, canvasSize in
            let ox = (canvasSize.width - CGFloat(art.width) * cell) / 2
            let oy = canvasSize.height - CGFloat(art.height) * cell - (size - CGFloat(art.height) * cell) / 2
                - CGFloat(lift) * cell
            ctx.withCGContext { cg in
                cg.setShouldAntialias(false)
                cg.setAllowsAntialiasing(false)
                func fill(_ cells: [BuddyArt.Cell], dx: Int, color: (Int) -> CGColor) {
                    for c in cells {
                        cg.setFillColor(color(c.color))
                        cg.fill(CGRect(x: ox + CGFloat(c.x + dx) * cell, y: oy + CGFloat(c.y) * cell, width: cell, height: cell))
                    }
                }
                fill(art.body, dx: 0) { tintCG ?? art.palette[$0] }
                fill(art.mouth, dx: look) { eyeCG ?? art.palette[$0] }
                fill(eyes, dx: eyesMove ? look : 0) { eyeCG ?? art.palette[$0] }
            }
        }
    }
}
