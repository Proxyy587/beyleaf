import { describe, expect, test } from "bun:test";
import type { EngineStatus } from "@belay/protocol";
import { ENGINES, parseClaude, parseCodex } from "./catalog";
import { BILLING_KEYS, detectEngine, findBinary, realDeps, searchDirs, subscriptionEnv, type Deps } from "./detect";
import { connectPlan, shQuote, watchSignIn } from "./connect";

const claude = ENGINES.find((e) => e.id === "claude")!;
const r = (stdout: string, code = 0, stderr = "") => ({ code, stdout, stderr });

describe("status parsers", () => {
  test("claude: signed in keeps only method and plan, never the email or org", () => {
    const p = parseClaude(r(JSON.stringify({ loggedIn: true, authMethod: "claude.ai", subscriptionType: "pro", email: "a@b.c", orgName: "Org" })));
    expect(p).toEqual({ auth: "signed-in", method: "claude.ai", plan: "pro" });
    expect(JSON.stringify(p)).not.toContain("a@b.c");
  });
  test("claude: signed out, and anything odd is unknown", () => {
    expect(parseClaude(r(JSON.stringify({ loggedIn: false }))).auth).toBe("signed-out");
    expect(parseClaude(r("not json")).auth).toBe("unknown");
    expect(parseClaude(r(JSON.stringify({ hello: 1 }))).auth).toBe("unknown");
  });
  test("codex: logged in, not logged in, and the surprise case", () => {
    expect(parseCodex(r("Logged in using ChatGPT")).auth).toBe("signed-in");
    expect(parseCodex(r("Logged in using ChatGPT")).method).toBe("chatgpt");
    expect(parseCodex(r("Not logged in", 1)).auth).toBe("signed-out");
    expect(parseCodex(r("", 2, "boom")).auth).toBe("unknown");
  });
});

const deps = (over: Partial<Deps> = {}): Deps => ({
  env: { PATH: "/usr/bin:/bin", ANTHROPIC_API_KEY: "sk-x", HOME: "/Users/u" },
  home: "/Users/u",
  isExecutable: (p) => p === "/opt/homebrew/bin/claude",
  exec: async () => null,
  ...over,
});

describe("finding and detecting", () => {
  test("a Mac app's short PATH still finds Homebrew and user installs", () => {
    expect(searchDirs({ PATH: "/usr/bin" }, "/Users/u")).toContain("/opt/homebrew/bin");
    expect(findBinary(["claude"], deps())).toBe("/opt/homebrew/bin/claude");
    expect(findBinary(["codex"], deps())).toBeNull();
  });
  test("a missing CLI is reported as not installed with no auth guess", async () => {
    const s = await detectEngine(ENGINES.find((e) => e.id === "codex")!, deps());
    expect(s).toMatchObject({ installed: false, path: null, auth: "unknown" });
  });
  test("an installed CLI is asked its own status; the child never sees API keys", async () => {
    const seen: Array<Record<string, string | undefined> | undefined> = [];
    const s = await detectEngine(claude, deps({
      exec: async (cmd, o) => {
        seen.push(o.env);
        return cmd.includes("--version") ? r("2.1.311 (Claude Code)\n") : r(JSON.stringify({ loggedIn: true, authMethod: "claude.ai", subscriptionType: "pro" }));
      },
    }));
    expect(s).toMatchObject({ installed: true, version: "2.1.311 (Claude Code)", auth: "signed-in", method: "claude.ai", plan: "pro", verified: true });
    expect(seen.every((e) => e && !("ANTHROPIC_API_KEY" in e) && e.PATH)).toBe(true);
  });
  test("a CLI that hangs is unknown, not signed out", async () => {
    const s = await detectEngine(claude, deps());
    expect(s).toMatchObject({ installed: true, auth: "unknown", version: null });
  });
  test("an engine with no verified status command is unknown", async () => {
    const cursor = ENGINES.find((e) => e.id === "cursor")!;
    const s = await detectEngine(cursor, deps({ isExecutable: (p) => p.endsWith("/cursor-agent"), exec: async () => r("1.0\n") }));
    expect(s).toMatchObject({ installed: true, auth: "unknown", verified: false });
  });
  test("subscription mode removes every billing key and nothing else", () => {
    const env = Object.fromEntries([...BILLING_KEYS.map((k) => [k, "x"]), ["PATH", "/bin"], ["HOME", "/h"]]);
    expect(subscriptionEnv(env)).toEqual({ PATH: "/bin", HOME: "/h" });
  });
});

const status = (over: Partial<EngineStatus>): EngineStatus => ({
  id: "claude", name: "Claude Code", installed: true, path: "/opt/homebrew/bin/claude", version: "2", auth: "signed-out", method: null, plan: null, verified: true, ...over,
});

describe("connect plan", () => {
  test("missing: show the install command, don't run it", () => {
    expect(connectPlan(status({ installed: false, path: null }))).toEqual({ kind: "install", command: "npm install -g @anthropic-ai/claude-code", url: "https://code.claude.com/docs" });
  });
  test("signed in: ready; signed out: the vendor's login; unknown: login, marked uncertain", () => {
    expect(connectPlan(status({ auth: "signed-in" }))).toEqual({ kind: "ready" });
    expect(connectPlan(status({ auth: "signed-out" }))).toEqual({ kind: "signin", command: "/opt/homebrew/bin/claude auth login", certain: true });
    expect(connectPlan(status({ auth: "unknown" }))).toMatchObject({ kind: "signin", certain: false });
  });
  test("a path with spaces or quotes is quoted so the command can't be split or injected", () => {
    expect(shQuote("/Users/a b/claude")).toBe("'/Users/a b/claude'");
    expect(shQuote("/x/it's")).toBe(`'/x/it'\\''s'`);
    expect(shQuote("/x/$(rm -rf ~)")).toBe("'/x/$(rm -rf ~)'");
    expect(connectPlan(status({ path: "/Users/a b/claude" }))).toMatchObject({ command: "'/Users/a b/claude' auth login" });
  });
});

describe("watchSignIn", () => {
  const clock = () => { let t = 0; return { now: () => t, sleep: async (ms: number) => { t += ms; } }; };
  test("returns as soon as the CLI says signed in", async () => {
    let n = 0;
    expect(await watchSignIn(async () => (++n >= 3 ? "signed-in" : "signed-out"), clock())).toBe("signed-in");
    expect(n).toBe(3);
  });
  test("gives up at the deadline", async () => {
    expect(await watchSignIn(async () => "signed-out", { ...clock(), timeoutMs: 10_000, intervalMs: 2000 })).toBe("timeout");
  });
  test("the user can cancel", async () => {
    const ac = new AbortController();
    let n = 0;
    const out = await watchSignIn(async () => { if (++n === 2) ac.abort(); return "signed-out"; }, { ...clock(), signal: ac.signal });
    expect(out).toBe("cancelled");
  });
});

describe("real process execution", () => {
  const real = realDeps();
  test("a finished command returns its output and exit code", async () => {
    expect(await real.exec(["/bin/echo", "hi"], { timeoutMs: 3000 })).toEqual({ code: 0, stdout: "hi\n", stderr: "" });
    expect((await real.exec(["/usr/bin/false"], { timeoutMs: 3000 }))?.code).toBe(1);
  });
  test("a command that hangs is killed at the deadline and reported as null", async () => {
    const t = Date.now();
    expect(await real.exec(["/bin/sleep", "5"], { timeoutMs: 300 })).toBeNull();
    expect(Date.now() - t).toBeLessThan(2000);
  });
  test("a command that can't start is null, not a crash", async () => {
    expect(await real.exec(["/nonexistent/x"], { timeoutMs: 1000 })).toBeNull();
  });
});
