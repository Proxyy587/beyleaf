// belayd entry point: `bun src/main.ts [--socket <path>]`.
import { homedir } from "node:os";
import { join } from "node:path";
import { realDeps } from "./engines/detect";
import { startServer } from "./server";

const i = process.argv.indexOf("--socket");
const socketPath = i > 0 && process.argv[i + 1] ? process.argv[i + 1]! : join(homedir(), "Library/Application Support/Belay/belayd.sock");
const server = startServer({ socketPath, deps: realDeps() });
console.log(`belayd listening on ${server.socketPath}`);
for (const sig of ["SIGINT", "SIGTERM"] as const) process.on(sig, () => { server.stop(); process.exit(0); });

// `--exit-with-parent`: the app holds our stdin; when it quits or dies the pipe closes and so do we (no orphan daemon).
if (process.argv.includes("--exit-with-parent")) {
  void (async () => { for await (const _ of Bun.stdin.stream()) { /* drain */ } server.stop(); process.exit(0); })();
}
