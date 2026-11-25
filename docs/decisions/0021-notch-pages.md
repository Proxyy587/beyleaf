# 0021: The open notch is pages of packed widgets (extends 0019)

- **Status:** accepted (2026-11-25). Extends ADR 0019; supersedes its storage (`AppSettings.widgets`), not its packing rule.
- **Context:**
  - The owner asked for many more widgets (clock, smart timer, stopwatch, notes, weather, calendar, later agent chat),
    without the notch "feeling like too much stuff", and suggested slides you switch between.
  - One packed list (ADR 0019) would grow into a tall panel, and every widget in it would run while open.
  - Performance rules (`docs/performance.md`) require that only what's visible does any work.
- **Decision:**
  - The open notch shows one **page** at a time. A page is a named, ordered list of widgets; the ADR 0019 packing rule
    runs per page unchanged.
  - Built-in pages: `now`, `notes`, `day`; `agents` is added at A1. **Every widget kind lives on exactly one page.**
  - Pages with no present widget are skipped. Navigation: two-finger swipe, dots in the band, ⌘[ ⌘] ⌘1–4 while the
    panel is key, a global capture shortcut for Notes. The last chosen page is remembered.
  - Only the visible page is in the view tree, so hidden pages can't tick, poll or fetch.
  - **Data model** (UserDefaults, JSON):
    ```
    AppSettings.pages: [PageSetting]     key "pages"
    PageSetting { kind: PageKind, enabled: Bool, widgets: [WidgetSetting] }   // WidgetSetting { kind, enabled } as in 0019
    AppSettings.page: PageKind           key "notchPage"   (remembered page)
    ```
  - **Decode is tolerant** (pure, in `WidgetLayout.swift`, covered by `widgets-selftest.sh`): unknown page or widget
    kinds are dropped; a widget listed twice keeps its first place; a missing widget is appended to its home page with its
    default; a missing page is appended with its defaults.
  - **Migration (once):** when `pages` is absent, the Now page is built from the old `widgets` array (its order and
    switches kept), with the clock inserted first and new Now widgets appended with their defaults. Notes and Day get
    their defaults. The old `widgets` key is left in place (a downgrade still reads it) and ignored from then on.
  - The notch panel may become key **only while open, and only for a text field** (`becomesKeyOnlyIfNeeded`), or when the
    capture shortcut opens it. It never activates Belay. This refines ADR 0014's "never steals focus": a field the user
    clicked or summoned gets the keyboard; nothing else does.
  - Spec: `docs/widget-hub.md`.
- **Consequences:**
  - Adding a widget means choosing its home page and designing its tile, wide, ready and gone states (as 0019).
  - The packing self-test grows a pages section (decode, migration, the one-page-per-widget invariant).
  - Theme files are untouched; pages are content, not look (as 0019).
  - Keyboard focus returning to the previous app after the notch closes is **UNVERIFIED** until checked by hand.
