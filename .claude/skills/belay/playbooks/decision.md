# Playbook: recording a decision (ADR)

Write an ADR when a choice is expensive to reverse: stack, process boundaries, protocol, security model, licensing, data storage, or anything that contradicts an existing ADR.

1. Copy the newest file in `docs/decisions/`, bump the number (`00NN-kebab-title.md`).
2. Sections: **Status** (`proposed` / `accepted (date)` / `superseded by NNNN`), **Context** (facts, with sources; quote primary docs), **Decision**, **Consequences** (including what must now be verified).
3. Never rewrite an accepted ADR's decision. Supersede it with a new ADR and mark the old one `superseded by NNNN`.
4. Add the row to `docs/decisions/README.md`.
5. Update the docs the decision touches: `architecture.md`, `tech-stack.md`, `features-final.md`, `AGENTS.md` golden rules and this skill's rules list, so nothing contradicts it.
6. CHANGELOG line, then commit `docs: ADR NNNN <short title>`.
