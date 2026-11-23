# 0003: No GPL code; vendor only MIT/Apache-2.0, with provenance

- **Status:** accepted (2026-11-24)
- **Context:** Belay is MIT. Boring Notch, Notchi and jackson-storm/DynamicNotch are GPL-3.0; copying from them would force Belay to become GPL.
- **Decision:**
  - GPL repos are never cloned into `refs/` and never copied. Their UX may be studied from their public pages only.
  - Code comes only from repos listed in `refs.lock`. It is vendored **verbatim** into `third_party/<project>/` with the upstream `LICENSE` and a `SOURCE.md` (commit, files, SHA-256, intended use).
  - Adapted copies in `apps/` or `core/` keep a header naming the upstream file and commit.
  - `THIRD_PARTY_NOTICES.md` lists every project.
- **Consequences:** Adaptations show up as reviewable diffs against the verbatim copy. Apache-2.0 files keep Apache terms and the upstream NOTICE.
