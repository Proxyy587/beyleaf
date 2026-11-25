import SwiftUI

// The Moon widget (docs/widget-hub.md §3.11): today's phase drawn as a disc, from date math alone.

/// The lit part of the moon. Static, so it costs nothing after the first draw.
private struct MoonLit: Shape {
    let cycle: Double
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2, c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        let pts = MoonLogic.litOutline(cycle: cycle)
        guard let first = pts.first else { return p }
        p.move(to: CGPoint(x: c.x + r * first.x, y: c.y + r * first.y))
        for q in pts.dropFirst() { p.addLine(to: CGPoint(x: c.x + r * q.x, y: c.y + r * q.y)) }
        p.closeSubpath()
        return p
    }
}

struct MoonCard: View {
    let size: WidgetSize
    var ticking = true

    var body: some View {
        // The phase moves a few percent a day: refresh hourly, only while visible.
        Ticking(seconds: 3600, active: ticking) { now in
            HStack(spacing: Tok.s3) {
                ZStack {
                    Circle().fill(Tok.ink.opacity(0.14))
                    MoonLit(cycle: MoonLogic.cycle(now)).fill(Tok.ink)
                }
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(MoonLogic.phase(now).name).font(Tok.rowTitle).foregroundStyle(Tok.ink).lineLimit(1).truncationMode(.tail)
                    StatusLine(text: MoonLogic.litText(now))
                }
                Spacer(minLength: Tok.s2)
                if size == .wide {
                    Text(MoonLogic.nextLine(now)).font(Tok.meta).foregroundStyle(Tok.ink2).lineLimit(1).truncationMode(.tail)
                }
            }
            .card()
            .frame(maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(MoonLogic.spoken(now))
        }
    }
}
