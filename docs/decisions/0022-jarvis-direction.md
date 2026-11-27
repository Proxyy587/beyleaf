# 0022: Buddies, routines, connectors and Mac control are one direction ("Jarvis")

- **Status:** accepted (2026-11-27); ordering settled below.
- **Context:**
  - The owner asked for buddies like dusk bot (pet characters, cron routines, chat, connectors) joined with Clicky-style Mac control, built phase by phase.
  - `docs/crew.md` already designs the crew (ADRs 0009–0011). "Buddies" is the user-facing name for crew members, drawn with the 30 traced sprites.
- **Decision:**
  - The crew is the buddies. We extend `docs/crew.md` with routines (cron schedules), connectors and Mac actions instead of starting a parallel system.
  - Phases and state live in `docs/jarvis-roadmap.md`.
  - The clean-room rule stands (0008, 0018): dusk bot is read for behaviour only. Code comes from OpenMausBot (Apache-2.0) and Clicky (MIT) through `scripts/vendor.sh`.
- **Ordering:** Phase 2 stands up the smallest `core/` first (crew protocol subset, scheduler, router) and builds the Swift layout against sample data; the approval path buddies need is the same code A2 needs, so it is built once. The owner asked to proceed on 2026-11-27 without choosing A1–A2 first.
- **Consequences:** every phase adds a row to `docs/ui-inventory.md` and an entry in `CHANGELOG.md`.
