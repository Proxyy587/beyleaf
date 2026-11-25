# Spike A0: can Belay hold and steer Claude Code? (go/no-go)

**Result: GO.** Run on 2026-11-25 with Claude Code 2.1.311, Bun 1.4.5 and macOS 26, in the throwaway project
`~/Developer/belay-a0-test` (hooks in its own `.claude/settings.json`; the owner's global settings were untouched).

## What was built (`core/packages/belayd/spike/`)
- **`belayd.ts`:**
  - listens on a 0600 Unix socket at `~/Library/Application Support/Belay/belayd.sock` (ADR 0006);
  - logs every hook to `~/Library/Logs/Belay/a0-spike.jsonl`;
  - holds each `PermissionRequest` for `HOLD_SECONDS`, then follows a scripted policy: deny the first command with a steer, allow the steered command.
- **`belay-hook.ts`:** the command hook. It sends the hook's stdin to belayd as one newline-terminated line and prints belayd's JSON reply.
  - **Fail open** (ADR 0005): if belayd is down or replies with garbage, it prints nothing and exits 0.

## Results
| Check | Result |
|---|---|
| Transport round trip (no hold) | ~25 ms per hook, including Bun start-up |
| Hold | Held 20 s (13:50:37 → 13:50:57); Claude Code waited |
| Deny shape | `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"…"}}}`. Claude received the message and the command did not run |
| Allow shape | `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}` |
| Other events | `SessionStart`, `PreToolUse`, `PostToolUse` and `Stop` were all delivered and logged; an empty reply means no decision |
| belayd down | The shim printed nothing and exited 0, so Claude Code used its own flow |
| `claude -p` | `PermissionRequest` fires in headless mode, so the hook can answer there |
| **Steer, phrased as an instruction** ("Instead run `echo belay-steered`") | **Claude refused to follow it.** It treated an instruction inside a tool error as possible prompt injection |
| **Steer, attributed to the user, verbatim** ("The user reviewed this request in Belay … Their reply, verbatim: "…"") | **Claude followed it:** ran `echo belay-steered` and reported the output |

## What this decides
- **Approvals from the notch work** (A2), including a long hold while the user decides.
- **Steering works only as the user's own words, clearly attributed.** Belay must never write instructions of its own
  into a deny message. It relays what the user typed or said, verbatim, labelled as the user's (ADR 0020).
  - This is also the honest design, and it lines up with ADR 0011 (untrusted content can't grant permission).
- **The shim needs newline framing.** Bun closes the whole socket on a client half-close, so "write, then shutdown"
  loses the reply. Fixed in the spike, and the real shim must keep it.

## Not covered yet
- Codex hooks (the Codex CLI isn't installed).
- Interactive Claude Code sessions: only `-p` was run. The hook contract is the same, but the user-visible flow while held
  is UNVERIFIED.
- Hold times longer than a minute: the hook `timeout` was 60 s in the spike; the default is 600 s.
