# 0002: Rust core deferred to v0.3

- **Status:** accepted (2026-11-24)
- **Context:** Rust gives smaller binaries, lower memory and one core for Windows/Linux. It is a new language for the developer, and v0.1 has a 2-week budget. The core is I/O-bound (hooks, a few events a second).
- **Decision:** Ship v0.1 and v0.2 on the TypeScript core. Port it to Rust (`belay-core`) behind protocol v1 when a Windows/Linux build is greenlit, or when measured idle CPU or memory breaks the budget in `docs/tech-stack.md` §4.
- **Consequences:** Every core behaviour must be covered by protocol-level tests and fixtures, so the port can be verified mechanically.
