# Source

- **Upstream:** https://github.com/vercel-labs/agent-browser, `skills/agent-browser/` @ f0a9835 (2026-11-24)
- **Licence:** Apache-2.0 (`LICENSE`, copied from the repository root)
- **Files (verbatim, unmodified):**

| File | SHA-256 (first 16) |
|---|---|
| `SKILL.md` | `7d46deeb0101e84f` |
| `LICENSE` | `014bb31e83d5c2e7` |

## Why we use it
It lets an agent see a web page: screenshot a reference site, read its computed fonts and colours, and later QA
`apps/web`. `SKILL.md` is only a stub. The real guide comes from the installed CLI (`agent-browser skills get core`),
which always matches the CLI's version.

## Setup (once per Mac)
- `npm i -g agent-browser@0.44.0` (npm's latest on 2026-11-25; the repo's main says 0.45.0, which isn't published yet).
- `agent-browser install` downloads Chromium (191 MB). On 2026-11-25 it timed out twice here, so we use an installed
  Chromium browser instead: `export AGENT_BROWSER_EXECUTABLE_PATH="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"`
  (or Google Chrome's path).

## Rules
- Public pages only. Never sign in, submit forms or post anything without the user asking.
- Reference sites are for feel. Record what we learned in our own words (ADR 0008). Never copy their CSS, assets or copy.
