// Routines (docs/buddies.md §7): a goal on a schedule. A routine never runs anything itself: when its time comes it makes
// a task for its buddy, and that task waits for your OK to its plan like any other (ADR 0026). A Mac that was asleep through
// several runs makes one task, not a pile: missed runs are collapsed, never replayed.
import type { Routine, Schedule } from "@belay/protocol";
import { describe, nextRun } from "./schedule";
import type { Result } from "./registry";

export const MAX_ROUTINES = 20;

export class Routines {
  private list: Routine[] = [];
  /** When each routine was made: the point its first run counts from. */
  private born = new Map<string, Date>();
  private n = 0;
  constructor(private now: () => Date = () => new Date()) {}

  get all(): readonly Routine[] { return this.list; }
  get(id: string): Routine | undefined { return this.list.find((r) => r.id === id); }

  create(buddy: string, goal: string, schedule: Schedule): Result<Routine> {
    if (!goal.trim()) return { ok: false, why: "say what the routine is for" };
    if (this.list.length >= MAX_ROUTINES) return { ok: false, why: `that's ${MAX_ROUTINES} routines; remove one first` };
    if (schedule.kind === "every" && schedule.minutes < 5) return { ok: false, why: "a routine can run at most every 5 minutes" };
    if (schedule.kind === "once" && Date.parse(schedule.at) <= this.now().getTime()) return { ok: false, why: "that time has already passed" };
    const r: Routine = { id: `r${++this.n}`, buddy, goal: goal.trim(), schedule, paused: false, lastRunAt: null };
    this.list.push(r);
    this.born.set(r.id, this.now());
    return { ok: true, value: r };
  }

  remove(id: string): boolean {
    const had = this.list.some((r) => r.id === id);
    this.list = this.list.filter((r) => r.id !== id);
    this.born.delete(id);
    return had;
  }

  /** A removed buddy takes its routines with it. */
  removeFor(buddy: string): string[] {
    const gone = this.list.filter((r) => r.buddy === buddy).map((r) => r.id);
    gone.forEach((id) => this.remove(id));
    return gone;
  }

  setPaused(id: string, paused: boolean): boolean {
    const r = this.get(id);
    if (!r) return false;
    r.paused = paused;
    // Resuming doesn't owe the time spent paused: count from now.
    if (!paused) this.born.set(id, this.now());
    return true;
  }

  next(r: Routine): Date | null {
    if (r.paused) return null;
    const from = r.lastRunAt ? new Date(r.lastRunAt) : (this.born.get(r.id) ?? this.now());
    // Counting from the last run (or from when it was made) finds the first run after it: if that is already past, it is due.
    return nextRun(r.schedule, from, r.lastRunAt ? new Date(r.lastRunAt) : null);
  }

  words(r: Routine): string { return describe(r.schedule); }

  /** Routines whose time has come. Each is marked as run now, so however many runs were missed it is due once. */
  due(): Routine[] {
    const now = this.now();
    const out: Routine[] = [];
    for (const r of this.list) {
      const t = this.next(r);
      if (t && t.getTime() <= now.getTime()) { r.lastRunAt = now.toISOString(); out.push(r); }
    }
    // A one-off is done once it has run.
    for (const r of out) if (r.schedule.kind === "once") this.remove(r.id);
    return out;
  }

  /** "Run now": makes the routine's task without touching its schedule. */
  runNow(id: string): Routine | undefined { return this.get(id); }
}
