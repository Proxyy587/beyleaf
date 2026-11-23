# 0009: Crew is hub-and-spoke, with one tool surface

- **Status:** accepted (2026-11-24)
- **Context:** Belay gains sub-agents (Lead, Porter, Tempo, Scout, Sketch, custom; `docs/crew.md`) that must cooperate. Peer-to-peer messaging between agent processes would scatter routing, budgets, safety checks and audit across processes. CLI engines (`claude`, `codex`) can call tools through MCP. In-process runtimes call functions directly.
- **Decision:**
  - All crew messages, handoffs and tool calls go through `CrewService` in `belayd`. Members never talk to each other's processes.
  - Every tool is defined once in `ToolHost`. CLI engines reach it through `belay mcp --turn <token>`, a stdio MCP proxy over the 0600 Unix socket. Only a turn-scoped capability token crosses into the agent process (pattern from OpenMausBot's harness MCP proxy, Apache-2.0).
  - A thread's tool manifest is frozen for the thread's life, so provider prompt caching stays valid.
- **Consequences:**
  - One place enforces hop, cycle and turn budgets, taint, approvals and audit.
  - Adding a member is a config change plus a job card, not a new process protocol.
  - The MCP proxy must be tiny and tested, since it runs inside agent processes.
