#!/usr/bin/env bash
# Repo integrity checks for Belay. Exit non-zero on any failure.
set -uo pipefail
root="$(git rev-parse --show-toplevel)"; cd "$root"
fail=0; ok() { echo "ok    $*"; }; bad() { echo "FAIL  $*"; fail=1; }

# 1. refs.lock: only permissive licences
while read -r dir url commit license _; do
  case "$license" in MIT|Apache-2.0|BSD-2-Clause|BSD-3-Clause) ;; *) bad "refs.lock: $dir has non-permissive licence '$license'";; esac
done < <(grep -vE '^\s*(#|$)' refs.lock)
ok "refs.lock licences are permissive"

# 2. third_party: SOURCE.md hashes match files; files match pinned refs when present
before=$fail; fail=0
for d in third_party/*/; do
  name="$(basename "$d")"
  [ -f "$d/SOURCE.md" ] || { bad "$name: missing SOURCE.md"; continue; }
  [ -f "$d/LICENSE" ] || bad "$name: missing LICENSE"
  grep -qE "^$name[[:space:]]" refs.lock || bad "$name: not listed in refs.lock"
  grep -q "## Why we vendor it" "$d/SOURCE.md" && ! grep -q "^_TODO_$" "$d/SOURCE.md" || bad "$name: 'Why we vendor it' not filled in"
  grep -oE '^\| `[^`]+` \| `[0-9a-f]{16}`' "$d/SOURCE.md" | sed -E 's/^\| `([^`]+)` \| `([0-9a-f]{16})`/\1 \2/' | while read -r f h; do
    [ -f "$d/$f" ] || { echo "FAIL  $name: listed file missing: $f"; continue; }
    [ "$(shasum -a 256 "$d/$f" | cut -c1-16)" = "$h" ] || echo "FAIL  $name: hash mismatch: $f"
    if [ -f "refs/$name/$f" ]; then cmp -s "refs/$name/$f" "$d/$f" || echo "FAIL  $name: differs from refs: $f"; fi
  done | tee /tmp/belay-verify.$$; [ -s /tmp/belay-verify.$$ ] && fail=1; rm -f /tmp/belay-verify.$$
  grep -q "\[$name\]\|## $name" THIRD_PARTY_NOTICES.md || grep -qi "$name" THIRD_PARTY_NOTICES.md || bad "$name: missing from THIRD_PARTY_NOTICES.md"
done
[ $fail -eq 0 ] && ok "third_party provenance checked"; [ $before -eq 1 ] && fail=1

# 3. ADR index lists every ADR file
for f in docs/decisions/0*.md; do
  grep -q "($(basename "$f"))" docs/decisions/README.md || bad "ADR index missing $(basename "$f")"
done
ok "ADR index checked"

# 4. Changelog has an Unreleased section
grep -q '^## \[Unreleased\]' CHANGELOG.md && ok "CHANGELOG has [Unreleased]" || bad "CHANGELOG missing [Unreleased]"

# 5. Code must never reference agent credential stores (ADR 0004)
if grep -rnE '\.claude/\.credentials|\.codex/auth\.json|claude\.ai/oauth' apps core 2>/dev/null; then bad "credential path referenced in apps/ or core/"; else ok "no agent-credential references in apps/ or core/"; fi

# 6. refs/ never committed
git ls-files --error-unmatch refs >/dev/null 2>&1 && bad "refs/ is tracked by git" || ok "refs/ is not tracked"

[ $fail -eq 0 ] && echo "verify-repo: PASS" || { echo "verify-repo: FAIL"; exit 1; }
