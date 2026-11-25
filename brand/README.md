# Belay brand

**The mark:** the notch, and the one point that needs you. Chosen 2026-11-24 from three rounds of exploration (`explore/`).

**Temporary logo (2026-11-25):** beepo, the first of the buddies (`buddies/`), stands in for the logo in the notch's brand slot and Settings → About. The app icon and the menu bar icon still use the mark below until they are redesigned.

| File | Use |
|---|---|
| `mark.svg` | Primary mark, ink `#F5F5F3`: docs, website, dark backgrounds |
| `mark-template.svg` → `export/MenuBarIcon(@2x).png` | Menu bar (template image: macOS tints it for light and dark) |
| `mark-live.svg` | The point in live green `#5BD08A`: "something needs you" moments, splash, social |
| `app-icon.svg` → `export/AppIcon.icns`, `export/app-icon-1024.png` | App icon: black squircle, live mark |

**Geometry** (64 × 64 grid): notch `M8 20 Q13 20 13 24.5 V25 A5 5 0 0 0 18 30 H46 A5 5 0 0 0 51 25 V24.5 Q51 20 56 20 Z`, point `circle(32, 41, r 4.5)`. In SwiftUI, draw it as a `Shape` from these numbers, not a bitmap.

**Rules:**
- Minimum size 16 pt. Clear space of one point-diameter on every side.
- Colours: ink on black, black on light. Green only on the point, and only for "live" (it's a status colour, `docs/design.md` §3).
- Never: outline it, add gradients or shadows, rotate it, stretch it, or put text inside it.
- **In the product the point is alive:** it appears when an agent needs you and pulses once on a catch. At rest the mark is still.

**Rejected** (`explore/`): A gate (read as a mug), B drop (lamp), C eight (generic), E rope (lamp), F clip (Taurus symbol), D2 edge (good, but busier at 16 pt).
