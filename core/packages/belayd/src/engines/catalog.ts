// The engines Belay can drive: the user's own CLIs (ADR 0004, 0025). One entry per engine.
import type { AuthState, EngineId } from "@belay/protocol";

export type ExecResult = { code: number; stdout: string; stderr: string };
export type Parsed = { auth: AuthState; method?: string; plan?: string };

export interface EngineDef {
  id: EngineId;
  name: string;
  bins: string[];
  /** Arguments of the CLI's own status command. Absent: Belay can't tell, and says `unknown`. */
  status?: { args: string[]; parse(r: ExecResult): Parsed };
  /** Arguments of the CLI's own sign-in command, run by the user in Terminal. */
  login: string[];
  install: { command: string; url: string };
  /** True once the status and login commands were run on a real install. */
  verified: boolean;
}

const unknown: Parsed = { auth: "unknown" };

/** `claude auth status --json` (verified on Claude Code 2.1.311). Only the sign-in method and plan are kept. */
export function parseClaude(r: ExecResult): Parsed {
  try {
    const d = JSON.parse(r.stdout);
    if (typeof d?.loggedIn !== "boolean") return unknown;
    if (!d.loggedIn) return { auth: "signed-out" };
    return {
      auth: "signed-in",
      method: typeof d.authMethod === "string" ? d.authMethod : undefined,
      plan: typeof d.subscriptionType === "string" ? d.subscriptionType : undefined,
    };
  } catch {
    return unknown;
  }
}

/** `codex login status`: UNVERIFIED (Codex isn't installed on the dev Mac). Anything unexpected is `unknown`. */
export function parseCodex(r: ExecResult): Parsed {
  const text = `${r.stdout}\n${r.stderr}`;
  if (/not logged in|logged out/i.test(text)) return { auth: "signed-out" };
  if (r.code === 0 && /logged in/i.test(text)) {
    const m = text.match(/using\s+(chatgpt|an api key|api key)/i);
    return { auth: "signed-in", method: m ? m[1]!.toLowerCase().replace("an ", "") : undefined };
  }
  return unknown;
}

export const ENGINES: EngineDef[] = [
  {
    id: "claude", name: "Claude Code", bins: ["claude"],
    status: { args: ["auth", "status", "--json"], parse: parseClaude },
    login: ["auth", "login"],
    install: { command: "npm install -g @anthropic-ai/claude-code", url: "https://code.claude.com/docs" },
    verified: true,
  },
  {
    id: "codex", name: "Codex", bins: ["codex"],
    status: { args: ["login", "status"], parse: parseCodex },
    login: ["login"],
    install: { command: "npm install -g @openai/codex", url: "https://developers.openai.com/codex" },
    verified: false,
  },
  {
    id: "cursor", name: "Cursor", bins: ["cursor-agent"],
    login: ["login"],
    install: { command: "curl https://cursor.com/install -fsS | bash", url: "https://cursor.com/cli" },
    verified: false,
  },
  {
    id: "antigravity", name: "Antigravity", bins: ["agy"],
    login: ["login"],
    install: { command: "See the Antigravity CLI page", url: "https://antigravity.google" },
    verified: false,
  },
  {
    id: "opencode", name: "OpenCode", bins: ["opencode"],
    login: ["auth", "login"],
    install: { command: "npm install -g opencode-ai", url: "https://opencode.ai" },
    verified: false,
  },
];
