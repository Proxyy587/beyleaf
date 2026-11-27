// Protocol v1, engines subset (ADR 0025). Additive within v1.
import { z } from "zod";

export const EngineId = z.enum(["claude", "codex", "cursor", "antigravity", "opencode"]);
export type EngineId = z.infer<typeof EngineId>;

/** `unknown` means Belay has no verified way to tell; it is never a guess. */
export const AuthState = z.enum(["signed-in", "signed-out", "unknown"]);
export type AuthState = z.infer<typeof AuthState>;

export const EngineStatus = z.object({
  id: EngineId,
  name: z.string(),
  installed: z.boolean(),
  path: z.string().nullable(),
  version: z.string().nullable(),
  auth: AuthState,
  /** How the CLI says it is signed in ("claude.ai"), and the plan if it says ("pro"). No emails, no org names. */
  method: z.string().nullable(),
  plan: z.string().nullable(),
  /** False when the status or login command has not been run on a real install. */
  verified: z.boolean(),
});
export type EngineStatus = z.infer<typeof EngineStatus>;

export const ConnectStep = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("ready") }),
  /** Shown to the user with a copy button. Belay never runs it. */
  z.object({ kind: z.literal("install"), command: z.string(), url: z.string() }),
  /** The vendor's own sign-in, to run in a visible Terminal window. */
  z.object({ kind: z.literal("signin"), command: z.string(), certain: z.boolean() }),
]);
export type ConnectStep = z.infer<typeof ConnectStep>;
