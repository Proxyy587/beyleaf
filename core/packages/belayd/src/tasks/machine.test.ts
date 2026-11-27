import { describe, expect, test } from "bun:test";
import * as M from "./machine";

const w = (o: Partial<M.World> = {}): M.World => ({ engineReady: true, tradingEnabled: false, now: new Date("2026-11-27T10:00:00Z"), ...o });
const music = [
  { id: "s1", label: "Open the browser", kind: "mac" as const },
  { id: "s2", label: "Search for the playlist", kind: "browse" as const },
  { id: "s3", label: "Press play", kind: "browse" as const },
];
const flight = [
  { id: "s1", label: "Search flights DEL to BOM", kind: "browse" as const },
  { id: "s2", label: "Hold the 09:10 fare", kind: "spend" as const, amount: 120 },
  { id: "s3", label: "Pay for the ticket", kind: "payment" as const },
];

describe("a task is only ever made by you", () => {
  test("it starts in planning and runs nothing", () => {
    const t = M.create("beepo", "open my browser and play music", undefined, w());
    expect(t.status).toBe("planning");
    expect(t.steps).toEqual([]);
  });
  test("no engine: blocked, with the reason", () => {
    const t = M.create("beepo", "open my browser", undefined, w({ engineReady: false }));
    expect(t.status).toBe("blocked");
    expect(t.note).toContain("engine");
  });
});

describe("plan approval", () => {
  test("a plan waits for your OK; nothing runs before it", () => {
    let t = M.plan(M.create("beepo", "play music", undefined, w()), music, w());
    expect(t.status).toBe("needs-plan-ok");
    expect(t.steps.every((s) => s.status === "todo")).toBe(true);
    t = M.approvePlan(t, w());
    expect(t.status).toBe("running");
    expect(t.steps[0]!.status).toBe("doing");
  });
  test("approving twice does nothing new", () => {
    const t = M.approvePlan(M.plan(M.create("beepo", "play music", undefined, w()), music, w()), w());
    expect(M.approvePlan(t, w())).toBe(t);
  });
  test("a plan over the step limit is blocked", () => {
    const steps = Array.from({ length: 5 }, (_, i) => ({ id: `s${i}`, label: "x", kind: "browse" as const }));
    expect(M.plan(M.create("beepo", "tidy up", { maxSteps: 3, maxMinutes: 10 }, w()), steps, w()).status).toBe("blocked");
  });
  test("an empty plan fails", () => {
    expect(M.plan(M.create("beepo", "tidy up", undefined, w()), [], w()).status).toBe("failed");
  });
});

describe("running a safe task", () => {
  test("browse and mac steps go on one after another until done", () => {
    let t = M.approvePlan(M.plan(M.create("beepo", "play music", undefined, w()), music, w()), w());
    for (let i = 0; i < 3; i++) { expect(t.status).toBe("running"); t = M.finish(t, true); }
    expect(t.status).toBe("done");
    expect(M.progress(t)).toEqual({ done: 3, total: 3 });
  });
  test("a failed step fails the task and runs nothing further", () => {
    let t = M.approvePlan(M.plan(M.create("beepo", "play music", undefined, w()), music, w()), w());
    t = M.finish(t, false);
    expect(t.status).toBe("failed");
    expect(t.steps[1]!.status).toBe("todo");
  });
});

describe("money", () => {
  test("a money goal with no limit is blocked before anything is planned", () => {
    expect(M.create("beepo", "book me a flight to Mumbai", undefined, w()).status).toBe("blocked");
  });
  test("a plan that would move more than the limit is blocked", () => {
    const t = M.create("beepo", "book me a flight to Mumbai", { maxSteps: 30, maxMinutes: 60, maxMoney: 100, currency: "USD" }, w());
    expect(M.plan(t, flight, w()).status).toBe("blocked");
  });
  test("a spend asks every time, then a payment is handed to you", () => {
    const limits = { maxSteps: 30, maxMinutes: 60, maxMoney: 150, currency: "USD" };
    let t = M.approvePlan(M.plan(M.create("beepo", "book me a flight to Mumbai", limits, w()), flight, w()), w());
    t = M.finish(t, true); // search done
    expect(t.status).toBe("needs-you");
    expect(M.waitingOn(t)?.kind).toBe("spend");
    t = M.approveStep(t);
    expect(t.status).toBe("running");
    t = M.finish(t, true);
    expect(t.moved).toBe(120);
    expect(t.status).toBe("needs-you");
    expect(M.waitingOn(t)?.kind).toBe("payment");
    expect(t.note).toContain("You pay");
    t = M.approveStep(t); // "I paid"
    expect(t.status).toBe("done");
  });
  test("denying a spend skips it and goes on", () => {
    const limits = { maxSteps: 30, maxMinutes: 60, maxMoney: 150 };
    let t = M.approvePlan(M.plan(M.create("beepo", "book me a flight", limits, w()), flight, w()), w());
    t = M.denyStep(M.finish(t, true));
    expect(t.steps[1]!.status).toBe("skipped");
    expect(M.waitingOn(t)?.kind).toBe("payment");
  });
  test("a second spend past the limit stops the task", () => {
    const limits = { maxSteps: 30, maxMinutes: 60, maxMoney: 150 };
    const steps = [
      { id: "a", label: "Hold seat", kind: "spend" as const, amount: 100 },
      { id: "b", label: "Hold seat", kind: "spend" as const, amount: 50 },
    ];
    let t = M.approvePlan(M.plan(M.create("beepo", "buy two tickets", limits, w()), steps, w()), w());
    t = M.finish(M.approveStep(t), true);
    expect(t.moved).toBe(100);
    t = M.approveStep({ ...t, limits: { ...t.limits, maxMoney: 120 } }); // limit lowered mid-way
    expect(t.status).toBe("stopped");
  });
  test("a spend never runs without your approval, even as the first step", () => {
    const limits = { maxSteps: 30, maxMinutes: 60, maxMoney: 150 };
    const t = M.approvePlan(M.plan(M.create("beepo", "buy a ticket", limits, w()), [{ id: "a", label: "Buy", kind: "spend", amount: 10 }], w()), w());
    expect(t.status).toBe("needs-you");
  });
});

describe("trading is off, and 'until the amount is reached' does not exist", () => {
  test("a trading goal is blocked even with a limit and an engine", () => {
    const t = M.create("beepo", "start trading with my money and don't stop until it reaches 10000", { maxSteps: 30, maxMinutes: 60, maxMoney: 500 }, w());
    expect(t.status).toBe("blocked");
    expect(t.note).toContain("Trading");
  });
  test("a plan with a trade step is blocked", () => {
    const t = M.create("beepo", "rebalance", { maxSteps: 30, maxMinutes: 60, maxMoney: 500 }, w());
    expect(M.plan(t, [{ id: "a", label: "Sell 1 share", kind: "trade", amount: 10 }], w()).status).toBe("blocked");
  });
  test("every task ends: by the time limit", () => {
    let t = M.approvePlan(M.plan(M.create("beepo", "play music", { maxSteps: 5, maxMinutes: 10 }, w()), music, w()), w());
    expect(M.tick(t, new Date("2026-11-27T10:09:00Z")).status).toBe("running");
    t = M.tick(t, new Date("2026-11-27T10:11:00Z"));
    expect(t.status).toBe("stopped");
    expect(t.note).toContain("time limit");
  });
});

describe("you are always in charge", () => {
  test("stop ends a running task and does not touch a finished one", () => {
    const t = M.approvePlan(M.plan(M.create("beepo", "play music", undefined, w()), music, w()), w());
    expect(M.stop(t).status).toBe("stopped");
    const done = { ...t, status: "done" as const };
    expect(M.stop(done)).toBe(done);
  });
  test("pause and resume keep an approval waiting", () => {
    const limits = { maxSteps: 30, maxMinutes: 60, maxMoney: 150 };
    let t = M.finish(M.approvePlan(M.plan(M.create("beepo", "book a flight", limits, w()), flight, w()), w()), true);
    expect(t.status).toBe("needs-you");
    t = M.pause(t, true);
    expect(t.status).toBe("paused");
    expect(M.pause(t, false).status).toBe("needs-you");
  });
});
