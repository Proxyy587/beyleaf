# Playbook: borrowing code from an upstream repo

**Allowed:** only repos in `refs.lock` with MIT, Apache-2.0 or BSD licences.
**Never:** GPL (ADR 0003) or source-available (PolyForm/BSL/"personal use", e.g. dusk bot; ADR 0008). Never copy by hand.

1. **New upstream?**
   - Verify its `LICENSE` file on GitHub.
   - Add a line to `refs.lock`: `<dir> <url> <commit> <licence> <excludes|-> <purpose>`.
   - Commit it on its own: `chore: pin <repo> reference`.
2. `./scripts/fetch-refs.sh` clones or re-pins everything into git-ignored `refs/`.
3. `./scripts/vendor.sh <dir> <path-in-repo>…` copies the files verbatim into `third_party/<dir>/`, copies LICENSE/NOTICE, and writes the SHA-256 table in `SOURCE.md`.
   - Run it under `bash` with array arguments for multiple paths.
4. Fill in **"Why we vendor it"** in `third_party/<dir>/SOURCE.md`: upstream file, what we take, Belay destination, feature IDs.
5. Add or update the project row in `THIRD_PARTY_NOTICES.md`, with its full licence text (and the NOTICE for Apache-2.0).
6. Verify byte-identity: `cmp refs/<dir>/<path> third_party/<dir>/<path>`. The `verify-repo.sh` script checks all of them.
7. **Commit:** one commit per upstream project, e.g. `vendor: import <what> from <Project> (<Licence>)`, plus a CHANGELOG line.
8. **Later adaptation** happens in `apps/` or `core/` with the provenance header. `third_party/` is never edited.

Prefer **tightly scoped, self-contained files**. If a file drags in more than about 3 internal imports (e.g. OpenMausBot `server/procs.ts`), don't vendor it. Note it as a porting reference in `SOURCE.md` instead.
