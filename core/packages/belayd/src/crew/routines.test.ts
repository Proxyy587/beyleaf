import { beforeAll, describe, expect, test } from "bun:test";
import { Routines } from "./routines";

beforeAll(() => { process.env.TZ = "UTC"; });
let clock = new Date("2026-11-27T07:00:00Z");
const mk = () => new Routines(() => clock);
const set = (s: string) => { clock = new Date(s); };

describe("routines", () => {
  test("a daily routine is due at its time, once", () => {
    set("2026-11-27T07:00:00Z");
    const rs = mk();
    const r = rs.create("beepo", "summarise my inbox", { kind: "daily", time: "08:30", days: [] });
    expect(r.ok).toBe(true);
    expect(rs.due()).toEqual([]);
    set("2026-11-27T08:31:00Z");
    expect(rs.due().map((x) => x.goal)).toEqual(["summarise my inbox"]);
    expect(rs.due()).toEqual([]); // not again until tomorrow
    set("2026-11-28T08:31:00Z");
    expect(rs.due().length).toBe(1);
  });
  test("missed runs collapse into one", () => {
    set("2026-11-27T07:00:00Z");
    const rs = mk();
    rs.create("beepo", "tidy", { kind: "every", minutes: 60 });
    set("2026-11-27T19:00:00Z"); // the Mac slept for twelve hours
    expect(rs.due().length).toBe(1);
    expect(rs.due().length).toBe(0);
  });
  test("a paused routine never fires, and resuming doesn't owe the time paused", () => {
    set("2026-11-27T07:00:00Z");
    const rs = mk();
    const r = rs.create("beepo", "tidy", { kind: "every", minutes: 60 });
    if (!r.ok) throw new Error();
    rs.setPaused(r.value.id, true);
    set("2026-11-27T12:00:00Z");
    expect(rs.due()).toEqual([]);
    rs.setPaused(r.value.id, false);
    expect(rs.due()).toEqual([]); // counted from now
    set("2026-11-27T13:05:00Z");
    expect(rs.due().length).toBe(1);
  });
  test("a one-off runs once and goes", () => {
    set("2026-11-27T07:00:00Z");
    const rs = mk();
    rs.create("beepo", "remind me", { kind: "once", at: "2026-11-27T09:00:00Z" });
    set("2026-11-27T09:01:00Z");
    expect(rs.due().length).toBe(1);
    expect(rs.all.length).toBe(0);
  });
  test("refuses past one-offs, too-frequent runs and a full list", () => {
    set("2026-11-27T07:00:00Z");
    const rs = mk();
    expect(rs.create("beepo", "x", { kind: "once", at: "2026-11-27T06:00:00Z" }).ok).toBe(false);
    expect(rs.create("beepo", "x", { kind: "every", minutes: 1 }).ok).toBe(false);
    for (let i = 0; i < 20; i++) rs.create("beepo", `g${i}`, { kind: "every", minutes: 60 });
    expect(rs.create("beepo", "one more", { kind: "every", minutes: 60 }).ok).toBe(false);
  });
  test("event routines are never due by the clock", () => {
    set("2026-11-27T07:00:00Z");
    const rs = mk();
    rs.create("beepo", "when done", { kind: "event", name: "session.done" });
    set("2027-01-01T00:00:00Z");
    expect(rs.due()).toEqual([]);
  });
  test("removing a buddy removes its routines", () => {
    set("2026-11-27T07:00:00Z");
    const rs = mk();
    rs.create("sprout", "a", { kind: "every", minutes: 60 });
    rs.create("beepo", "b", { kind: "every", minutes: 60 });
    expect(rs.removeFor("sprout").length).toBe(1);
    expect(rs.all.map((r) => r.goal)).toEqual(["b"]);
  });
});
