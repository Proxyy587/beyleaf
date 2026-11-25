// A0 spike: the command hook Claude Code runs. Forwards stdin to belayd over the Unix socket and prints its reply.
// Fail open (ADR 0005): if belayd is down, slow or returns garbage, print nothing and exit 0, so Claude Code falls
// back to its own permission flow. Never prints anything that isn't belayd's JSON.
import { homedir } from "node:os";
import { join } from "node:path";

const SOCKET = process.env.BELAY_SOCKET ?? join(homedir(), "Library/Application Support/Belay/belayd.sock");
const input = await Bun.stdin.text();

try {
  const reply = await new Promise<string>((resolve, reject) => {
    let out = "";
    Bun.connect({
      unix: SOCKET,
      socket: {
        // Hook stdin is one JSON object; newline-terminate it so belayd knows the request is complete.
        open(s) { s.write(input.replace(/\n/g, " ") + "\n"); },
        data(_s, chunk) { out += chunk.toString(); },
        close() { resolve(out); },
        error(_s, e) { reject(e); },
        connectError(_s, e) { reject(e); },
      },
    }).catch(reject);
  });
  if (reply.trim()) { JSON.parse(reply); process.stdout.write(reply); }   // only well-formed JSON reaches Claude
} catch {
  // belayd unavailable: no decision.
}
process.exit(0);
