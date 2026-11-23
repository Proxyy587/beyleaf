# 0006: Hooks reach the core over a Unix socket via a command-hook shim

- **Status:** accepted (2026-11-24). Supersedes the localhost-HTTP-plus-token transport in the first draft of `docs/architecture.md`.
- **Context:**
  - The first draft used Claude Code HTTP hooks on a localhost port with a bearer token. That left an open question: hook URLs are fixed in config while the port may change.
  - Perch (MIT, `refs.lock`) solves this differently. Agent configs run a tiny shell script as a **command hook**. The script `curl --unix-socket`s the hook JSON to a socket that only the user can open (`chmod 0600`). It waits up to 3600 s for `PermissionRequest`, and an empty reply means "no decision". (See `Sources/Perch/HookServer.swift`, `HookInstaller`, at the pinned commit.)
- **Decision:**
  - `belayd` listens on `~/Library/Application Support/Belay/belay.sock` (mode 0600) for both Claude Code and Codex.
  - Hooks are command hooks that run a shim (`belay-hook <agent> <event>`), the same mechanism for both agents.
  - The shell ↔ core WebSocket also moves to this socket (or a second 0600 socket), so no TCP port is opened.
- **Consequences:**
  - No ports or tokens in agent configs.
  - Filesystem permissions are the access control.
  - **Verify on Day 1:**
    - Whether Bun can serve HTTP on a Unix socket in a compiled binary.
    - Codex `PermissionRequest` hold time: Perch registers it with a 5 s timeout, versus 3600 s for Claude Code. That suggests Codex approvals may not be holdable for long.
