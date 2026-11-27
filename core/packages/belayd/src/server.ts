// belayd's socket: newline-delimited protocol v1 over a 0600 Unix socket (ADR 0006). No TCP port.
import { chmodSync, existsSync, lstatSync, mkdirSync, unlinkSync } from "node:fs";
import { dirname } from "node:path";
import { Envelope, ShellRequest, type EngineId, type EngineRow } from "@belay/protocol";
import { ENGINES } from "./engines/catalog";
import { connectPlan, watchSignIn, type WatchOptions } from "./engines/connect";
import { detectEngine, type Deps } from "./engines/detect";

export interface ServerOptions {
  socketPath: string;
  deps: Deps;
  watch?: WatchOptions;
}

type Conn = { buf: string };

export function startServer({ socketPath, deps, watch }: ServerOptions) {
  mkdirSync(dirname(socketPath), { recursive: true, mode: 0o700 });
  if (existsSync(socketPath)) {
    // Only ever remove a stale socket, never some other file at that path.
    if (!lstatSync(socketPath).isSocket()) throw new Error(`${socketPath} exists and is not a socket`);
    unlinkSync(socketPath);
  }

  const clients = new Set<import("bun").Socket<Conn>>();
  const watching = new Map<EngineId, AbortController>();

  const row = async (id: EngineId): Promise<EngineRow> => {
    const status = await detectEngine(ENGINES.find((e) => e.id === id)!, deps);
    return { status, step: connectPlan(status) };
  };
  const rows = () => Promise.all(ENGINES.map((e) => row(e.id)));
  const send = (s: import("bun").Socket<Conn>, id: string, type: string, data: object) => s.write(JSON.stringify({ v: 1, id, type, data }) + "\n");
  const broadcast = (data: object) => clients.forEach((c) => send(c, "", "engines.updated", data));

  async function handle(s: import("bun").Socket<Conn>, line: string) {
    let env;
    try { env = Envelope.parse(JSON.parse(line)); } catch { return send(s, "", "error", { type: "error", message: "bad envelope" }); }
    const parsed = ShellRequest.safeParse({ type: env.type, ...(env.data as object | undefined) });
    if (!parsed.success) return send(s, env.id, "error", { type: "error", message: `unknown request ${env.type}` });
    const req = parsed.data;
    switch (req.type) {
      case "ping": return send(s, env.id, "pong", { type: "pong" });
      case "engines.list": return send(s, env.id, "engines.list.result", { type: "engines.list.result", engines: await rows() });
      case "engines.cancel": watching.get(req.id)?.abort(); return send(s, env.id, "pong", { type: "pong" });
      case "engines.signin": {
        const r = await row(req.id);
        const waiting = r.step.kind === "signin";
        send(s, env.id, "engines.signin.result", { type: "engines.signin.result", row: r, watching: waiting });
        if (waiting && !watching.has(req.id)) {
          const ac = new AbortController();
          watching.set(req.id, ac);
          // The user runs the vendor's command in Terminal; re-read the CLI's own status until it says signed in.
          void watchSignIn(async () => (await row(req.id)).status.auth, { ...watch, signal: ac.signal }).then(async () => {
            watching.delete(req.id);
            broadcast({ type: "engines.updated", engines: await rows() });
          });
        }
        return;
      }
    }
  }

  const server = Bun.listen<Conn>({
    unix: socketPath,
    socket: {
      open(s) { s.data = { buf: "" }; clients.add(s); },
      close(s) { clients.delete(s); },
      data(s, chunk) {
        s.data.buf += chunk.toString();
        if (s.data.buf.length > 1_000_000) return s.end();
        let nl: number;
        while ((nl = s.data.buf.indexOf("\n")) >= 0) {
          const line = s.data.buf.slice(0, nl);
          s.data.buf = s.data.buf.slice(nl + 1);
          if (line.trim()) void handle(s, line);
        }
      },
    },
  });
  chmodSync(socketPath, 0o600);
  return {
    socketPath,
    stop() { watching.forEach((a) => a.abort()); server.stop(true); if (existsSync(socketPath)) unlinkSync(socketPath); },
  };
}
