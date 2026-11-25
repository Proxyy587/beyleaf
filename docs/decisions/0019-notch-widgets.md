# 0019: The open notch is user-ordered widgets, packed with no gaps

- **Status:** accepted (2026-11-25). Moves "row order" out of the theme (ADR 0015).
- **Context:**
  - The owner wants users to choose and sort what the notch shows, with no empty space.
  - Rows lived in `Theme.rows`, so "what is shown" travelled with "how it looks", and presets had to special-case keeping rows.
  - The panel also drew placeholder lines ("Not playing", "Nothing shown") and a dead band beside the camera.
- **Decision:**
  - The open panel is a list of **widgets** in the user's order, stored in `AppSettings.widgets`, not in the theme.
  - Each widget reports a presence for its current state: **live**, **ready** (one useful action) or **gone**.
  - It also reports a size for that state: **wide** or **tile**.
  - A pure function packs them: tiles pair in order, a lone tile is promoted to its wide layout, and nothing is ever reordered. It has a `swiftc` self-test.
  - Gone widgets take no space. Placeholder lines are removed.
  - `Theme.rows` is migrated once and then ignored. It stays decodable so old theme files still load.
  - Spec: `docs/notch-widgets.md`.
- **Consequences:**
  - Customization can't produce holes or dead strips.
  - Every widget must design both a tile and a wide form, plus its ready state.
  - Themes become purely visual. Sharing a theme no longer changes someone's widgets.
  - New widgets still need a row in `docs/ui-inventory.md` that passes the purpose test.
