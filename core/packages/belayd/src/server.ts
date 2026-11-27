// belayd's socket: newline-delimited protocol v1 over a 0600 Unix socket (ADR 0006). No TCP port.
import { chmodSync, existsSync, lstatSync, mkdirSync, unlinkSync } from "node:fs";
import { dirname } from "node:path";
import { Envelope, ShellRequest, type EngineId, type EngineRow } from "@belay/protocol";
import type { Task } from "@belay/protocol";
import { Registry } from "./crew/registry";
import { Routines } from "./crew/routines";
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
const MAX_TASKS = 200;

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
  const routines = new Routines();
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
  const put = (t: Task) => {
    tasks.set(t.id, t);
    // Finished tasks are forgotten oldest first, so a long-running core (or a noisy routine) can't grow without bound.
    for (const [id, old] of tasks) { if (tasks.size <= MAX_TASKS) break; if (["done", "stopped", "failed", "blocked"].includes(old.status)) tasks.delete(id); }
    push("task.updated", { task: t });
    return t;
  };
  const routineState = () => ({
    routines: routines.all,
    nextRun: Object.fromEntries(routines.all.map((r) => [r.id, routines.next(r)?.toISOString() ?? null])),
    when: Object.fromEntries(routines.all.map((r) => [r.id, routines.words(r)])),
  });
  /** A routine's time came (or you pressed run now): it makes a task, which waits for your OK to its plan like any other. */
  const fire = async (r: { buddy: string; goal: string }) => put(M.create(r.buddy, r.goal, undefined, await world()));
  // Every task ends: a clock enforces the time limit and fires due routines while the core runs.
  const clock = setInterval(() => {
    for (const t of tasks.values()) { const n = M.tick(t, new Date()); if (n !== t) put(n); }
    const due = routines.due();
    if (due.length) { due.forEach((r) => fire(r).catch(() => {})); push("crew.routines", routineState()); }
  }, 15_000);
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
      case "crew.list":
        send(s, env.id, "crew.roster", { type: "crew.roster", ...roster() });
        return send(s, env.id, "crew.routines", { type: "crew.routines", ...routineState() });
      case "crew.routine.create": {
        if (!registry.get(req.buddy)) return send(s, env.id, "crew.refused", { type: "crew.refused", why: `${req.buddy} is not on your crew` });
        const r = routines.create(req.buddy, req.goal, req.schedule);
        if (!r.ok) return send(s, env.id, "crew.refused", { type: "crew.refused", why: r.why });
        return push("crew.routines", routineState());
      }
      case "crew.routine.remove": routines.remove(req.id); return push("crew.routines", routineState());
      case "crew.routine.pause": routines.setPaused(req.id, req.paused); return push("crew.routines", routineState());
      case "crew.routine.runNow": { const r = routines.runNow(req.id); if (r) await fire(r); return; }
      case "crew.buddy.create": {
        const r = registry.create(req.by, req.spec);
        if (!r.ok) return send(s, env.id, "crew.refused", { type: "crew.refused", why: r.why });
        push("crew.created", { buddy: r.value, by: req.by });
        return push("crew.roster", roster());
      }
      case "crew.buddy.remove": {
        const r = registry.remove(req.by, req.id);
        if (!r.ok) return send(s, env.id, "crew.refused", { type: "crew.refused", why: r.why });
        for (const id of r.value) { talk.forget(id); routines.removeFor(id); for (const t of tasks.values()) if (t.buddy === id) put(M.stop(t)); push("crew.removed", { id, by: req.by }); }
        push("crew.routines", routineState());
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
        if (!req.goal.trim()) return send(s, env.id, "crew.refused", { type: "crew.refused", why: "say what the task is" });
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
          if (line.trim()) handle(s, line).catch(() => send(s, "", "error", { type: "error", message: "request failed" }));
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
