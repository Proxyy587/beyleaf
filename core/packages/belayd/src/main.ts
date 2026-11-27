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
