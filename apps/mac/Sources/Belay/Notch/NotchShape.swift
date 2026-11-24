import SwiftUI

/// The notch silhouette: flush with the top edge, concave "ears" where it meets the menu bar, rounded bottom corners.
/// Both radii are animatable, so the closed notch (tight, like the hardware) springs into the open panel (soft).
/// Written for Belay; the shape idea is the same one DynamicNotchKit (MIT) and Perch use.
struct NotchShape: Shape {
    var earRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(earRadius, bottomRadius) }
        set { earRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in r: CGRect) -> Path {
        let e = min(earRadius, r.width / 4, r.height / 2)
        let b = min(bottomRadius, (r.width - 2 * e) / 2, r.height - e)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        // Left ear: curves from the top edge inward and down.
        p.addQuadCurve(to: CGPoint(x: r.minX + e, y: r.minY + e), control: CGPoint(x: r.minX + e, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + e, y: r.maxY - b))
        p.addQuadCurve(to: CGPoint(x: r.minX + e + b, y: r.maxY), control: CGPoint(x: r.minX + e, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - e - b, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - e, y: r.maxY - b), control: CGPoint(x: r.maxX - e, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - e, y: r.minY + e))
        // Right ear.
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.maxX - e, y: r.minY))
        p.closeSubpath()
        return p
    }
}
