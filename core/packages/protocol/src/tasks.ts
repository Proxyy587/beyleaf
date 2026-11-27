// Protocol v1, tasks subset (docs/buddies.md §6a). A task is a goal a buddy works toward, in steps you approved.
import { z } from "zod";
import { BuddyId } from "./crew";

/**
 * What a step touches. `spend`, `send` and `trade` move money or speak for you: they ask every time, with no "Always".
 * `payment` is never done by a buddy at all: it hands the page to you.
 */
export const StepKind = z.enum(["observe", "browse", "mac", "code", "send", "spend", "payment", "trade"]);
export type StepKind = z.infer<typeof StepKind>;

export const TaskStatus = z.enum([
  "planning", // waiting for a plan
  "blocked", // can't proceed (no engine, trading off, ...): `note` says why
  "needs-plan-ok", // a plan is ready; nothing runs until you approve it
  "running",
  "needs-you", // a step needs your approval or your hands (payment)
  "paused",
  "done",
  "stopped", // you pressed stop, or a limit was reached
  "failed",
]);
export type TaskStatus = z.infer<typeof TaskStatus>;

export const Step = z.object({
  id: z.string(),
  label: z.string().min(1).max(120),
  kind: StepKind,
  status: z.enum(["todo", "doing", "done", "skipped", "failed"]),
  /** Money this step would move, in the task's currency (spend and trade). */
  amount: z.number().nonnegative().optional(),
});
export type Step = z.infer<typeof Step>;

/** Hard limits a task cannot raise on its own. */
export const Limits = z.object({
  maxSteps: z.number().int().min(1).max(200),
  maxMinutes: z.number().int().min(1).max(24 * 60),
  /** Most money the whole task may move. Required for any task that has a money step. */
  maxMoney: z.number().nonnegative().optional(),
  currency: z.string().max(4).optional(),
});
export type Limits = z.infer<typeof Limits>;

export const Task = z.object({
  id: z.string(),
  buddy: BuddyId,
  goal: z.string().min(1).max(500),
  status: TaskStatus,
  steps: z.array(Step),
  limits: Limits,
  moved: z.number().nonnegative(),
  startedAt: z.string().datetime().nullable(),
  note: z.string().max(200).optional(),
});
export type Task = z.infer<typeof Task>;

export const TaskRequest = z.discriminatedUnion("type", [
  z.object({ type: z.literal("task.create"), buddy: BuddyId, goal: z.string().min(1).max(500), limits: Limits.optional() }),
  z.object({ type: z.literal("task.approve"), id: z.string() }),
  z.object({ type: z.literal("task.deny"), id: z.string() }),
  z.object({ type: z.literal("task.stop"), id: z.string() }),
  z.object({ type: z.literal("task.pause"), id: z.string(), paused: z.boolean() }),
]);
export const TaskEvent = z.discriminatedUnion("type", [
  z.object({ type: z.literal("task.updated"), task: Task }),
  z.object({ type: z.literal("task.list"), tasks: z.array(Task) }),
]);
