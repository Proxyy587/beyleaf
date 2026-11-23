# 0011: Untrusted content can't grant permission (taint tracking)

- **Status:** accepted (2026-11-24)
- **Context:** Scout reads web pages; members may read emails or files from outside the user's roots. That content can contain instructions aimed at the model ("prompt injection"). dusk bot's public docs put the principle well: "an email cannot give itself permission".
- **Decision:**
  - Any turn that ingests untrusted content is **tainted**. Taint propagates through `crew.ask` / `crew.handoff` results.
  - In a tainted chain, every `outward` action, every `fs.write` outside the task worktree, and every `mac.run_shortcut` **always** produces a rope card, regardless of "Always" rules. The card states the reason and the source.
  - Untrusted content is fenced and labelled in context packs. Notes derived from it are stored as sourced facts, never as instructions.
  - Only the user can approve. No member can approve another member's request.
- **Consequences:**
  - Some extra cards in research-heavy flows. That's accepted as the price of safety.
  - Taint is a field on turns, messages and tool calls, covered by dedicated tests.
