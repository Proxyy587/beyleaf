import AppKit
import SwiftUI

/// Belay's mark: the notch, and the one point that needs you (brand/README.md). Drawn from the brand geometry on its
/// 64 × 64 grid, never from a bitmap. `BelayMark.notch` and `.point` are the two parts; `BelayMarkView` puts them
/// together with the brand's colour rules.
enum BelayMark {
    /// The grid the brand geometry is drawn on.
    static let grid: CGFloat = 64

    /// The notch: `M8 20 Q13 20 13 24.5 V25 A5 5 0 0 0 18 30 H46 A5 5 0 0 0 51 25 V24.5 Q51 20 56 20 Z`.
    struct Notch: Shape {
        /// Drawn without the point, centre the notch itself (its geometry sits 7 units above the grid centre).
        var alone = false
        func path(in r: CGRect) -> Path {
            let s = min(r.width, r.height) / BelayMark.grid
            let o = CGPoint(x: r.midX - 32 * s, y: r.midY - (alone ? 25 : 32) * s)
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
            var path = Path()
            path.move(to: p(8, 20))
            path.addQuadCurve(to: p(13, 24.5), control: p(13, 20))
            path.addLine(to: p(13, 25))
            // A5 5 0 0 0 18 30: a quarter circle centred at (18, 25), from 180° to 90° (y down), counter-clockwise on screen.
            path.addArc(center: p(18, 25), radius: 5 * s, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
            path.addLine(to: p(46, 30))
            path.addArc(center: p(46, 25), radius: 5 * s, startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
            path.addLine(to: p(51, 24.5))
            path.addQuadCurve(to: p(56, 20), control: p(51, 20))
            path.closeSubpath()
            return path
        }
    }

    /// The point: `circle(32, 41, r 4.5)`.
    struct Point: Shape {
        func path(in r: CGRect) -> Path {
            let s = min(r.width, r.height) / BelayMark.grid
            let c = CGPoint(x: r.midX + (32 - 32) * s, y: r.midY + (41 - 32) * s)
            return Path(ellipseIn: CGRect(x: c.x - 4.5 * s, y: c.y - 4.5 * s, width: 9 * s, height: 9 * s))
        }
    }

    /// A monochrome template image for the menu bar (macOS tints it for light and dark). Vector-drawn, so it's crisp
    /// at any backing scale. 18 pt matches the exported `brand/export/MenuBarIcon.png`.
    static func templateImage(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.addPath(Notch().path(in: rect).cgPath)
            ctx.addPath(Point().path(in: rect).cgPath)
            ctx.fillPath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Belay"
        return image
    }
}

/// The mark in a view. Ink on black by default. `live` paints the point in the live colour: only for "something needs
/// you" (a status colour, design.md §3). `showsPoint: false` draws the notch alone. Still at rest: no loops.
struct BelayMarkView: View {
    var ink: Color = Tok.ink
    var live = false
    var showsPoint = true

    var body: some View {
        ZStack {
            BelayMark.Notch(alone: !showsPoint).fill(ink)
            if showsPoint { BelayMark.Point().fill(live ? Tok.live : ink) }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Belay")
    }
}
