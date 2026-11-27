# 0024: Belay is "one rope for every AI on your Mac", built session bus and rope first

- **Status:** accepted (2026-11-27, owner)
- **Context:**
  - Supervising Claude Code and Codex from the notch is crowded (`docs/verdict.md`), and dusk bot and heyclicky already own the buddy-assistant story. No single piece is unique; the combination is (`docs/product-vision.md` §2).
  - Buddies need the same approval path that supervising outside agents needs, so building it once serves both.
- **Decision:**
  - The product is one approval and audit layer (the rope) over every agent, buddy and Mac action, with every running AI visible in the notch.
  - Build order: session bus and hooks, then the rope and Needs-you inbox, then buddies' engines and chat plus Belay's MCP server, then Mac hands and routines, then the ecosystem (`docs/product-vision.md` §8). The first public version is the first two.
  - Agents plug in at three honest tiers (control, observe and ask, presence); the UI shows the tier.
- **Consequences:**
  - Supersedes the ordering note in ADR 0022 only in emphasis: the core is still stood up first, but its first job is sessions and approvals, not chat.
  - Phase 1 starts now (`docs/jarvis-roadmap.md` is updated with it).
  - Launching the user's own `claude` from Belay stays blocked on the Commercial Terms question (ADR 0004).
