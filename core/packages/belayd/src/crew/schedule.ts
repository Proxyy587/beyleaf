// Routine schedules: next run and missed runs. Pure; the clock is always passed in (docs/buddies.md §7).
import type { Schedule } from "@belay/protocol";

const MIN = 60_000;

function atTime(day: Date, hhmm: string): Date {
  const [h, m] = hhmm.split(":").map(Number);
  const d = new Date(day);
  d.setHours(h!, m!, 0, 0);
  return d;
}

/** The first run strictly after `after`, or null for event schedules and past one-off runs. */
export function nextRun(s: Schedule, after: Date, lastRunAt?: Date | null): Date | null {
  switch (s.kind) {
    case "event":
      return null;
    case "once": {
      const at = new Date(s.at);
      return at.getTime() > after.getTime() ? at : null;
    }
    case "every": {
      const base = lastRunAt ?? after;
      let t = base.getTime() + s.minutes * MIN;
      if (t <= after.getTime()) t = after.getTime() + s.minutes * MIN; // never schedule into the past
      return new Date(t);
    }
    case "daily": {
      for (let i = 0; i < 8; i++) {
        const day = new Date(after);
        day.setDate(day.getDate() + i); // setDate keeps local wall-clock time across DST changes
        const t = atTime(day, s.time);
        if (t.getTime() <= after.getTime()) continue;
        if (s.days.length === 0 || s.days.includes(t.getDay())) return t;
      }
      return null;
    }
  }
}

/** Runs that were due in (since, now] and didn't happen (the Mac was asleep or off). Newest last, at most `cap`.
 *  Missed runs are shown to the user, never replayed silently. `every` collapses to at most one. */
export function missedRuns(s: Schedule, since: Date, now: Date, cap = 5): Date[] {
  if (s.kind === "event") return [];
  if (s.kind === "once") {
    const at = new Date(s.at);
    return at.getTime() > since.getTime() && at.getTime() <= now.getTime() ? [at] : [];
  }
  if (s.kind === "every") {
    return since.getTime() + s.minutes * MIN <= now.getTime() ? [new Date(now.getTime())] : [];
  }
  const out: Date[] = [];
  let cursor = since;
  for (let i = 0; i < 400 && out.length < 400; i++) {
    const n = nextRun(s, cursor);
    if (!n || n.getTime() > now.getTime()) break;
    out.push(n);
    cursor = n;
  }
  return out.slice(-cap);
}

const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

/** The words the UI shows for a schedule, lowercase and short (design.md §10). */
export function describe(s: Schedule): string {
  switch (s.kind) {
    case "event":
      return `when ${s.name.replace(".", " ")}`;
    case "once":
      return "once";
    case "every":
      return s.minutes % 60 === 0 ? (s.minutes === 60 ? "every hour" : `every ${s.minutes / 60} hours`) : `every ${s.minutes} min`;
    case "daily": {
      const d = [...new Set(s.days)].sort();
      const days =
        d.length === 0 || d.length === 7 ? "daily" : d.join() === "1,2,3,4,5" ? "weekdays" : d.join() === "0,6" ? "weekends" : d.map((x) => DAYS[x]).join(" ");
      return `${days} ${s.time}`;
    }
  }
}
