# Source

- **Upstream:** https://github.com/mattpocock/skills, `skills/engineering/improve-codebase-architecture/` @ d653911 (2026-11-24)
- **Licence:** MIT (`LICENSE`, copied from the repository root)
- **Files:** `HTML-REPORT.md` verbatim. `SKILL.md` with three Belay edits:
  1. ADRs live in `docs/decisions/`, not `docs/adr/`.
  2. The "grilling" skill isn't installed, so step 3 asks one question at a time, each with a recommended answer.
  3. The "domain-modeling" skill isn't installed, so step 3 keeps `GLOSSARY.md` current directly.

| File | SHA-256 (first 16, as shipped here) |
|---|---|
| `SKILL.md` | `58bc1299e3405fa3` |
| `HTML-REPORT.md` | `581e8bb5a521e46b` |
| `LICENSE` | `0e7ac423bf2c6e22` |

## Why we use it
Run it on purpose (`/improve-codebase-architecture`; it never triggers by itself) before a big build step, such as
`belayd` or the Crew. It finds shallow modules in `apps/mac` and the core and proposes deeper ones, then asks before
changing anything. It needs its partner skill `codebase-design` for its vocabulary.

## How it fits Belay
ADRs in `docs/decisions/` are settled. A candidate that contradicts one is shown only with a reason to reopen it.
`GLOSSARY.md` doesn't exist yet. The skill creates it at the repo root the first time it names a domain term.
