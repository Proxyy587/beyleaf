# 0022: Buddies, routines, connectors and Mac control are one direction ("Jarvis")

- **Status:** proposed (2026-11-26), awaiting the owner's answer on ordering (see Open).
- **Context:**
  - The owner asked for buddies like dusk bot (pet characters, cron routines, chat, connectors) joined with Clicky-style Mac control, built phase by phase.
  - `docs/crew.md` already designs the crew (ADRs 0009–0011). "Buddies" is the user-facing name for crew members, drawn with the 30 traced sprites.
- **Decision:**
  - The crew is the buddies. We extend `docs/crew.md` with routines (cron schedules), connectors and Mac actions instead of starting a parallel system.
  - Phases and state live in `docs/jarvis-roadmap.md`.
  - The clean-room rule stands (0008, 0018): dusk bot is read for behaviour only. Code comes from OpenMausBot (Apache-2.0) and Clicky (MIT) through `scripts/vendor.sh`.
- **Open:** whether to build `core/` (protocol v1, minimal `CrewService`) at the start of Phase 2, or finish A1–A2 first as `docs/status.md` §7 says. Update this ADR when the owner chooses.
- **Consequences:** every phase adds a row to `docs/ui-inventory.md` and an entry in `CHANGELOG.md`.
