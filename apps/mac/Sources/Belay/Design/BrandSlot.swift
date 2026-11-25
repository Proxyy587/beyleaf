import SwiftUI

/// The one place the logo appears on the notch: left of the camera in the open panel's band (docs/notch-widgets.md §3).
///
/// The box is fixed (a 16 pt glyph in a 28 pt square), so a new logo drops in by changing only what's drawn here:
/// the layout around it never moves. From A1 it doubles as the agents' status light (`live` lights the belayer's
/// pupils green while an agent needs you). Keep this file the only notch code that knows which mark is drawn.
struct BrandSlot: View {
    var live = false
    var body: some View {
        BelayMarkView(ink: Tok.ink3, live: live)
            .frame(width: 16, height: 16)
            .frame(width: Tok.button, height: Tok.button)
            .accessibilityLabel(live ? "Belay: agents working" : "Belay")
    }
}
