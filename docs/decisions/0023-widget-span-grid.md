# 0023: Widgets have a user-chosen size on a column grid (supersedes 0019's packing rule)

- **Status:** accepted (2026-11-26). Supersedes the **packing rule** of ADR 0019 (tiles pair automatically, a lone tile is
  promoted to wide, Notes/Now playing/Calendar are always wide). ADR 0019's presence model (live, ready, gone) and ADR
  0021's pages are unchanged.
- **Context:**
  - The owner found the automatic packing restrictive: they want to form any layout, choose each widget's size, and have
    the notch leave it as arranged instead of promoting or pairing on its own.
  - The expand button only made things bigger. The owner wants extra room to hold extra widgets.
- **Decision:**
  - The open panel is a **grid of 2 columns** (compact) or **3 columns** (expanded). A column is the same width in both,
    so a widget keeps its size and the extra column holds more widgets.
  - Every widget placement has a **span**: `small` (1 column), `wide` (2) or `full` (3). A span wider than the grid is
    clamped to a full row (`wide` and `full` look the same in 2 columns). The span is stored per widget in
    `AppSettings.pages` (`WidgetSetting.span`, JSON key `span`, an Int 1...3), so it moves with the widget between pages
    and survives hiding.
  - Layout **flows in the user's order**: a widget that doesn't fit the rest of the row starts the next row. Nothing is
    reordered, resized, promoted or paired by the app. A row with free columns stays that way. This is a pure function
    (`WidgetLayout.rows(_:columns:)`) with a `swiftc` self-test.
  - A widget draws its **tile form** at span 1 and its **wide form** at span 2 and 3. A new widget kind declares, in
    `WidgetLayout.swift` only: `defaultSpan` (exhaustive switch) and optionally `minSpan` (default `.small`; `spans` is
    derived). Its card view takes `size: WidgetSize` (`.tile` or `.wide`) and must stay readable and truncate at both.
  - **Defaults** look as ADR 0019 packed them: the default pages (and old saved pages) get spans from `Pages.autoSpans`
    once: wide-by-nature widgets are wide, small ones pair, a small left alone is wide. After that the user's choices are
    never re-packed.
  - **Migration (once, tolerant):** saved `pages` with no `span` on any widget are laid out with `autoSpans` (the old look,
    including a clock with zones as wide). Unknown or out-of-range spans fall back to the kind's default. A saved layout
    keeps unknown-free decode semantics from ADR 0021.
  - **Editing:** in the notch's edit mode, drag a card to reorder and **tap it to cycle its size** (small, wide, and full
    when expanded); the right-click menu has a Size submenu; Settings → Widgets has a Size menu per widget. Adding the
    first clock time zone widens a small clock (the user's own edit; zones show only in the wide form).
  - **Minimum height:** every cell has a floor (`WidgetLayout.minHeight`) so a card with little content never collapses.
- **Consequences:**
  - Users can make holes. That is the point: the app no longer second-guesses the arrangement. In expanded mode the
    default wide widgets leave a free column beside them until the user places small widgets there.
  - Every widget designs a compact tile and a wide form (as 0019) and must be readable at both, in a 196 pt-ish column.
  - `docs/widget-hub.md`, `docs/ui-inventory.md` and `docs/status.md` describe the grid; `docs/notch-widgets.md`'s
    packing section is historical.
  - Tap and drag in edit mode need a real pointer to verify and are **UNVERIFIED** until checked by hand
    (`docs/open-questions.md`).
