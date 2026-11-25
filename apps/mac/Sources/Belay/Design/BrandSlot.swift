import SwiftUI

/// The one place the logo appears on the notch: left of the camera in the open panel's band (docs/notch-widgets.md §3).
///
/// The box is fixed (a 16 pt glyph in a 28 pt square), so a new logo drops in by changing only what's drawn here:
/// the layout around it never moves. From A1 it doubles as the agents' status light (`live` turns the buddy's eyes
/// green while an agent needs you). Keep this file the only notch code that knows which mark is drawn.
///
/// The mark is beepo, the temporary logo (brand/buddies/), in its own colours: on the black notch its purple reads
/// as the one spot of personality, where an ink3 silhouette read as a grey blob at 16 pt.
struct BrandSlot: View {
    var live = false
    var body: some View {
        BuddyView(id: .beepo, size: 16, eyeColor: live ? Tok.live : nil)
            .frame(width: Tok.button, height: Tok.button)
            .accessibilityLabel(live ? "Belay: agents working" : "Belay")
    }
}
