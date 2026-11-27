// Protocol v1 envelope (docs/architecture.md §4): one JSON object per line over a 0600 Unix socket.
import { z } from "zod";
import { ConnectStep, EngineId, EngineStatus } from "./engines";

export const Envelope = z.object({ v: z.literal(1), id: z.string().max(64), type: z.string().max(64), data: z.unknown().optional() });
export type Envelope = z.infer<typeof Envelope>;

/** Shell to core. */
export const ShellRequest = z.discriminatedUnion("type", [
  z.object({ type: z.literal("ping") }),
  z.object({ type: z.literal("engines.list") }),
  z.object({ type: z.literal("engines.signin"), id: EngineId }),
  z.object({ type: z.literal("engines.cancel"), id: EngineId }),
]);

export const EngineRow = z.object({ status: EngineStatus, step: ConnectStep });
export type EngineRow = z.infer<typeof EngineRow>;

/** Core to shell. */
export const CoreReply = z.discriminatedUnion("type", [
  z.object({ type: z.literal("pong") }),
  z.object({ type: z.literal("engines.list.result"), engines: z.array(EngineRow) }),
  z.object({ type: z.literal("engines.signin.result"), row: EngineRow, watching: z.boolean() }),
  z.object({ type: z.literal("engines.updated"), engines: z.array(EngineRow) }),
  z.object({ type: z.literal("error"), message: z.string() }),
]);
