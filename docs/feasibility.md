# Belay: technical feasibility

**Question:** What can be observed and controlled about a coding-agent session from **outside** the agent, and how much of that can a TypeScript web app or CLI do without a native macOS app?

**Research date:** **2026-11-23**, for docs and for local inspection.

## Sources

- **Docs read:**
  - Claude Code hooks reference: https://code.claude.com/docs/en/hooks.md
  - Claude Code Remote Control: https://code.claude.com/docs/en/remote-control.md
  - Claude Code monitoring/OTel: https://code.claude.com/docs/en/monitoring-usage.md
  - Codex hooks: https://developers.openai.com/codex/hooks
  - Codex app-server: https://developers.openai.com/codex/app-server
  - Gemini CLI hooks: https://geminicli.com/docs/hooks
- **Local inspection:** this Mac runs Claude Code **2.1.311** and has a Codex home directory (`~/.codex`). I read **structure only**: entry types, key names, file names. No prompt or code content was read or copied into these docs.
- **Undocumented internals:** anything observed locally but not described in vendor docs is marked **internal/undocumented**. It can change without notice.

---

## 1. Claude Code

### 1a. Hooks: the main supported interface

From the hooks reference:

- **Events (partial list):**
  - Session lifecycle: `SessionStart`, `SessionEnd`
  - Prompts: `UserPromptSubmit`
  - Tools: `PreToolUse` ("Can block it"), **`PermissionRequest`** ("When a tool call needs a permission decision"), `PermissionDenied` ("When auto mode denies a tool call"), `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`
  - `Notification`
  - Subagents: `SubagentStart`, `SubagentStop`
  - Turn end: `Stop`, `StopFailure`
  - Compaction: `PreCompact`, `PostCompact`
  - Environment: `CwdChanged`, `FileChanged`
  - Worktrees: `WorktreeCreate`, `WorktreeRemove`
  - Others
- **Handler types:**
  - "shell commands, HTTP endpoints, MCP tool calls, LLM prompts, or subagents"
  - An HTTP hook is configured as `{"type": "http", "url": "http://localhost:8080/hooks/pre-tool-use", "timeout": 30, "headers": {...}}`.
  - Default timeout is **600 s** for `command`, `http` and `mcp_tool`.
- **Approval from outside:**
  - `PermissionRequest` hooks "can allow or deny permission requests" with `decision.behavior: "allow" | "deny"`.
  - For allow only, they can also return `updatedInput`, which "modifies the tool's input parameters before execution". That is a limited form of steering: you can rewrite the command it is about to run.
  - A hook "can't approve what a deny rule refuses".
- **Common input fields** include `session_id`, `transcript_path`, `cwd` and `permission_mode`.
- **Transcript lag:** "The transcript file is written asynchronously and may lag the in-memory conversation… Hooks that need the final assistant text of the current turn should use `last_assistant_message` on Stop."
- **Exit codes:**
  - 0 means success. JSON on stdout is honoured as structured output.
  - 2 blocks, with per-event behaviour.
  - Bad JSON on exit 0 is a "non-blocking error", and the action proceeds.
- **Fires everywhere:** hooks "fire the same hook events wherever it runs: sessions in the terminal, IDE extensions, the Desktop app, and cloud sessions".

**Meaning for Belay:** a plain Node process listening on `localhost` can receive every tool call and every permission request from every Claude Code session, then hold the HTTP response open until a human clicks Allow or Deny in a browser. **Approval does not need native code.** This is the same mechanism the free tools in `landscape.md` use.

### 1b. Session transcripts (JSONL)

- **Location:**
  - Path: `~/.claude/projects/<cwd-with-slashes-as-dashes>/<sessionId>.jsonl`
  - The directory layout was observed on this machine.
  - The format is not a documented stable interface; the hooks doc only exposes it as `transcript_path`.
- **What one session file contained** (counts of entry `type`):
  - `user`, `assistant`, `system`, `attachment`
  - `file-history-snapshot`
  - `permission-mode`, `mode`
  - `ai-title`, `last-prompt`, `tools-used`
  - `api-request`, `api-request-blob`, `api-request-shape`
- **Message content blocks:** `text`, `thinking`, `tool_use`, `tool_result`, `tool_addition`.
- **Top-level keys** include `sessionId`, `cwd`, `gitBranch`, `timestamp`, `uuid`/`parentUuid`, `isSidechain` (subagents), `toolUseResult`, `requestId`, `version`, and **`permissionDecision`**.
- **`permissionDecision` is the interesting one.** Across this machine's transcripts it held values such as `{"decision":"accept","source":"config","reasonType":"classifier"}` (53 occurrences) and one `{"decision":"reject",…,"reasonType":"classifier",…}`. So the transcript records **what auto mode's classifier allowed and rejected**, per tool call. This is **internal/undocumented**.
- **Other files** (internal/undocumented):
  - `~/.claude/sessions/<pid>.json` holds `pid`, `sessionId`, `cwd`, `startedAt`, `version`, `kind` (e.g. "interactive"), `entrypoint` and a `messagingSocketPath` (`/tmp/cc-socks/<pid>.sock`). Useful for "which sessions are alive right now", but do not build on the socket.
  - `~/.claude/history.jsonl` exists.

### 1c. OpenTelemetry (official)

- The monitoring docs define events including `tool_decision`. **"When `classifier_verdict` is present, it gives the classifier outcome that decided the call."** There is also a `safety_event`.
- Tool arguments (e.g. Bash commands) appear only with `OTEL_LOG_TOOL_DETAILS=1`.
- **Meaning for Belay:** a supported, versioned way to collect allow/deny decisions, including auto-mode verdicts, without parsing internal JSONL. A Node OTLP receiver is ordinary TypeScript.

### 1d. Remote Control (official, competes directly)

- Connects claude.ai/code or the Claude mobile app to a **local** session.
- "Push when actions required" sends permission prompts to the phone.
- Prompts stay open "until you answer them".
- **Meaning for Belay:** for a Claude-Code-only user, "approve when I'm away from the terminal" is already a first-party feature.

### 1e. MCP and config

- Hooks can call MCP tools (`type: "mcp_tool"`).
- Config lives in `settings.json` (user, project or managed).
- **Installing Belay means writing hook entries into a user's settings.** That is a trust and security ask, and the same one every competitor makes.

---

## 2. OpenAI Codex

### 2a. Hooks (official)

- **Location:** `hooks.json` at `/etc/codex/hooks.json`, `$CODEX_HOME/hooks.json` (default `~/.codex/hooks.json`) or a trusted project's `.codex/hooks.json`, or inline under `[hooks]` in `config.toml`.
- **Events:**
  - During a turn: `PreToolUse`, **`PermissionRequest`**, `PostToolUse`, `PreCompact`, `PostCompact`, `UserPromptSubmit`, `SubagentStop`, `Stop`
  - Per model request: `PreModelRequest`, `PostModelRequest`
  - On interruption: `Interrupt`
  - At start: `SessionStart`, `SubagentStart`
  - At end: `SessionEnd`
- **`PermissionRequest`:**
  - Returns `{"decision":{"behavior":"allow"}}` or `{"behavior":"deny","message":"…"}`. "Any deny wins."
  - **"Don't return `updatedInput`, `updatedPermissions`, or `interrupt` for PermissionRequest; those fields are reserved for future behavior and fail closed today."**
  - So **Codex supports allow/deny only. You cannot rewrite the command through this hook.**
- **"Non-managed hooks must be reviewed and trusted before they run."** Every user has an extra trust step at install.
- `transcript_path` is provided, but "the transcript format isn't a stable interface".
- **Handler types:** from the doc's own description ("Run scripts or MCP tools"), command and MCP handlers exist. **UNVERIFIED whether Codex has an HTTP hook type like Claude Code's.** If not, a tiny command-hook shim that POSTs to localhost does the same job.

### 2b. Session logs

- **Location:** `~/.codex/sessions/YYYY/MM/DD/rollout-<timestamp>-<uuid>.jsonl.zst`
- **On this machine all 59 rollout files are zstd-compressed** (`.jsonl.zst`), so any reader needs a zstd decoder. Several SQLite stores (`state_5.sqlite`, `logs_2.sqlite`, `thread_history_1.sqlite`, etc.) also exist.
- All of this is **internal/undocumented**, and the docs explicitly warn the transcript format is unstable.
- `config.toml` on this machine has a `notify` key: a notification command hook. Its exact semantics are not verified in this pass.

### 2c. App-server (official JSON-RPC)

- `codex app-server` speaks JSON-RPC over stdio (default), a Unix socket, or WebSocket ("experimental and unsupported").
- Messages include `thread/list`, `thread/turns/list`, `thread/items/list` and `item/commandExecution/requestApproval`, with `command`, `cwd`, `reason` and `availableDecisions`.
- **This is how a client that hosts Codex sessions drives approvals.** **UNVERIFIED:** whether a third-party process can attach to a Codex TUI session the user started separately, or only to sessions the app-server itself runs. For Belay, assume hooks are the attach path and the app-server is the "Belay launches the agent" path.

---

## 3. Gemini CLI

- **Hook events:** `BeforeTool`, `AfterTool`, `BeforeAgent`, `AfterAgent`, `BeforeModel`, `AfterModel`, `BeforeToolSelection`, `Notification`, `PreCompress`, `SessionStart`, `SessionEnd`.
- **UNVERIFIED** whether `BeforeTool` can return an allow/deny that replaces the interactive prompt. I did not read that section.
- **Market note from the docs banner:** "Unpaid tier and Google One users: Gemini CLI was replaced by Antigravity CLI on June 18th, 2026." Weekly npm downloads (2026-11-16 to 22): `@google/gemini-cli` **565,013**, versus `@openai/codex` **27,601,227** and `@anthropic-ai/claude-code` **22,171,378**. Gemini CLI support is low priority.

---

## 4. The decisive question: TypeScript web/CLI vs native macOS

### What a TypeScript CLI + local web UI CAN do (all on documented interfaces)

| Capability | How |
|---|---|
| Live list of sessions and their status (working / waiting / done) | Claude Code hooks (`SessionStart`, `PreToolUse`, `Notification`, `Stop`, `SessionEnd`) POST to a local Node server. Codex hooks via a command shim. |
| **Approve / deny** a pending tool call | Claude Code `PermissionRequest` (HTTP hook, response held up to 600 s). Codex `PermissionRequest` (command hook). |
| Rewrite a command before it runs (light steering) | Claude Code only (`updatedInput`). **Not Codex** (fails closed). |
| Replay a session step by step | Parse `transcript_path` JSONL (Claude). Decompress `.jsonl.zst` (Codex). Both formats are unstable. |
| Audit what auto mode allowed and blocked | OTel `tool_decision.classifier_verdict` (documented) or transcript `permissionDecision` (undocumented) |
| Cost and token reporting | Transcripts or OTel (already done well by ccusage) |
| Notifications | Browser Notification API while a tab is open, or the CLI daemon shelling out to `osascript`/`terminal-notifier`, or ntfy/Pushover to a phone |
| Phone approval | Expose the local server via a tunnel. **Security-sensitive**, since this means remote code-execution approval over the internet. Remote Control already does this first-party for Claude Code. |
| Kill a runaway session | The CLI can signal the PID (from hook context or `~/.claude/sessions/<pid>.json`, undocumented) |
| Tray icon / always-on-top window | **Electron or Tauri**, still mostly TypeScript. Electron's tray and always-on-top windows are standard. A convincing **notch** UI in Electron is **UNVERIFIED** and likely to feel non-native. |

### What a non-native (browser or plain CLI) version could NOT do

1. **Live in the notch or menu bar.** That presence is the entire UX of Aria, NotchNook, AgentPeek, Runnock, Perch and Notchi. A browser tab is not at-a-glance. Electron gets a tray icon, not a notch.
2. **Be there when the tab is closed.** Browser notifications need an open page (or a service worker plus push, which needs a server). A background CLI daemon fixes delivery but not visibility.
3. **System-wide hotkeys** (e.g. ⌥↵ to approve while in another app). The browser can't. Electron can (`globalShortcut`), so this is not native-only, but it is not web.
4. **Jump to the exact terminal tab or window** that needs you. A CLI can approximate this with AppleScript for iTerm2 and Terminal.app (onikan27/claude-code-monitor does), but not from a browser, and not reliably for every terminal (Ghostty, Warp, VS Code's terminal).
5. **Type into a running TUI session** to steer it with free text. No documented interface exists for any of the three agents. The only routes are hooks (allow/deny/rewrite), `tmux send-keys` if the user happens to run inside tmux, or launching the agent yourself (Codex app-server, or Claude Code's Agent SDK). Aria advertises "Steer mid-run"; how it does this is **UNVERIFIED**.
6. **Observe GUI-only agents** (Cursor, Copilot in an IDE) beyond what they write to disk. Aria itself labels these "observe-only".
7. **Signed, notarized, trusted desktop install.** Telling users to install a hook that can approve shell commands via an `npx` web app is a harder trust ask than a notarized Mac app.

### Net feasibility

- **Technically, roughly 80% of the Belay feature set is buildable in TypeScript on documented hooks.** Approve/deny, a live session list, replay, audit and cost all fit.
- **What native buys is ambient presence (notch/menu bar) and polish. That is exactly the dimension the existing paid competitors sell on.** A web-based Belay would compete on the free-OSS side of the market (claude-code-monitor, claude-view, Agents Observe), where nobody has a business.
- **Fragility:**
  - Transcript formats are unstable for both vendors (Codex says so explicitly).
  - Hook schemas evolve quickly; the docs cite version gates in the v2.1.2xx–2.1.3xx range.
  - Any replay or audit feature built on JSONL parsing will need ongoing maintenance.
  - **The documented OTel path is the only one built for durability.**
