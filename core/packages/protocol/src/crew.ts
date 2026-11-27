// Protocol v1, crew subset (docs/buddies.md, docs/crew.md §10). Additive within v1.
import { z } from "zod";

export const BuddyId = z.string().regex(/^[a-z][a-z0-9-]{1,23}$/);

/** How much a buddy may reach on the Mac (docs/buddies.md §6). */
export const Tier = z.enum(["observe", "errands", "hands", "sandbox"]);

/** How much a buddy may do without asking. Outward and write-outside actions always ask, at every level (ADR 0005, 0011). */
export const Autonomy = z.enum(["ask", "edits", "routine"]);

export const Buddy = z.object({
  id: BuddyId,
  name: z.string().min(1).max(24),
  sprite: z.string(), // key in brand/buddies/buddies.json
  job: z.string().max(80),
  engine: z.enum(["claude-cli", "codex-cli", "local-model", "api-key", "rules", "fake"]),
  tiers: z.array(Tier),
  autonomy: Autonomy,
  /** Who made this buddy: you, or another buddy (docs/buddies.md §2a). Buddies are never made on their own. */
  createdBy: z.union([z.literal("you"), BuddyId]).default("you"),
});
export type Buddy = z.infer<typeof Buddy>;

/** What a new buddy is made from. The rest (tiers, autonomy, engine) starts at the safest the maker allows. */
export const BuddySpec = z.object({
  name: z.string().min(1).max(24),
  sprite: z.string(),
  job: z.string().max(80),
  tiers: z.array(Tier).optional(),
  autonomy: Autonomy.optional(),
});
export type BuddySpec = z.infer<typeof BuddySpec>;

export const BuddyState = z.enum(["idle", "working", "waiting", "done", "error", "paused"]);

export const Schedule = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("every"), minutes: z.number().int().min(1).max(7 * 24 * 60) }),
  /** `time` is local "HH:MM"; `days` are 0 (Sunday) to 6. Empty days means every day. */
  z.object({ kind: z.literal("daily"), time: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/), days: z.array(z.number().int().min(0).max(6)).max(7) }),
  z.object({ kind: z.literal("once"), at: z.string().datetime() }),
  /** Fired by an event: session.done, battery.low, calendar.soon, file.added. */
  z.object({ kind: z.literal("event"), name: z.enum(["session.done", "battery.low", "calendar.soon", "file.added"]) }),
]);
export type Schedule = z.infer<typeof Schedule>;

export const Routine = z.object({
  id: z.string(),
  buddy: BuddyId,
  goal: z.string().min(1).max(500),
  schedule: Schedule,
  paused: z.boolean(),
  lastRunAt: z.string().datetime().nullable(),
});
export type Routine = z.infer<typeof Routine>;

export const Message = z.object({
  id: z.string(),
  thread: z.string(), // "dm:<buddy>" or "group:<id>"
  from: z.union([z.literal("you"), BuddyId]),
  text: z.string().max(20000),
  at: z.string().datetime(),
  /** Tool steps shown as status rows (docs/buddies.md §5). */
  steps: z.array(z.object({ label: z.string().max(60), ms: z.number().int().nonnegative().optional() })).default([]),
  /** From untrusted content (mail, web). Never grants permission (ADR 0011). */
  tainted: z.boolean().default(false),
});
export type Message = z.infer<typeof Message>;

/** Shell to core. */
export const CrewRequest = z.discriminatedUnion("type", [
  z.object({ type: z.literal("crew.say"), text: z.string().min(1).max(20000), thread: z.string().optional() }),
  z.object({ type: z.literal("crew.routine.pause"), id: z.string(), paused: z.boolean() }),
  z.object({ type: z.literal("crew.routine.runNow"), id: z.string() }),
  z.object({ type: z.literal("crew.list") }),
  /** `by` is "you" from the shell. A buddy's own request arrives through the Belay MCP server and is shown to you. */
  z.object({ type: z.literal("crew.buddy.create"), by: z.union([z.literal("you"), BuddyId]).default("you"), spec: BuddySpec }),
  z.object({ type: z.literal("crew.buddy.remove"), by: z.union([z.literal("you"), BuddyId]).default("you"), id: BuddyId }),
  /** A message between buddies (or you to a buddy). Recorded in the pair's thread; buddies see each other's. */
  z.object({ type: z.literal("crew.tell"), from: z.union([z.literal("you"), BuddyId]), to: BuddyId, text: z.string().min(1).max(4000) }),
  /** Put a note in the shared notebook every buddy can read. */
  z.object({ type: z.literal("crew.share"), by: z.union([z.literal("you"), BuddyId]), key: z.string().min(1).max(40), text: z.string().max(4000) }),
]);

/** Core to shell. */
export const CrewEvent = z.discriminatedUnion("type", [
  z.object({ type: z.literal("crew.roster"), buddies: z.array(Buddy), states: z.record(BuddyId, BuddyState) }),
  z.object({ type: z.literal("crew.message"), message: Message }),
  z.object({ type: z.literal("crew.created"), buddy: Buddy, by: z.union([z.literal("you"), BuddyId]) }),
  z.object({ type: z.literal("crew.removed"), id: BuddyId, by: z.union([z.literal("you"), BuddyId]) }),
  z.object({ type: z.literal("crew.refused"), why: z.string() }),
  z.object({ type: z.literal("crew.routines"), routines: z.array(Routine), nextRun: z.record(z.string(), z.string().datetime().nullable()) }),
]);
