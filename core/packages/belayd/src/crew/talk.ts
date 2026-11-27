// How buddies talk and what they share (docs/buddies.md §2a). Messages between buddies are recorded where you can read
// them; a shared notebook holds what any of them wants the others to know. Both are bounded, so two buddies can't talk
// each other into a loop or fill the disk.
import type { Message } from "@belay/protocol";
import type { Registry, Result } from "./registry";

/** Longest chain of buddy-to-buddy replies before it stops and waits for you. */
export const MAX_HOPS = 6;
export const NOTEBOOK_KEYS = 30;

export function pairThread(a: string, b: string): string {
  return `dm:${[a, b].sort().join(":")}`;
}

export class Talk {
  private log = new Map<string, Message[]>();
  private notebook = new Map<string, { by: string; text: string }>();
  /** Consecutive messages between buddies with no word from you in between. */
  private hops = 0;
  private n = 0;
  constructor(private reg: Registry, private now: () => Date = () => new Date(), private tainted: (from: string) => boolean = () => false) {}

  thread(a: string, b: string): readonly Message[] { return this.log.get(pairThread(a, b)) ?? []; }
  notes(): { key: string; by: string; text: string }[] { return [...this.notebook].map(([key, v]) => ({ key, ...v })); }

  /** `from` says something to `to`. Anything from you resets the chain. */
  tell(from: "you" | string, to: string, text: string): Result<Message> {
    if (!this.reg.get(to)) return { ok: false, why: `${to} is not on your crew` };
    if (from !== "you" && !this.reg.get(from)) return { ok: false, why: `${from} is not on your crew` };
    if (from === to) return { ok: false, why: "a buddy can't message itself" };
    if (from === "you") this.hops = 0;
    else if (++this.hops > MAX_HOPS) return { ok: false, why: `${MAX_HOPS} messages between buddies with no word from you: waiting for you` };
    const thread = pairThread(from, to);
    const message: Message = { id: `m${++this.n}`, thread, from, text, at: this.now().toISOString(), steps: [], tainted: from !== "you" && this.tainted(from) };
    const list = this.log.get(thread) ?? [];
    list.push(message);
    this.log.set(thread, list.slice(-200));
    return { ok: true, value: message };
  }

  /** Every buddy reads the notebook; any buddy (or you) writes. Anything from untrusted content stays marked. */
  share(by: "you" | string, key: string, text: string): Result<{ key: string }> {
    if (by !== "you" && !this.reg.get(by)) return { ok: false, why: `${by} is not on your crew` };
    if (!this.notebook.has(key) && this.notebook.size >= NOTEBOOK_KEYS) return { ok: false, why: "the notebook is full" };
    if (text === "") this.notebook.delete(key);
    else this.notebook.set(key, { by, text });
    return { ok: true, value: { key } };
  }

  /** What a buddy gets to start with when it is made: the notes, nothing of other buddies' private threads. */
  contextFor(): string {
    return this.notes().map((n) => `${n.key} (from ${n.by}): ${n.text}`).join("\n");
  }

  /** Removing a buddy removes its threads. The notebook keeps what it wrote: that was shared on purpose. */
  forget(id: string) {
    for (const k of [...this.log.keys()]) if (k.split(":").slice(1).includes(id)) this.log.delete(k);
  }
}
