# 0018: dusk bot may be cloned locally for design study (amends 0008)

- **Status:** accepted (2026-11-25). Amends ADR 0008 for one case. The rest of 0008 stands.
- **Context:**
  - The owner asked to clone `DuskBotAI/duskbot` into `refs/` to study its skills and design, because its product
    feel is the closest to what Belay wants.
  - Its licence is unchanged: PolyForm Noncommercial 1.0.0, checked in the clone @ `981d1a79` (2026-11-25).
  - Belay is MIT and so permits commercial use. PolyForm code still can't enter it.
- **Decision:**
  - A study clone of dusk bot may live in `refs/duskbot`. That folder is git-ignored and local only.
  - It isn't listed in `refs.lock`, isn't fetched by `scripts/fetch-refs.sh`, and is never passed to `scripts/vendor.sh`.
  - Agents may read it for **design understanding**: rules, token values, motion timing, audit methods.
  - What we learn is recorded **in our own words** (for example `.claude/skills/belay-design/SKILL.md`).
  - Never copy or adapt code, CSS, skill text, assets or copy from it, and never translate its source line by line into Swift.
  - Numbers that describe a feel (a 240 ms duration, a 6 px rise) are facts we may reuse. Its source files are not.
- **Consequences:**
  - Better design input, at the cost of a weaker clean-room story. Reviewers should reject any diff that resembles
    dusk bot's code or text.
  - Other source-available projects still follow 0008 unchanged.
