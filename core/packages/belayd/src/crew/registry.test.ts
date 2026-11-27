import { describe, expect, test } from "bun:test";
import { MAX_BUDDIES, MAX_CHILDREN, Registry, slug } from "./registry";
import { MAX_HOPS, Talk } from "./talk";

const spec = (name: string, sprite: string, extra = {}) => ({ name, sprite, job: "does a thing", ...extra });

describe("the roster", () => {
  test("starts with beepo alone: nothing is made on its own", () => {
    const r = new Registry();
    expect(r.buddies.map((b) => b.id)).toEqual(["beepo"]);
  });
  test("you can make a buddy", () => {
    const r = new Registry();
    const made = r.create("you", spec("Sprout", "sprout", { tiers: ["observe", "errands"] }));
    expect(made.ok && made.value).toMatchObject({ id: "sprout", createdBy: "you", tiers: ["observe", "errands"], autonomy: "ask" });
  });
  test("names and characters are unique; unknown characters are refused", () => {
    const r = new Registry();
    r.create("you", spec("pip", "pip"));
    expect(r.create("you", spec("Pip", "willo")).ok).toBe(false);
    expect(r.create("you", spec("other", "pip")).ok).toBe(false);
    expect(r.create("you", spec("zed", "nobody")).ok).toBe(false);
    expect(r.create("you", spec("!", "willo")).ok).toBe(false);
  });
  test("slug", () => expect(slug("  Fizz the DJ! ")).toBe("fizz-the-dj"));
  test("the crew is capped", () => {
    const r = new Registry();
    const names = ["sprout", "willo", "pip", "gloop", "barnaby", "fig", "poko", "crush", "fizz"];
    let made = 0;
    for (const n of names) if (r.create("you", spec(n, n)).ok) made++;
    expect(r.buddies.length).toBe(MAX_BUDDIES);
    expect(made).toBe(MAX_BUDDIES - 1);
  });
});

describe("a buddy making a buddy", () => {
  test("allowed for a buddy you made, and recorded as its child", () => {
    const r = new Registry();
    r.create("you", spec("sprout", "sprout"));
    const kid = r.create("sprout", spec("tester", "toby"));
    expect(kid.ok && kid.value.createdBy).toBe("sprout");
  });
  test("a buddy made by a buddy cannot make more", () => {
    const r = new Registry();
    r.create("you", spec("sprout", "sprout"));
    r.create("sprout", spec("tester", "toby"));
    expect(r.create("tester", spec("deeper", "fig")).ok).toBe(false);
  });
  test("at most three children", () => {
    const r = new Registry();
    r.create("you", spec("sprout", "sprout"));
    const sprites = ["toby", "fig", "poko", "crush"];
    const results = sprites.map((s) => r.create("sprout", spec(`k-${s}`, s)).ok);
    expect(results).toEqual([true, true, true, false]);
    expect(MAX_CHILDREN).toBe(3);
  });
  test("it cannot give more reach or freedom than it has", () => {
    const r = new Registry();
    r.create("you", spec("sprout", "sprout", { tiers: ["observe", "errands"], autonomy: "ask" }));
    expect(r.create("sprout", spec("hands-kid", "toby", { tiers: ["hands"] })).ok).toBe(false);
    expect(r.create("sprout", spec("free-kid", "fig", { autonomy: "routine" })).ok).toBe(false);
    expect(r.create("sprout", spec("ok-kid", "poko", { tiers: ["errands"] })).ok).toBe(true);
  });
  test("an unknown maker is refused", () => {
    expect(new Registry().create("ghost", spec("ab", "fig")).ok).toBe(false);
  });
});

describe("removing", () => {
  test("beepo stays", () => expect(new Registry().remove("you", "beepo").ok).toBe(false));
  test("a buddy removes only its own, and a removed buddy takes its children", () => {
    const r = new Registry();
    r.create("you", spec("sprout", "sprout"));
    r.create("you", spec("willo", "willo"));
    r.create("sprout", spec("tester", "toby"));
    expect(r.remove("willo", "tester").ok).toBe(false);
    const gone = r.remove("you", "sprout");
    expect(gone.ok && gone.value).toEqual(["sprout", "tester"]);
    expect(r.buddies.map((b) => b.id)).toEqual(["beepo", "willo"]);
  });
});

describe("talking and sharing", () => {
  const crew = () => {
    const r = new Registry();
    r.create("you", spec("sprout", "sprout"));
    r.create("you", spec("willo", "willo"));
    return { r, t: new Talk(r, () => new Date("2026-11-27T10:00:00Z")) };
  };
  test("buddies message each other and the pair's thread is readable", () => {
    const { t } = crew();
    t.tell("sprout", "willo", "find the Bun docs");
    t.tell("willo", "sprout", "here: bun.sh/docs");
    expect(t.thread("willo", "sprout").map((m) => m.from)).toEqual(["sprout", "willo"]);
  });
  test("unknown buddies and self-talk are refused", () => {
    const { t } = crew();
    expect(t.tell("sprout", "ghost", "hi").ok).toBe(false);
    expect(t.tell("sprout", "sprout", "hi").ok).toBe(false);
  });
  test("a chain of buddy messages stops and waits for you; your word resets it", () => {
    const { t } = crew();
    let refused = 0;
    for (let i = 0; i < MAX_HOPS + 3; i++) if (!(i % 2 ? t.tell("willo", "sprout", "x") : t.tell("sprout", "willo", "x")).ok) refused++;
    expect(refused).toBe(3);
    expect(t.tell("you", "sprout", "carry on").ok).toBe(true);
    expect(t.tell("sprout", "willo", "x").ok).toBe(true);
  });
  test("the notebook is shared, bounded, and empty text clears a note", () => {
    const { t } = crew();
    t.share("willo", "docs", "bun.sh/docs");
    expect(t.contextFor()).toContain("docs (from willo): bun.sh/docs");
    t.share("you", "docs", "");
    expect(t.notes()).toEqual([]);
    for (let i = 0; i < 30; i++) t.share("you", `k${i}`, "x");
    expect(t.share("you", "one-more", "x").ok).toBe(false);
  });
  test("removing a buddy forgets its threads", () => {
    const { t } = crew();
    t.tell("sprout", "willo", "hi");
    t.forget("willo");
    expect(t.thread("sprout", "willo")).toEqual([]);
  });
});
