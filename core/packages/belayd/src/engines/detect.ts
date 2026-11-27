// Find the user's CLIs and ask each one, through its own status command, whether it is signed in (ADR 0025).
// Belay never opens a credential file. Every side effect is injected so the logic is testable without a Mac.
import type { EngineStatus } from "@belay/protocol";
import { ENGINES, type EngineDef, type ExecResult } from "./catalog";

export interface Deps {
  /** Runs a command with a deadline. null: it could not start or timed out. */
  exec(cmd: string[], opts: { timeoutMs: number; env?: Record<string, string | undefined> }): Promise<ExecResult | null>;
  isExecutable(path: string): boolean;
  env: Record<string, string | undefined>;
  home: string;
}

/** A Mac app starts with a short PATH, so the usual install places are searched too. */
export function searchDirs(env: Record<string, string | undefined>, home: string): string[] {
  const fromPath = (env.PATH ?? "").split(":").filter(Boolean);
  const extra = [`${home}/.local/bin`, `${home}/.bun/bin`, `${home}/.npm-global/bin`, "/opt/homebrew/bin", "/usr/local/bin"];
  return [...new Set([...fromPath, ...extra])];
}

export function findBinary(names: string[], deps: Pick<Deps, "isExecutable" | "env" | "home">): string | null {
  for (const dir of searchDirs(deps.env, deps.home)) {
    for (const n of names) {
      const p = `${dir}/${n}`;
      if (deps.isExecutable(p)) return p;
    }
  }
  return null;
}

/** API keys that would make a CLI bill the user instead of using their plan. Removed in subscription mode (ADR 0025). */
export const BILLING_KEYS = [
  "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "OPENAI_API_KEY", "CODEX_API_KEY", "CURSOR_API_KEY",
  "GEMINI_API_KEY", "GOOGLE_API_KEY", "OPENROUTER_API_KEY", "XAI_API_KEY", "GROK_API_KEY",
];

export function subscriptionEnv(env: Record<string, string | undefined>): Record<string, string | undefined> {
  const out = { ...env };
  for (const k of BILLING_KEYS) delete out[k];
  return out;
}

const firstLine = (s: string) => s.split("\n")[0]!.trim().slice(0, 80) || null;

export async function detectEngine(def: EngineDef, deps: Deps, timeoutMs = 4000): Promise<EngineStatus> {
  const base = { id: def.id, name: def.name, verified: def.verified, method: null, plan: null } as const;
  const path = findBinary(def.bins, deps);
  if (!path) return { ...base, installed: false, path: null, version: null, auth: "unknown" };
  // A GUI app starts with a short PATH and some CLIs are scripts (`#!/usr/bin/env node`): put the binary's own folder first.
  const env = { ...subscriptionEnv(deps.env), PATH: [path.slice(0, path.lastIndexOf("/")), ...searchDirs(deps.env, deps.home)].join(":") };
  const [ver, status] = await Promise.all([
    deps.exec([path, "--version"], { timeoutMs, env }),
    def.status ? deps.exec([path, ...def.status.args], { timeoutMs, env }) : Promise.resolve(null),
  ]);
  let parsed = def.status && status ? def.status.parse(status) : { auth: "unknown" as const };
  // Vendors keep logins in the macOS Keychain, which needs the user's session variables. Without them "signed out" can be a
  // false negative (seen with Claude Code when USER was missing), so say "can't tell" instead of accusing the user.
  if (parsed.auth === "signed-out" && !deps.env.USER && !deps.env.LOGNAME) parsed = { auth: "unknown" };
  return {
    ...base, installed: true, path,
    version: ver && ver.code === 0 ? firstLine(ver.stdout) : null,
    auth: parsed.auth, method: parsed.method ?? null, plan: parsed.plan ?? null,
  };
}

export const detectAll = (deps: Deps) => Promise.all(ENGINES.map((d) => detectEngine(d, deps)));

export function realDeps(): Deps {
  const { accessSync, constants, statSync } = require("node:fs") as typeof import("node:fs");
  return {
    env: process.env,
    home: process.env.HOME ?? "",
    isExecutable(p) {
      try { accessSync(p, constants.X_OK); return statSync(p).isFile(); } catch { return false; }
    },
    async exec(cmd, { timeoutMs, env }) {
      try {
        const proc = Bun.spawn(cmd, { stdout: "pipe", stderr: "pipe", stdin: "ignore", env: env as Record<string, string> });
        let timedOut = false;
        const timer = setTimeout(() => { timedOut = true; proc.kill(); }, timeoutMs);
        const [stdout, stderr] = await Promise.all([new Response(proc.stdout).text(), new Response(proc.stderr).text()]);
        const code = await proc.exited;
        clearTimeout(timer);
        return timedOut ? null : { code, stdout, stderr };
      } catch {
        return null;
      }
    },
  };
}
