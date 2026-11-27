import { afterAll, beforeAll, expect, test } from "bun:test";
import { statSync, writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Deps } from "./engines/detect";
import { startServer } from "./server";

const dir = mkdtempSync(join(tmpdir(), "belayd-"));
const sock = join(dir, "run", "b.sock");
let signedIn = false;
const deps: Deps = {
  env: { PATH: "/bin" }, home: "/h",
  isExecutable: (p) => p === "/bin/claude",
  exec: async (cmd) => cmd.includes("--version") ? { code: 0, stdout: "9.9\n", stderr: "" }
    : { code: 0, stdout: JSON.stringify({ loggedIn: signedIn, authMethod: "claude.ai", subscriptionType: "pro" }), stderr: "" },
};
let server: ReturnType<typeof startServer>;
beforeAll(() => { server = startServer({ socketPath: sock, deps, watch: { intervalMs: 20, timeoutMs: 3000 } }); });
afterAll(() => server.stop());

/** A tiny client: send one request, collect lines until `until` matches. */
async function ask(type: string, data: object = {}, until: (m: any) => boolean = () => true): Promise<any[]> {
  return new Promise((resolve, reject) => {
    const got: any[] = [];
    let buf = "";
    const timer = setTimeout(() => reject(new Error("timeout " + type)), 4000);
    Bun.connect({
      unix: sock,
      socket: {
        open(s) { s.write(JSON.stringify({ v: 1, id: "1", type, data }) + "\n"); },
        data(s, c) {
          buf += c.toString();
          let nl;
          while ((nl = buf.indexOf("\n")) >= 0) {
            const m = JSON.parse(buf.slice(0, nl)); buf = buf.slice(nl + 1); got.push(m);
            if (until(m)) { clearTimeout(timer); s.end(); resolve(got); }
          }
        },
      },
    });
  });
}

test("the socket is private: mode 0600, in a 0700 folder", () => {
  expect(statSync(sock).mode & 0o777).toBe(0o600);
  expect(statSync(join(dir, "run")).mode & 0o777).toBe(0o700);
});

test("ping answers pong; garbage and unknown requests get an error, not a crash", async () => {
  expect((await ask("ping"))[0].type).toBe("pong");
  expect((await ask("nope"))[0].type).toBe("error");
  expect((await ask("engines.signin", { id: "bogus" }))[0].type).toBe("error");
});

test("engines.list reports each engine with its status and next step", async () => {
  const [m] = await ask("engines.list");
  expect(m.type).toBe("engines.list.result");
  const claude = m.data.engines.find((e: any) => e.status.id === "claude");
  expect(claude.status).toMatchObject({ installed: true, version: "9.9", auth: "signed-out" });
  expect(claude.step.kind).toBe("signin");
  expect(m.data.engines.find((e: any) => e.status.id === "codex").step.kind).toBe("install");
});

test("signin returns the command, then pushes engines.updated once the CLI says signed in", async () => {
  signedIn = false;
  const pending = ask("engines.signin", { id: "claude" }, (m) => m.type === "engines.updated");
  await Bun.sleep(150);
  signedIn = true; // the user finished the vendor's sign-in in Terminal
  const msgs = await pending;
  expect(msgs[0].type).toBe("engines.signin.result");
  expect(msgs[0].data.row.step).toEqual({ kind: "signin", command: "/bin/claude auth login", certain: true });
  expect(msgs[0].data.watching).toBe(true);
  const updated = msgs.at(-1);
  expect(updated.data.engines.find((e: any) => e.status.id === "claude").step.kind).toBe("ready");
});

test("an existing file at the socket path is never deleted", () => {
  const f = join(dir, "not-a-socket");
  writeFileSync(f, "x");
  expect(() => startServer({ socketPath: f, deps })).toThrow(/not a socket/);
});
