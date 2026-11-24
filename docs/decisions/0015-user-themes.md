# 0015: Every visual token comes from a user theme

- **Status:** accepted (2026-11-24)
- **Context:** The user wants everything customizable: fonts, colours, surfaces, shapes, layout and motion, including subtle blur. `docs/design.md` defines fixed tokens.
- **Decision:**
  - `Tok` resolves every token from a Codable `Theme` (`apps/mac/Sources/Belay/Settings/Theme.swift`):
    - typography: UI font, mono font, text scale, status case and tracking;
    - colours: ink and its levels, accent, live;
    - surface: solid or glass, colour, glass tint, shadow;
    - shape and layout: width, roundness, density, row order and visibility;
    - motion: speed, blur, bounce, reduced-motion override.
  - Presets (Midnight, Smoke, Terminal, Soft) must pass the anti-slop list. User edits are the user's call.
  - Themes can be saved, exported and imported as JSON.
  - Theme writes are no-ops when nothing changed. Controls that echo their value back (colour pickers, stepped sliders) otherwise caused an update loop (measured at 10–25% CPU).
- **Consequences:**
  - Views use `Tok.*` only and sit under `.id(themeRevision)`, so any theme change re-reads every token.
  - The closed notch always stays solid, to blend with the camera housing.
  - Blur and bounce turn off under reduced motion.
