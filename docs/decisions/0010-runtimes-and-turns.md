# 0010: Members think through pluggable runtimes, in bounded turns

- **Status:** accepted (2026-11-24)
- **Context:** Members must use the AI the user already has (ADR 0004): their `claude` CLI, their `codex` CLI, a local model, or their API key. Long-lived agent processes per member waste memory and are hard to stop or budget.
- **Decision:**
  - Every member runs through an `AgentRuntime` (`ClaudeCli`, `CodexCli`, `LocalModel`, `ApiKey`, `Fake`). Work happens in **turns**: assemble a context pack, start the engine, stream typed events, finish.
  - Each turn runs in its own process group (vendored `group-exec.ts`), with wall-clock and turn budgets.
  - Only Lead may resume a long coding session, by stored session id, inside a git worktree.
  - `FakeRuntime` with scripted transcripts is a first-class runtime for tests.
- **Consequences:**
  - Switching a member's engine keeps its threads, notes and tasks.
  - All crew logic is testable without a model.
  - CLI flags for print mode, streaming JSON, MCP config and resume are **UNVERIFIED** and must be checked before v0.2 (`docs/crew.md` §15).
