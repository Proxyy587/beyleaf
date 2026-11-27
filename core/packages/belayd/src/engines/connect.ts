// What the user has to do to connect an engine, and waiting for it (ADR 0025). Belay shows the install command and
// never runs it; sign-in is the vendor's own command in a Terminal window the user can see.
import type { AuthState, ConnectStep, EngineStatus } from "@belay/protocol";
import { ENGINES } from "./catalog";

/** Safe to paste into a shell: single quotes, with embedded quotes closed and reopened. */
export const shQuote = (s: string) => (/^[\w@%+=:,./-]+$/.test(s) ? s : `'${s.replace(/'/g, `'\\''`)}'`);

export function connectPlan(s: EngineStatus): ConnectStep {
  const def = ENGINES.find((e) => e.id === s.id)!;
  if (!s.installed || !s.path) return { kind: "install", command: def.install.command, url: def.install.url };
  if (s.auth === "signed-in") return { kind: "ready" };
  return { kind: "signin", command: [s.path, ...def.login].map(shQuote).join(" "), certain: s.auth === "signed-out" };
}

export interface WatchOptions {
  intervalMs?: number;
  timeoutMs?: number;
  sleep?: (ms: number) => Promise<void>;
  now?: () => number;
  signal?: AbortSignal;
}

/** Re-reads status until the engine is signed in, the deadline passes, or the user cancels. */
export async function watchSignIn(
  read: () => Promise<AuthState>,
  { intervalMs = 2000, timeoutMs = 5 * 60_000, sleep = (ms) => new Promise((r) => setTimeout(r, ms)), now = Date.now, signal }: WatchOptions = {},
): Promise<"signed-in" | "timeout" | "cancelled"> {
  const end = now() + timeoutMs;
  while (now() < end) {
    if (signal?.aborted) return "cancelled";
    if ((await read()) === "signed-in") return "signed-in";
    await sleep(intervalMs);
  }
  return signal?.aborted ? "cancelled" : "timeout";
}
