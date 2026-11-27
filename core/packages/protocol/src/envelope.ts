// Protocol v1 envelope (docs/architecture.md §4): one JSON object per line over a 0600 Unix socket.
import { z } from "zod";
import { BuddyState, Buddy, BuddyId, CrewRequest, CrewEvent } from "./crew";
import { ConnectStep, EngineId, EngineStatus } from "./engines";
import { Task, TaskEvent, TaskRequest } from "./tasks";

export const Envelope = z.object({ v: z.literal(1), id: z.string().max(64), type: z.string().max(64), data: z.unknown().optional() });
export type Envelope = z.infer<typeof Envelope>;

/** Shell to core. */
export const ShellRequest = z.discriminatedUnion("type", [
  z.object({ type: z.literal("ping") }),
  z.object({ type: z.literal("engines.list") }),
  z.object({ type: z.literal("engines.signin"), id: EngineId }),
  z.object({ type: z.literal("engines.cancel"), id: EngineId }),
  ...CrewRequest.options,
  ...TaskRequest.options,
]);

export const EngineRow = z.object({ status: EngineStatus, step: ConnectStep });
export type EngineRow = z.infer<typeof EngineRow>;

/** Core to shell. */
export const CoreReply = z.discriminatedUnion("type", [
  z.object({ type: z.literal("pong") }),
  z.object({ type: z.literal("engines.list.result"), engines: z.array(EngineRow) }),
  z.object({ type: z.literal("engines.signin.result"), row: EngineRow, watching: z.boolean() }),
  z.object({ type: z.literal("engines.updated"), engines: z.array(EngineRow) }),
  z.object({ type: z.literal("crew.roster"), buddies: z.array(Buddy), states: z.record(BuddyId, BuddyState), notes: z.array(z.object({ key: z.string(), by: z.string(), text: z.string() })) }),
  ...CrewEvent.options.filter((o) => o.shape.type.value !== "crew.roster"),
  ...TaskEvent.options,
  z.object({ type: z.literal("error"), message: z.string() }),
]);
