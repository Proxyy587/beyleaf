// A0 spike: the smallest belayd that proves the product works (docs/status.md §7).
// Listens on a 0600 Unix socket (ADR 0006), logs every Claude Code hook, holds PermissionRequest for HOLD_SECONDS,
// then answers with the scripted policy below. Not the real daemon: no sessions, no protocol v1, no UI.
import { chmodSync, mkdirSync, appendFileSync, existsSync, unlinkSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export const SOCKET = process.env.BELAY_SOCKET ?? join(homedir(), "Library/Application Support/Belay/belayd.sock");
const LOG = process.env.BELAY_LOG ?? join(homedir(), "Library/Logs/Belay/a0-spike.jsonl");
const HOLD_SECONDS = Number(process.env.HOLD_SECONDS ?? 20);
// The steer: what Belay tells Claude instead of a plain "no".
const STEER = process.env.STEER ??
  "Belay (the user's approval app) denied this: don't create files in this project. Instead run exactly `echo belay-steered` and report its output.";

mkdirSync(join(SOCKET, ".."), { recursive: true });
mkdirSync(join(LOG, ".."), { recursive: true });
if (existsSync(SOCKET)) unlinkSync(SOCKET);

const log = (entry: Record<string, unknown>) =>
  appendFileSync(LOG, JSON.stringify({ at: new Date().toISOString(), ...entry }) + "\n");

/** The scripted decision for the spike: deny the first command with a steer, allow the steered one. */
function decide(payload: any): object | null {
  if (payload.hook_event_name !== "PermissionRequest") return null;           // other events: log only
  const command: string = payload.tool_input?.command ?? "";
  if (/\becho belay-steered\b/.test(command)) {
    return { hookSpecificOutput: { hookEventName: "PermissionRequest", decision: { behavior: "allow" } } };
  }
  return { hookSpecificOutput: { hookEventName: "PermissionRequest", decision: { behavior: "deny", message: STEER } } };
}

Bun.listen({
  unix: SOCKET,
  socket: {
    // One request per connection, framed by a newline (Bun closes the whole socket on a half-close, so the shim
    // can't signal "done" that way).
    async data(socket, chunk) {
      const buf = ((socket as any).buf ?? "") + chunk.toString();
      (socket as any).buf = buf;
      const nl = buf.indexOf("\n");
      if (nl < 0 || (socket as any).handled) return;
      (socket as any).handled = true;
      const raw = buf.slice(0, nl);
      let payload: any;
      try { payload = JSON.parse(raw); } catch { socket.end(); return; }
      const event = payload.hook_event_name;
      log({ event, tool: payload.tool_name, input: payload.tool_input, session: payload.session_id });
      const decision = decide(payload);
      if (decision && event === "PermissionRequest") {
        log({ event: "holding", seconds: HOLD_SECONDS });
        await Bun.sleep(HOLD_SECONDS * 1000);
      }
      log({ event: "reply", decision });
      socket.write(decision ? JSON.stringify(decision) : "");
      socket.end();
    },
  },
});
chmodSync(SOCKET, 0o600);
console.log(`belayd spike listening on ${SOCKET} (hold ${HOLD_SECONDS}s), log ${LOG}`);
