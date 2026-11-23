# Belay: technical architecture

**Decided:** 2026-11-24.

**Implements:** `features-final.md`.

**Stack:** `tech-stack.md`.

---

## 1. System overview

```
                         ┌──────────────────────── user's Mac ─────────────────────────┐
 Claude Code sessions ──►│  command hook: `belay-hook claude <event>` ─┐               │
 (terminal/IDE/desktop)  │                                             │ curl --unix-  │
 Codex sessions ────────►│  command hook: `belay-hook codex <event>` ──┤ socket (0600) │
 (command hooks)         │                                             ▼   (ADR 0006)  │
                         │  ┌──────────────── belayd (TS / Bun binary) ──────────────┐ │
                         │  │ HookGateway → Adapters(claude, codex) → EventBus        │ │
                         │  │ SessionStore · ApprovalBroker · RiskEngine(rule packs)  │ │
                         │  │ Narrator · IntentRouter · QuestEngine · Logbook         │ │
                         │  │ Engines(v0.2: claude/codex CLI, local LLM, BYOK)        │ │
                         │  │ Actions(v0.2) · CardRenderer · Installer · PluginHost   │ │
                         │  │ SQLite (~/Library/Application Support/Belay/belay.db)   │ │
                         │  └──────────────▲──────────── WebSocket (protocol v1) ─────┘ │
                         │                 │                                           │
                         │  ┌──────────────┴──────── Belay.app (Swift) ──────────────┐ │
                         │  │ CoreClient · Supervisor (launches & restarts belayd)   │ │
                         │  │ NotchShell(DynamicNotchKit) · Island · BaseCamp         │ │
                         │  │ RopeCard · QuestCard · Logbook views · Character        │ │
                         │  │ FeelKit (haptics · sound · springs)                     │ │
                         │  │ Voice (hotkey · on-device STT · TTS)                    │ │
                         │  │ MacBridge (NowPlaying · WindowLocator(AX) · Overlay ·   │ │
                         │  │            AppleScript/NSWorkspace actions)             │ │
                         │  │ Permissions · Settings · Sparkle updater                │ │
                         │  └─────────────────────────────────────────────────────────┘ │
                         └──────────────────────────────────────────────────────────────┘
```

**Rule of the split:**
- **Swift renders, listens and touches macOS.**
- **TypeScript decides.** All product logic (state, risk, intents, quests, stats, engines) lives in `belayd`, so it can be tested headless and later ported to Rust (`tech-stack.md` §2).

## 2. Processes and lifecycle

1. The user launches **Belay.app**. `Supervisor` starts the bundled `belayd` with the data directory.
2. `belayd` listens on a **Unix socket**, `~/Library/Application Support/Belay/belay.sock` (mode `0600`). It writes `runtime.json` (pid, protocol version) next to it. No TCP port is opened (ADR 0006).
3. Agent configs run a **command hook**: the installed shim `belay-hook <agent> <event>`. The shim pipes the hook JSON to the socket with `curl --unix-socket`, waits for the reply (up to 3600 s for Claude Code `PermissionRequest`), and prints it. If the socket is missing it prints nothing, which is the fail-open path (ADR 0005). This removes the fixed-port problem of the first draft. The pattern is taken from Perch (MIT; `third_party/perch/`).
4. **If `belayd` dies:**
   - `Supervisor` restarts it with backoff, and the island shows a dim "rope slack" state.
   - Meanwhile hooks fail. That is a non-blocking error, so **agents fall back to their own terminal prompts**. Belay never auto-allows (the fail-open rule).
5. On quit, Belay.app sends `shutdown` and `belayd` answers all pending approvals with **no decision**, returning control to the terminal.

## 3. `belayd` modules

| Module | Responsibility | Feature IDs |
|---|---|---|
| **HookGateway** | Hono routes on the Unix socket: `POST /hook/claude/:event`, `POST /hook/codex/:event`. Parses with zod. Holds `PermissionRequest` responses open. Access control is the socket's 0600 mode (ADR 0006). Ported from Perch's `HookServer`. | A1–A4 |
| **Adapters/claude, Adapters/codex** | Map each agent's hook JSON to Belay's `AgentEvent`. Know each agent's capabilities: Codex has no `updatedInput` or `interrupt`. | A1–A4, A9 |
| **EventBus** | In-process typed pub/sub. Every module subscribes here, never to each other. | all |
| **SessionStore** | One state machine per session: `idle → climbing → rope_dropped → climbing → summit / dangling / ended`. Persisted in SQLite. | A1, A5, A10 |
| **ApprovalBroker** | A map of pending requests. Each has a timeout: at T-5 s Belay returns no decision so the terminal takes over. Resolves `allow / always / deny(message) / stop`. Writes an audit row. | A2, A4 |
| **RiskEngine** | Loads rule packs (built-in + user + plugin), evaluates every `PreToolUse`/`PermissionRequest`, and emits `catch` with a severity and a human line | A3, I2 |
| **IntentRouter** | Voice/text transcript → intent (`approve`, `deny`, `always`, `stop`, `steer(text)`, `status`, `music.*`, `timer.*`, `quest.*`, `task(text)`). Deterministic grammar first; optional LLM fallback via Engines. | A4, A5, C4, J2 |
| **Narrator** | Builds spoken and written lines from templates. Optional one-line summaries via Engines or an on-device model. | A5, A10 |
| **QuestEngine** | Context rules ("summit unreviewed > 5 min", "same allow × 9"), rate limiting, a no-quest-during-rope-drop guard, XP | F1–F7, G2 |
| **Logbook** | Aggregates stats (approvals, catches, pitch durations, summits), grades and streaks | G1–G4 |
| **CardRenderer** | satori templates → PNG for the daily, weekly and profile cards | G1, G4, G5 |
| **Installer** | Detects agents. Produces a **diff preview** of hook-config changes. Backs up the original. Applies the change. Removes it cleanly on uninstall. Walks the user through Codex hook trust. | H1, H4 |
| **Engines** (v0.2) | Spawn the **user's own** `claude` / `codex` CLIs headless, or a local or BYOK model. Never touches subscription credentials. Adapted from MausBot (Apache-2.0). | J1, J2 |
| **Actions** (v0.2) | Requests to the shell for Mac actions (open app or URL, music, timers), each typed and permissioned. Destructive or outward actions require a card. | J3, J4 |
| **PluginHost** (v0.3) | Loads TS plugins with a declared manifest (holds, quests, rules, intents) and runs them in a restricted worker with only declared capabilities | I1 |

## 4. Shell ↔ core protocol (v1)

- **Transport:** WebSocket (`/v1`) over the same 0600 Unix socket, or a second one, `belay-ui.sock`. The shell connects with `URLSessionWebSocketTask` or a small Network.framework client. Whether Bun serves WebSocket upgrades on a Unix socket in a compiled binary is a **Day 1 check** (ADR 0006); the fallback is a localhost port plus a per-launch token written to `runtime.json`.
- **Envelope:** `{ "v": 1, "id": "<uuid>", "type": "<name>", "data": { … } }`. Requests carry `id`; replies echo it.
- **Schemas:** live in `core/packages/protocol` (zod). CI generates `apps/mac/Belay/Protocol/Generated.swift`, and **CI fails if generated code is stale**.

| Direction | Message | Purpose |
|---|---|---|
| core → shell | `state.snapshot`, `session.updated` | Island dots, base-camp list |
| core → shell | `rope.dropped {approvalId, agent, repo, command, risk, capabilities}` | Show the RopeCard |
| core → shell | `catch {approvalId, severity, line}` | Catch animation + haptic + sound + TTS |
| core → shell | `speak {text, priority}` | TTS |
| core → shell | `quest.offer`, `card.ready {pngPath}`, `logbook.updated` | Quests and sharing |
| core → shell | `action.request {kind, params, needsCard}` | v0.2 Mac actions |
| shell → core | `approval.resolve {approvalId, decision, message?}` | Button or keyboard answer |
| shell → core | `voice.transcript {text, final}` | IntentRouter input |
| shell → core | `window.frame {sessionId, rect}` | Rope-to-window (A8) |
| shell → core | `nowplaying.updated`, `focus.changed`, `call.active` | Context for quests and mute rules |
| both | `ping/pong`, `shutdown`, `error` | Health |

## 5. Key flows

### 5.1 Approval with voice steering (the hero flow: A2, A3, A4)

1. Claude Code fires `PermissionRequest`. Its command hook runs `belay-hook claude PermissionRequest`, which posts the JSON to `belayd` over the Unix socket and waits.
2. Adapter → `AgentEvent.permission`. RiskEngine evaluates it: e.g. `prod-db` severity high.
3. ApprovalBroker stores the pending request, keeps the HTTP response open, and starts the timeout.
4. Core → shell: `catch` + `rope.dropped`. The shell plays the catch spring, the 3× haptic and the "whoa" sound, shows the RopeCard **without taking focus**, and speaks the risk line.
5. The user holds the talk key: "no, use staging instead". On-device STT sends `voice.transcript`, and IntentRouter returns `steer("use staging instead")`.
6. Broker replies to the held hook: `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"use staging instead"}}}`.
7. Claude receives the denial with the message and changes course. Session goes `rope_dropped → climbing`. The Logbook counts one catch.
8. **Codex variant:** the same, but over the command shim. "Always" and "stop" are hidden because the adapter says they're unsupported.

### 5.2 Rope to the window (A8, v0.2)

When a session's state becomes `rope_dropped`:
1. The shell's WindowLocator finds that session's terminal window using the session's `cwd`, TTY and pid mapping. It uses the Accessibility API for window frames, plus AppleScript for iTerm2/Terminal tab selection.
2. The Overlay (a transparent, click-through, full-screen `NSPanel`) draws an animated rope from the notch to the window frame.
3. If the window can't be found, it skips the rope and nothing breaks.

### 5.3 Hands: "open my latest PR" (J2, J3, v0.2)

1. IntentRouter gets `task("open my latest PR")`.
2. If there's a deterministic match (an Actions recipe), it sends `action.request{open_url}`. Otherwise it goes to Engines.
3. Engines spawns the user's `codex exec` or `claude -p` with the task, a tight tool allowlist, and Belay's **own hooks** active.
4. Every step of that run passes through the normal RiskEngine and RopeCards. Belay supervises its own delegated work exactly as it supervises the user's agents.

### 5.4 Daily share card (G1)

- At the end of the day, or on demand, Logbook aggregates the stats. CardRenderer turns them into a PNG in the data directory.
- Core sends `card.ready`.
- The shell offers Copy or Post. Post opens the X compose URL with prefilled text; the image is copied to the clipboard. No X API needed.

## 6. Storage

Everything lives under `~/Library/Application Support/Belay/`:

| File | Contents |
|---|---|
| `belay.db` (SQLite) | sessions, events (last 30 days, compacted), approvals (audit), catches, quests, logbook_daily, grades |
| `config.json` | user settings (hotkey, voice, mute rules, enabled holds) |
| `rules/` | user rule packs (YAML) |
| `plugins/` | installed plugins (v0.3) |
| `cards/` | rendered PNGs |
| `belay.sock`, `belay-ui.sock` | Unix sockets (0600) for hooks and the shell (ADR 0006) |
| `runtime.json` | pid, protocol version (0600, rewritten each launch) |
| `backups/` | original agent config files saved before the Installer touched them |

**No prompts or code are stored.** The events table holds the tool name, a command summary for Bash, file paths, and timing. Users can turn command text storage off. This matches the privacy line in `product.md`.

## 7. Security model

| Threat | Control |
|---|---|
| A local malicious process forges approvals | Unix sockets with mode 0600 in the user's Application Support folder: only processes running as the user can connect. No TCP port. (A process already running as the user can also edit agent configs directly, so this is the same trust boundary the agents themselves have.) |
| Belay auto-approves something dangerous | No code path returns `allow` without an explicit user action or a user-created "Always" rule. Unit test plus a lint rule on the broker. |
| Belay down or slow blocks the agent | Timeouts return **no decision**, so the terminal prompt takes over |
| Plugins exfiltrate data | Manifest-declared capabilities, a worker sandbox, no network unless declared, plugins listed on install (v0.3) |
| Credentials misuse | Belay never reads `~/.claude` or `~/.codex` auth files and never handles subscription tokens (`oss-reuse.md` §2). Enforced by a CI grep test. |
| Supply chain | Pinned dependencies, lockfiles, signed and notarized builds, Sparkle EdDSA-signed updates |

## 8. Repository layout

```
belay/
├── README.md · LICENSE (MIT) · THIRD_PARTY_NOTICES.md · CLAUDE.md
├── docs/                         research, product, stack, architecture
├── apps/
│   ├── mac/                      Swift app
│   │   ├── project.yml           XcodeGen
│   │   └── Belay/
│   │       ├── App/              BelayApp, Supervisor, Settings
│   │       ├── Notch/            Island, BaseCamp (DynamicNotchKit)
│   │       ├── Cards/            RopeCard, QuestCard, LogbookViews
│   │       ├── Character/        sprite atlas + state machine
│   │       ├── Feel/             Haptics, Sounds, Springs
│   │       ├── Voice/            Hotkey, STT, TTS
│   │       ├── MacBridge/        NowPlaying, WindowLocator, Overlay, Actions
│   │       └── Protocol/         Generated.swift + CoreClient
│   └── web/                      Next.js site + MDX docs
├── core/                         Bun workspace
│   ├── packages/protocol/        zod schemas (source of truth)
│   ├── packages/belayd/          gateway, adapters, broker, engines…
│   ├── packages/rules/           built-in rule packs + DSL
│   └── packages/cards/           satori templates
├── rules/                        community rule packs (YAML)
├── e2e/                          live agent continuation tests (A6)
└── .github/workflows/            ci.yml, release.yml
```

## 9. Testing strategy

| Layer | What | How |
|---|---|---|
| Core unit | Adapters (fixture hook payloads per agent version), broker timeouts, RiskEngine rules (≥ 50 cases), IntentRouter grammar | `bun test` |
| Protocol | Swift ↔ TS schema parity | Codegen staleness check in CI |
| Shell | View-model state transitions, haptic and sound mapping | XCTest |
| **Live continuation (A6)** | A real Claude Code + Codex session in a temp repo triggers an approval → Belay answers allow / deny-with-message → assert the agent continued as instructed | `e2e/` scripts run before every release. Locally first, CI where agent auth is possible. Whether `PermissionRequest` fires in headless `claude -p` runs is **UNVERIFIED**; drive an interactive session via a pty if needed. |
| Performance | Hook → rope latency, idle CPU and memory | A scripted benchmark in CI from v0.2 |

## 10. Cross-platform path (v0.3+)

1. Port `belayd` to **Rust** (`belay-core`) behind protocol v1, using the same test fixtures.
2. Build Windows and Linux shells in **Tauri**. A floating island at the top centre replaces the notch. Haptics and the Accessibility features degrade gracefully per platform.
3. The Mac Swift shell stays. It only ever spoke the protocol.
