# Playbook: crew members, tools and runtimes

Design source: `docs/crew.md`. ADRs 0009 (hub + ToolHost + MCP proxy), 0010 (runtimes and turns), 0011 (taint).

## Add a member
1. Job card at `crew/<member>/card.md` (data dir): one job, a voice, and what it must never do.
2. Allowed tool namespaces (least privilege). Example: Tempo gets `music` only; Scout gets no `outward`.
3. Default runtime (`claude-cli`, `codex-cli`, `local-model`, `api-key`).
4. Router name and aliases for voice and @mentions. Add Router table tests.
5. Notch skin/avatar (no vendor logos).
6. FakeRuntime transcripts covering its common flows. Budget and cycle tests still pass.

## Add a tool
1. zod schema, a **risk class**, a **side-effect class** (`internal` / `local` / `local write` / `network read` / `external`), and its implementation (core or `*.command` to the shell).
2. External effects (`outward`) **always** need a card (J4). Network reads produce **tainted** results.
3. Register it in ToolHost. Tool manifests are frozen per thread: adding a tool must not change existing threads' manifests.
4. Tests: schema, risk/taint behaviour, and a manifest golden test.

## Add a runtime
- Implement `AgentRuntime` (`docs/crew.md` §5).
- Spawn in its own process group (adapt `third_party/OpenMausBot/server/group-exec.ts`).
- Pass only the turn capability token to MCP.
- Never read the engine's credentials.
- Contract tests against the FakeRuntime expectations.
- Record unverified CLI flags in `reference/open-questions.md`.

## Budgets (defaults)
- 6 hops per root request.
- Repeated (from → to, goal) is blocked.
- 4 turns per member per root.
- 9 (odd) group-goal turns, with Belay taking the last.
- 2 concurrent engine turns.
- 10 min per turn (Lead: 60 min).
