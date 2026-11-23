# Contributing to Belay

Thanks for helping! Belay is MIT-licensed and built in the open.

## Before you start
1. Read `AGENTS.md`. It holds the repo map, golden rules and working agreement that every human and agent follows.
2. Check `docs/features-final.md` for what's in scope, and `docs/decisions/` for what's already decided.

## Setup
```sh
./scripts/fetch-refs.sh        # optional: clone pinned reference repos into refs/ (read-only)
```
App and core build steps will be added here when code lands (v0.1).

## Commits and PRs
- One task per commit, Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `vendor:`, `build:`, `ci:`).
- User-visible changes and decisions update `CHANGELOG.md` → `[Unreleased]` in the same commit.
- PRs describe *why*, link the feature ID (e.g. `A3`) or ADR, and say how the change was verified.

## Borrowing code
- Only from repos in `refs.lock`, only MIT/Apache-2.0/BSD, never GPL (ADR 0003).
- Use `scripts/vendor.sh`. Don't copy by hand. Keep `third_party/` byte-identical to upstream and adapt into `apps/` or `core/`
  with a provenance header.
- To add a new upstream repo, add it to `refs.lock` in its own commit, with its licence and purpose.

## Security
Never commit secrets. Belay must never read agent credentials (ADR 0004). Report vulnerabilities privately to the
maintainers rather than in a public issue.
