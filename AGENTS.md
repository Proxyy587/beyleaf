# Belay: agent and contributor context

Belay is a free, open-source (MIT) macOS notch companion that supervises coding agents (Claude Code, Codex). A small
climber in the notch "holds the rope". When an agent needs approval the rope drops. When it tries something
dangerous Belay "catches the fall". You answer by voice or keyboard.

**Current phase:** pre-v0.1 setup. Docs, decisions and vendored references are in place; no application code yet.
**Next:** the Day 1 spike in `docs/build-plan.md` §3.

## Read first

| Need | Doc |
|---|---|
| What we're building (locked list, acceptance tests) | `docs/features-final.md` |
| How it fits together (processes, modules, protocol, flows) | `docs/architecture.md` |
| Stack and why | `docs/tech-stack.md` |
| Decisions you must not silently reverse | `docs/decisions/` (ADRs) |
| Day-by-day v0.1 plan | `docs/build-plan.md` |
| Borrowed code and its rules | `docs/oss-reuse.md`, `THIRD_PARTY_NOTICES.md`, `third_party/*/SOURCE.md` |
| Sub-agents (Crew) design | `docs/crew.md` |
| Design rules (UI, anti-slop) | `docs/design.md`; widgets `docs/notch-widgets.md`; vs Dynamic Island and Boring Notch `docs/notch-comparison.md` |
| Every UI element, its purpose and status; what was cut and why | `docs/ui-inventory.md` |
| What only the human can do (accounts, legal, hardware) | `docs/prerequisites.md` |
| What changed recently | `CHANGELOG.md` |
| Claude Code playbooks (commit, vendor, ADR, feature, crew) + repo checks | `.claude/skills/belay/` (project skill, loads automatically in Claude Code) |
| Which Claude Code skills we use, and why | `docs/claude-skills.md` |

## Repo map

```
apps/mac/        Swift shell (Belay.app): notch, cards, voice, haptics, Mac bridge. SwiftPM; build+run with scripts/run.sh.
apps/web/        Next.js landing page + docs.
core/            Bun workspace: protocol (zod, source of truth), belayd (all product logic), rules, cards.
rules/           Community danger-rule packs (YAML).
e2e/             Live agent continuation tests (feature A6).
third_party/     Verbatim upstream files + LICENSE + SOURCE.md. Never edit; adapt into apps/ or core/.
refs/            Git-ignored clones at pinned commits (scripts/fetch-refs.sh). Read-only.
docs/            Research, product, stack, architecture, ADRs.
scripts/         fetch-refs.sh, vendor.sh.
```

## Golden rules (each has an ADR)

1. **Swift renders and touches macOS; TypeScript decides.** No product logic in Swift. (ADR 0001)
2. **The shell and core speak only protocol v1.** Change schemas in `core/packages/protocol` and regenerate the Swift types; never hand-edit the generated code. (ADR 0001)
3. **Fail open, never auto-allow.** On timeout, crash or shutdown, the hook returns no decision. No `allow` without a user action or a user-made "Always" rule. (ADR 0005)
4. **Never touch agent credentials.** Don't read `~/.claude` or `~/.codex` auth or session files, and don't handle subscription tokens. Engines run the user's own CLIs. (ADR 0004)
5. **No GPL code, ever.** Only repos in `refs.lock`, only through `scripts/vendor.sh`. Adapted files get a provenance header. (ADR 0003)
6. **Hooks go over 0600 Unix sockets via the `belay-hook` shim.** No TCP ports. (ADR 0006)
7. **No vendor names or logos in Belay's branding.** Plain-text "works with Claude Code and Codex" is fine.
7b. **The notch window is ours** (ADR 0014). Don't add DynamicNotchKit back without a new ADR.
8. **Untrusted content can't grant permission.** Tainted chains always drop the rope for outward, write-outside or shortcut actions. Only the user approves. (ADR 0011)
9. **Source-available code is off-limits** (PolyForm, BSL, "personal use", e.g. dusk bot): never copied or adapted. dusk bot alone may be cloned to `refs/duskbot` for design study, with learnings written in our own words. (ADR 0008, 0018)

## Working agreement

- **One task = one commit.** Small, focused, buildable. Use Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `vendor:`, `build:`, `ci:`.
  - Subject: imperative, ≤ 72 characters.
  - Body: *why*, plus anything a reviewer must know.
  - End agent-made commits with the repo's attribution trailer.
- **One branch per major update.** Branch off `main` as `<type>/<topic>` (for example `skills/design-skills`,
  `feat/notch-redesign`, `feat/hook-spike`), commit each task on it, push it, then merge it into `main` with
  `--no-ff` so the update stays visible as one unit. Small fixes may go straight to an open update branch.
- **Update `CHANGELOG.md`** under `[Unreleased]` in the same commit as any user-visible change or decision.
- **New decision → new ADR** in `docs/decisions/`, linked from its README. Don't edit an accepted ADR's decision; supersede it.
- **Vendoring:**
  - `scripts/fetch-refs.sh`, then `scripts/vendor.sh <ref> <paths…>`, then fill "Why we vendor it" in `SOURCE.md` and add or update the `THIRD_PARTY_NOTICES.md` row. One commit per upstream project.
  - Adapted copies start with: `// Adapted from <Project> (<Licence>), <upstream path> @ <short commit>. See third_party/<dir>/.` Apache-2.0 adaptations add `Modified by Belay contributors.`
- **Unknowns stay marked.** If something isn't verified (an API, a version, agent behaviour), write UNVERIFIED and add it to the Day 1 checks. Don't present guesses as facts.
- **Verify before you say it's done.** Run the relevant tests or build, or say plainly that you didn't. Run `.claude/skills/belay/scripts/verify-repo.sh` before every commit.

## Prerequisites (local)

- Xcode with Swift 6.x (present on the dev machine: Swift 6.2.3)
- Bun (**not installed yet**). Pin it in `.bun-version` when the core is scaffolded.
- Xcode is **not required** for the Mac app (SwiftPM + Command Line Tools, ADR 0013). XcodeGen is no longer used.
- Claude Code and Codex CLIs for e2e tests
