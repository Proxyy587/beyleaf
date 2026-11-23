# belayd

The core daemon. See `docs/architecture.md` §3 for modules and §5 for flows.

| Module (planned) | Adapt from |
|---|---|
| HookGateway, Installer, `shim/belay-hook` | Perch `HookServer.swift` / `HookInstaller` (port Swift → TS), `third_party/perch/` |
| Adapters (claude, codex), Narrator lines | Perch `LiveStatus.swift` (port), `third_party/perch/` |
| `src/redact.ts` | OpenMausBot `shared/redact.ts` (Apache-2.0), `third_party/OpenMausBot/` |
| Engines (v0.2) | OpenMausBot engine layer: porting list in `third_party/OpenMausBot/SOURCE.md` |

Invariants: fail open (ADR 0005), never read agent credentials (ADR 0004).
