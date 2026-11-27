import { beforeAll, describe, expect, test } from "bun:test";
import type { Schedule } from "@belay/protocol";
import { describe as words, missedRuns, nextRun } from "./schedule";
import { route } from "./router";

beforeAll(() => {
  process.env.TZ = "UTC";
});
const at = (s: string) => new Date(s);
const weekdays: Schedule = { kind: "daily", time: "08:30", days: [1, 2, 3, 4, 5] };

describe("nextRun", () => {
  test("daily: later today, else next matching day", () => {
    expect(nextRun(weekdays, at("2026-11-27T07:00:00Z"))?.toISOString()).toBe("2026-11-27T08:30:00.000Z"); // Fri
    expect(nextRun(weekdays, at("2026-11-27T09:00:00Z"))?.toISOString()).toBe("2026-11-30T08:30:00.000Z"); // skips the weekend
  });
  test("daily: the exact time is not 'after'", () => {
    expect(nextRun(weekdays, at("2026-11-27T08:30:00Z"))?.toISOString()).toBe("2026-11-30T08:30:00.000Z");
  });
  test("daily: empty days means every day", () => {
    expect(nextRun({ kind: "daily", time: "06:00", days: [] }, at("2026-11-27T07:00:00Z"))?.toISOString()).toBe("2026-11-28T06:00:00.000Z");
  });
  test("every: counts from the last run, never into the past", () => {
    const s: Schedule = { kind: "every", minutes: 120 };
    expect(nextRun(s, at("2026-11-27T10:00:00Z"), at("2026-11-27T09:00:00Z"))?.toISOString()).toBe("2026-11-27T11:00:00.000Z");
    expect(nextRun(s, at("2026-11-27T20:00:00Z"), at("2026-11-27T09:00:00Z"))?.toISOString()).toBe("2026-11-27T22:00:00.000Z");
  });
  test("once and event", () => {
    expect(nextRun({ kind: "once", at: "2026-12-01T10:00:00Z" }, at("2026-11-27T00:00:00Z"))?.toISOString()).toBe("2026-12-01T10:00:00.000Z");
    expect(nextRun({ kind: "once", at: "2026-11-01T10:00:00Z" }, at("2026-11-27T00:00:00Z"))).toBeNull();
    expect(nextRun({ kind: "event", name: "session.done" }, at("2026-11-27T00:00:00Z"))).toBeNull();
  });
});

describe("missedRuns", () => {
  test("lists runs due while asleep, newest last, capped", () => {
    const m = missedRuns(weekdays, at("2026-11-23T09:00:00Z"), at("2026-11-27T09:00:00Z"));
    expect(m.map((d) => d.toISOString().slice(0, 10))).toEqual(["2026-11-24", "2026-11-25", "2026-11-26", "2026-11-27"]);
    expect(missedRuns(weekdays, at("2026-10-01T00:00:00Z"), at("2026-11-27T09:00:00Z"), 2)).toHaveLength(2);
  });
  test("nothing missed when nothing was due; interval collapses to one", () => {
    expect(missedRuns(weekdays, at("2026-11-27T08:31:00Z"), at("2026-11-27T12:00:00Z"))).toEqual([]);
    expect(missedRuns({ kind: "every", minutes: 30 }, at("2026-11-27T00:00:00Z"), at("2026-11-27T12:00:00Z"))).toHaveLength(1);
    expect(missedRuns({ kind: "event", name: "battery.low" }, at("2026-11-01T00:00:00Z"), at("2026-11-27T12:00:00Z"))).toEqual([]);
  });
});

describe("describe", () => {
  test("short lowercase words", () => {
    expect(words(weekdays)).toBe("weekdays 08:30");
    expect(words({ kind: "daily", time: "09:00", days: [] })).toBe("daily 09:00");
    expect(words({ kind: "daily", time: "10:00", days: [6, 0] })).toBe("weekends 10:00");
    expect(words({ kind: "daily", time: "10:00", days: [1, 3] })).toBe("Mon Wed 10:00");
    expect(words({ kind: "every", minutes: 60 })).toBe("every hour");
    expect(words({ kind: "every", minutes: 120 })).toBe("every 2 hours");
    expect(words({ kind: "every", minutes: 45 })).toBe("every 45 min");
    expect(words({ kind: "event", name: "session.done" })).toBe("when session done");
  });
});

describe("route", () => {
  const roster = { beepo: "beepo", sprout: "sprout", pip: "pip", willo: "willo" };
  test("name lead-in", () => {
    expect(route("willo, find the Bun docs", roster, "beepo")).toEqual({ to: ["willo"], text: "find the Bun docs", explicit: true });
    expect(route("Hey Pip: open Notes", roster, "beepo")).toEqual({ to: ["pip"], text: "open Notes", explicit: true });
  });
  test("mentions, several", () => {
    const r = route("@sprout @pip fix the test and open the PR", roster, "beepo");
    expect(r.to).toEqual(["sprout", "pip"]);
    expect(r.text).toBe("fix the test and open the PR");
  });
  test("no name goes to the coordinator; a name inside a sentence does not route", () => {
    expect(route("what time is it", roster, "beepo")).toEqual({ to: ["beepo"], text: "what time is it", explicit: false });
    expect(route("tell me about the pip package", roster, "beepo").to).toEqual(["beepo"]);
    expect(route("pipeline status", roster, "beepo").to).toEqual(["beepo"]);
  });
  test("empty roster", () => {
    expect(route("hello", {}, "beepo").to).toEqual(["beepo"]);
  });
});
