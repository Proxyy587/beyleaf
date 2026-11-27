import { expect, test } from "bun:test";
import { Buddy, CrewEvent, Routine, Schedule } from "@belay/protocol";

test("a buddy, routine and event round-trip the schemas", () => {
  const b = Buddy.parse({ id: "pip", name: "pip", sprite: "pip", job: "errands on your Mac", engine: "rules", tiers: ["errands"], autonomy: "ask" });
  expect(b.tiers).toEqual(["errands"]);
  expect(Routine.safeParse({ id: "r1", buddy: "otto", goal: "summarise my inbox", schedule: { kind: "daily", time: "08:30", days: [1, 2, 3, 4, 5] }, paused: false, lastRunAt: null }).success).toBe(true);
  expect(CrewEvent.safeParse({ type: "crew.roster", buddies: [b], states: { pip: "idle" } }).success).toBe(true);
});

test("bad input is refused", () => {
  expect(Schedule.safeParse({ kind: "daily", time: "25:00", days: [] }).success).toBe(false);
  expect(Schedule.safeParse({ kind: "every", minutes: 0 }).success).toBe(false);
  expect(Buddy.safeParse({ id: "Pip!", name: "x", sprite: "pip", job: "", engine: "rules", tiers: [], autonomy: "ask" }).success).toBe(false);
  expect(Buddy.safeParse({ id: "pip", name: "x", sprite: "pip", job: "", engine: "rules", tiers: ["root"], autonomy: "ask" }).success).toBe(false);
});
