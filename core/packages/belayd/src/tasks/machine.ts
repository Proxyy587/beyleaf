// A task is a goal a buddy works toward in steps (docs/buddies.md §6a). This file is the whole policy for what may run
// without you, as pure functions over a task, so the tests pin every rule:
//   - nothing is made or run on its own: a task starts only when you ask, and runs only after you approve its plan;
//   - steps that move money or speak for you (spend, send, trade) ask every time, with no "Always";
//   - paying is yours: a `payment` step hands the page to you, Belay never types card or bank details;
//   - hard limits (steps, minutes, money) can't be raised by the task, and hitting one stops it;
//   - "keep going until X" is not a thing: every task ends by finishing, by a limit, or by your stop.
import type { Limits, Step, Task } from "@belay/protocol";

export const ASKS_EVERY_TIME: ReadonlySet<Step["kind"]> = new Set(["spend", "send", "trade"]);
export const MONEY: ReadonlySet<Step["kind"]> = new Set(["spend", "payment", "trade"]);
const AUTO: ReadonlySet<Step["kind"]> = new Set(["observe", "browse", "mac", "code"]);

export interface World {
  /** A signed-in engine exists to plan and carry steps out. */
  engineReady: boolean;
  /** Trading needs a broker connection and legal sign-off (docs/trading.md). Off in v1. */
  tradingEnabled: boolean;
  now: Date;
}

export const DEFAULT_LIMITS: Limits = { maxSteps: 30, maxMinutes: 60 };
const MONEY_WORDS = /\b(trad(e|es|ing)|invest(ing)?|stocks?|shares?|crypto|forex|buy|sell|book|purchase|pay|order|flights?|tickets?)\b/i;
const TRADE_WORDS = /\b(trad(e|es|ing)|invest(ing)?|stocks?|shares?|crypto|forex)\b/i;

/** A rough read of the words, as a belt on top of the step kinds: it can only make a task stricter. */
export function looksLikeMoney(goal: string): boolean { return MONEY_WORDS.test(goal); }
export function looksLikeTrading(goal: string): boolean { return TRADE_WORDS.test(goal); }

let counter = 0;
export function create(buddy: string, goal: string, limits: Limits | undefined, w: World): Task {
  const l = { ...DEFAULT_LIMITS, ...limits };
  const base: Task = { id: `t${++counter}`, buddy, goal: goal.trim(), status: "planning", steps: [], limits: l, moved: 0, startedAt: null, note: "Waiting for the engine to plan it." };
  if (looksLikeTrading(goal) && !w.tradingEnabled) {
    return { ...base, status: "blocked", note: "Trading isn't switched on: it needs a broker connection and a legal check first. Nothing was started." };
  }
  if (looksLikeMoney(goal) && l.maxMoney === undefined) {
    return { ...base, status: "blocked", note: "This involves money. Set the most it may spend, then ask again." };
  }
  if (!w.engineReady) return { ...base, status: "blocked", note: "No engine is signed in to plan this. Sign one in under Settings, Agents." };
  return base;
}

/** The plan arrives (from an engine, later). Rejected if it breaks a limit; otherwise it waits for your OK. */
export function plan(t: Task, steps: Omit<Step, "status">[], w: World): Task {
  if (t.status !== "planning") return t;
  if (steps.length === 0) return { ...t, status: "failed", note: "The plan had no steps." };
  if (steps.length > t.limits.maxSteps) return { ...t, status: "blocked", note: `The plan has ${steps.length} steps; the limit is ${t.limits.maxSteps}.` };
  if (steps.some((s) => s.kind === "trade") && !w.tradingEnabled) return { ...t, status: "blocked", note: "The plan trades, and trading isn't switched on." };
  const total = steps.reduce((n, s) => n + (s.kind === "spend" || s.kind === "trade" ? (s.amount ?? 0) : 0), 0);
  const hasMoney = steps.some((s) => MONEY.has(s.kind));
  if (hasMoney && t.limits.maxMoney === undefined) return { ...t, status: "blocked", note: "The plan involves money and no spending limit is set." };
  if (t.limits.maxMoney !== undefined && total > t.limits.maxMoney) return { ...t, status: "blocked", note: `The plan would move ${total}; the limit is ${t.limits.maxMoney}.` };
  return { ...t, status: "needs-plan-ok", steps: steps.map((s) => ({ ...s, status: "todo" as const })), note: undefined };
}

/** What the task is waiting for next, if anything. */
export function waitingOn(t: Task): Step | undefined {
  return t.status === "needs-you" ? t.steps.find((s) => s.status === "doing") : undefined;
}

function advance(t: Task): Task {
  const next = t.steps.find((s) => s.status === "todo");
  if (!next) return { ...t, status: "done", note: undefined };
  const steps = t.steps.map((s) => (s === next ? { ...s, status: "doing" as const } : s));
  if (next.kind === "payment") return { ...t, steps, status: "needs-you", note: "You pay. Belay never types card or bank details; the page is yours." };
  if (ASKS_EVERY_TIME.has(next.kind)) return { ...t, steps, status: "needs-you", note: "Needs your OK." };
  if (AUTO.has(next.kind)) return { ...t, steps, status: "running", note: undefined };
  return { ...t, steps, status: "failed", note: `Unknown step kind ${next.kind}` };
}

export function approvePlan(t: Task, w: World): Task {
  if (t.status !== "needs-plan-ok") return t;
  return advance({ ...t, status: "running", startedAt: w.now.toISOString() });
}

/** You approve the step it is waiting on (spend, send, trade), or confirm that you did the payment yourself. */
export function approveStep(t: Task): Task {
  const step = waitingOn(t);
  if (!step) return t;
  if (step.kind === "payment") return finish(t, true);
  const amount = step.amount ?? 0;
  if (t.limits.maxMoney !== undefined && t.moved + amount > t.limits.maxMoney) {
    return { ...t, status: "stopped", note: `That would pass the spending limit (${t.limits.maxMoney}).` };
  }
  return { ...t, status: "running", note: undefined };
}

export function denyStep(t: Task): Task {
  const step = waitingOn(t);
  if (!step) return t;
  return advance({ ...t, steps: t.steps.map((s) => (s === step ? { ...s, status: "skipped" as const } : s)) });
}

/** The engine reports the step it was doing as finished or failed. */
export function finish(t: Task, ok: boolean): Task {
  const step = t.steps.find((s) => s.status === "doing");
  if (!step || (t.status !== "running" && t.status !== "needs-you")) return t;
  const moved = ok && (step.kind === "spend" || step.kind === "trade") ? t.moved + (step.amount ?? 0) : t.moved;
  const steps = t.steps.map((s) => (s === step ? { ...s, status: ok ? ("done" as const) : ("failed" as const) } : s));
  if (!ok) return { ...t, steps, moved, status: "failed", note: `Stopped: "${step.label}" failed.` };
  return advance({ ...t, steps, moved });
}

export function stop(t: Task): Task {
  if (t.status === "done" || t.status === "stopped" || t.status === "failed") return t;
  return { ...t, status: "stopped", note: "You stopped it.", steps: t.steps.map((s) => (s.status === "doing" ? { ...s, status: "skipped" as const } : s)) };
}

export function pause(t: Task, paused: boolean): Task {
  if (paused && (t.status === "running" || t.status === "needs-you")) return { ...t, status: "paused" };
  if (!paused && t.status === "paused") return { ...t, status: t.steps.some((s) => s.status === "doing" && (ASKS_EVERY_TIME.has(s.kind) || s.kind === "payment")) ? "needs-you" : "running" };
  return t;
}

/** Called on a clock. A task past its time limit stops, wherever it was. */
export function tick(t: Task, now: Date): Task {
  if (!t.startedAt || (t.status !== "running" && t.status !== "needs-you" && t.status !== "paused")) return t;
  if (now.getTime() - Date.parse(t.startedAt) > t.limits.maxMinutes * 60_000) return { ...stop(t), note: `Stopped at the time limit (${t.limits.maxMinutes} min).` };
  return t;
}

/** The number of steps finished, for a progress line. */
export function progress(t: Task): { done: number; total: number } {
  return { done: t.steps.filter((s) => s.status === "done" || s.status === "skipped").length, total: t.steps.length };
}
