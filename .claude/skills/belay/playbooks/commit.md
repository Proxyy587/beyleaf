# Playbook: committing

1. **Scope:** one task = one commit. If you did two things, make two commits. Stage files explicitly (`git add <paths>`), never `git add -A` blindly. Check `git status --short` first.
2. **Subject:** Conventional Commits, imperative, ≤ 72 chars. Types: `feat` `fix` `docs` `chore` `refactor` `test` `vendor` `build` `ci`.
   e.g. `feat(belayd): hold PermissionRequest on the hook socket`
3. **Body:** *why*, plus anything a reviewer must know (feature ID, ADR, what was verified).
4. **Changelog:** if the change is user-visible or a decision, add a line under `## [Unreleased]` in `CHANGELOG.md` **in the same commit**.
5. **Trailer:** end with the attribution trailer the session provides, e.g. `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
6. **Run commands in `bash -euo pipefail`** for multi-step commit scripts. zsh doesn't word-split unquoted variables, and a failed step must stop the commit (this has bitten us once).
7. **Before committing:** `.claude/skills/belay/scripts/verify-repo.sh` passes.
8. Never push, rewrite published history, or change commit dates unless the user explicitly asks.
