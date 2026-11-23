# Playbook: implementing a feature

1. **Find it:** the ID (e.g. `A2`) in `docs/features-final.md`, including its phase, "Built in" component and "Done when" test. If it isn't in the locked list for the current phase, stop and ask.
2. **Find the design:** the component row in `docs/architecture.md` §3 (core) or `apps/mac/README.md` (shell). Crew features: `docs/crew.md`.
3. **Check decisions:** skim `docs/decisions/README.md`. If your approach contradicts an accepted ADR, write a superseding ADR first (`playbooks/decision.md`).
4. **Protocol first:** if the shell and core exchange anything new, add or modify the zod schema in `core/packages/protocol`, regenerate Swift, and keep it additive within v1.
5. **Reuse:** check the folder README's "Adapt from" column and `third_party/*/SOURCE.md`. Adapt, don't copy blindly. Add the provenance header:
   `// Adapted from <Project> (<Licence>), <upstream path> @ <short commit>. See third_party/<dir>/.` (+ `Modified by Belay contributors.` for Apache-2.0)
6. **Logic in TypeScript, rendering in Swift** (rule 1). If you're writing an `if` about product behaviour in Swift, move it to `belayd`.
7. **Tests:**
   - Core: `bun test`. Fixtures per agent version.
   - Crew: FakeRuntime transcripts.
   - Shell: XCTest.
   - The feature's "Done when" must be demonstrably true.
8. **Unknowns:** anything you couldn't verify goes in `reference/open-questions.md` and is marked UNVERIFIED in code comments or docs.
9. **Commit** per `playbooks/commit.md`, with the feature ID in the body.
