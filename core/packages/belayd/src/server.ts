// belayd's socket: newline-delimited protocol v1 over a 0600 Unix socket (ADR 0006). No TCP port.
import { chmodSync, existsSync, lstatSync, mkdirSync, unlinkSync } from "node:fs";
import { dirname } from "node:path";
import { Envelope, ShellRequest, type EngineId, type EngineRow } from "@belay/protocol";
import type { Task } from "@belay/protocol";
import { Registry } from "./crew/registry";
import { Talk } from "./crew/talk";
import * as M from "./tasks/machine";
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

  // The crew starts as beepo alone; buddies and tasks exist only because you (or a buddy you made) asked (docs/buddies.md).
  const registry = new Registry();
  const talk = new Talk(registry);
  const tasks = new Map<string, Task>();
  const clients = new Set<import("bun").Socket<Conn>>();
  const watching = new Map<EngineId, AbortController>();

  const row = async (id: EngineId): Promise<EngineRow> => {
    const status = await detectEngine(ENGINES.find((e) => e.id === id)!, deps);
    return { status, step: connectPlan(status) };
  };
  const rows = () => Promise.all(ENGINES.map((e) => row(e.id)));
  const send = (s: import("bun").Socket<Conn>, id: string, type: string, data: object) => s.write(JSON.stringify({ v: 1, id, type, data }) + "\n");
  const broadcast = (data: object) => clients.forEach((c) => send(c, "", "engines.updated", data));
  const push = (type: string, data: object) => clients.forEach((c) => send(c, "", type, { type, ...data }));
  const roster = () => ({ buddies: registry.buddies, states: Object.fromEntries(registry.buddies.map((b) => [b.id, "idle"])), notes: talk.notes() });
  const world = async (): Promise<M.World> => ({ engineReady: (await rows()).some((r) => r.status.auth === "signed-in"), tradingEnabled: false, now: new Date() });
  const put = (t: Task) => { tasks.set(t.id, t); push("task.updated", { task: t }); return t; };
  // Every task ends: a clock enforces the time limit while the core runs.
  const clock = setInterval(() => { for (const t of tasks.values()) { const n = M.tick(t, new Date()); if (n !== t) put(n); } }, 15_000);
  clock.unref();

  async function handle(s: import("bun").Socket<Conn>, line: string) {
    let env;
    try { env = Envelope.parse(JSON.parse(line)); } catch { return send(s, "", "error", { type: "error", message: "bad envelope" }); }
    const parsed = ShellRequest.safeParse({ type: env.type, ...(env.data as object | undefined) });
    if (!parsed.success) return send(s, env.id, "error", { type: "error", message: `unknown request ${env.type}` });
    const req = parsed.data;
    switch (req.type) {
      case "ping": return send(s, env.id, "pong", { type: "pong" });
      case "engines.list": return send(s, env.id, "engines.list.result", { type: "engines.list.result", engines: await rows() });
      case "crew.list": return send(s, env.id, "crew.roster", { type: "crew.roster", ...roster() });
      case "crew.buddy.create": {
        const r = registry.create(req.by, req.spec);
        if (!r.ok) return send(s, env.id, "crew.refused", { type: "crew.refused", why: r.why });
        push("crew.created", { buddy: r.value, by: req.by });
        return push("crew.roster", roster());
      }
      case "crew.buddy.remove": {
        const r = registry.remove(req.by, req.id);
        if (!r.ok) return send(s, env.id, "crew.refused", { type: "crew.refused", why: r.why });
        for (const id of r.value) { talk.forget(id); for (const t of tasks.values()) if (t.buddy === id) put(M.stop(t)); push("crew.removed", { id, by: req.by }); }
        return push("crew.roster", roster());
      }
      case "crew.tell": {
        const r = talk.tell(req.from, req.to, req.text);
        return r.ok ? push("crew.message", { message: r.value }) : send(s, env.id, "crew.refused", { type: "crew.refused", why: r.why });
      }
      case "crew.share": {
        const r = talk.share(req.by, req.key, req.text);
        return r.ok ? push("crew.roster", roster()) : send(s, env.id, "crew.refused", { type: "crew.refused", why: r.why });
      }
      case "task.create": {
        if (!registry.get(req.buddy)) return send(s, env.id, "crew.refused", { type: "crew.refused", why: `${req.buddy} is not on your crew` });
        put(M.create(req.buddy, req.goal, req.limits, await world()));
        return;
      }
      case "task.approve": case "task.deny": case "task.stop": case "task.pause": {
        const t = tasks.get(req.id);
        if (!t) return send(s, env.id, "crew.refused", { type: "crew.refused", why: "no such task" });
        const w = await world();
        const next = req.type === "task.stop" ? M.stop(t)
          : req.type === "task.pause" ? M.pause(t, req.paused)
          : req.type === "task.approve" ? (t.status === "needs-plan-ok" ? M.approvePlan(t, w) : M.approveStep(t))
          : (t.status === "needs-plan-ok" ? M.stop(t) : M.denyStep(t));
        put(next);
        return;
      }
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
    stop() { clearInterval(clock); watching.forEach((a) => a.abort()); server.stop(true); if (existsSync(socketPath)) unlinkSync(socketPath); },
  };
}
