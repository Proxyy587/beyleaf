# core: Bun workspace (`belayd` and friends)

All product logic lives here (ADR 0001) so it can be tested headless and later ported to Rust behind protocol v1
(ADR 0002).

| Package | Responsibility |
|---|---|
| `packages/protocol` | zod schemas for every shell↔core message and hook payload. **Source of truth**; generates `apps/mac/Belay/Protocol/Generated.swift`. |
| `packages/belayd` | The daemon: HookGateway (Unix socket, ADR 0006), Adapters, EventBus, SessionStore, ApprovalBroker, RiskEngine, IntentRouter, Narrator, QuestEngine, Logbook, Installer, Engines (v0.2), PluginHost (v0.3). Also ships the `belay-hook` shim and the `belay` CLI. |
| `packages/rules` | Built-in danger-rule packs and the rule DSL (A3, I2) |
| `packages/cards` | satori templates for share cards (G1, G4, G5) |
