// The crew roster (docs/buddies.md §2a). Buddies are never made on their own: you make one, or a buddy you already have
// makes one, and either way it is shown. Rules here are the whole policy, so the tests can pin them.
import type { Autonomy, Buddy, BuddySpec, Tier } from "@belay/protocol";

export const MAX_BUDDIES = 8;
/** A buddy may make at most this many, and a buddy made by a buddy may not make any: no runaway spawning. */
export const MAX_CHILDREN = 3;

const TIERS: Tier[] = ["observe", "errands", "hands", "sandbox"];
const AUTONOMY: Autonomy[] = ["ask", "edits", "routine"];
/** The sprites that exist (brand/buddies/buddies.json). */
export const SPRITES = ["beepo", "sprout", "willo", "pip", "gloop", "barnaby", "fig", "poko", "crush", "fizz", "otto", "bram", "breeze", "ziggy", "toby"] as const;

export type Maker = "you" | string;
export type Result<T> = { ok: true; value: T } | { ok: false; why: string };

/** beepo is the one buddy every install has: it takes what you say and hands it to whoever should do it. */
export const BEEPO: Buddy = {
  id: "beepo", name: "beepo", sprite: "beepo", job: "routes what you ask", engine: "rules",
  tiers: ["observe"], autonomy: "ask", createdBy: "you",
};

export function slug(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 24);
}

export class Registry {
  private list: Buddy[] = [{ ...BEEPO }];
  get buddies(): readonly Buddy[] { return this.list; }
  get(id: string): Buddy | undefined { return this.list.find((b) => b.id === id); }
  /** Sprites not yet taken, in catalogue order. */
  free(): string[] { return SPRITES.filter((s) => !this.list.some((b) => b.sprite === s)); }
  children(of: string): Buddy[] { return this.list.filter((b) => b.createdBy === of); }

  create(by: Maker, spec: BuddySpec): Result<Buddy> {
    const maker = by === "you" ? null : this.get(by);
    if (by !== "you" && !maker) return { ok: false, why: `${by} is not on your crew` };
    if (this.list.length >= MAX_BUDDIES) return { ok: false, why: `the crew is full (${MAX_BUDDIES})` };
    if (maker) {
      if (maker.createdBy !== "you") return { ok: false, why: `${maker.name} was made by a buddy, so it can't make more` };
      if (this.children(maker.id).length >= MAX_CHILDREN) return { ok: false, why: `${maker.name} has already made ${MAX_CHILDREN}` };
    }
    const id = slug(spec.name);
    if (id.length < 2) return { ok: false, why: "give the buddy a name" };
    if (this.get(id)) return { ok: false, why: `there is already a buddy called ${id}` };
    if (!SPRITES.includes(spec.sprite as (typeof SPRITES)[number])) return { ok: false, why: `no character called ${spec.sprite}` };
    if (this.list.some((b) => b.sprite === spec.sprite)) return { ok: false, why: `${spec.sprite} is already on your crew` };

    // A buddy can only hand on what it has: never more reach, never more freedom than its maker.
    const wantTiers = spec.tiers ?? ["observe"];
    const wantAuto = spec.autonomy ?? "ask";
    if (maker) {
      const over = wantTiers.filter((t) => !maker.tiers.includes(t));
      if (over.length) return { ok: false, why: `${maker.name} can't give ${over.join(", ")}: it doesn't have it` };
      if (AUTONOMY.indexOf(wantAuto) > AUTONOMY.indexOf(maker.autonomy)) return { ok: false, why: `${maker.name} can't give more freedom than it has` };
    }
    // Reach is ordered: a tier you can't picture below another is not a reason to mix them up, so keep catalogue order.
    const tiers = TIERS.filter((t) => wantTiers.includes(t));
    const buddy: Buddy = {
      id, name: spec.name.trim(), sprite: spec.sprite, job: spec.job.trim(), engine: "rules",
      tiers, autonomy: wantAuto, createdBy: by,
    };
    this.list.push(buddy);
    return { ok: true, value: buddy };
  }

  /** You can remove any buddy but beepo. A buddy can remove only ones it made. Whatever a buddy made goes with it. */
  remove(by: Maker, id: string): Result<string[]> {
    const target = this.get(id);
    if (!target) return { ok: false, why: `${id} is not on your crew` };
    if (id === "beepo") return { ok: false, why: "beepo stays: it is how you reach the rest" };
    if (by !== "you" && target.createdBy !== by) return { ok: false, why: `${by} can only remove buddies it made` };
    const gone = [id, ...this.children(id).map((b) => b.id)];
    this.list = this.list.filter((b) => !gone.includes(b.id));
    return { ok: true, value: gone };
  }
}
