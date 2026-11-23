#!/usr/bin/env bash
# Clone every repo in refs.lock into refs/ at its pinned commit, shallowly.
# Safe to re-run: existing clones are re-pointed at the pinned commit.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/refs"

grep -vE '^\s*(#|$)' "$root/refs.lock" | while read -r dir url commit license excludes purpose; do
  dest="$root/refs/$dir"
  if [ ! -d "$dest/.git" ]; then
    if [ "$excludes" != "-" ]; then
      git clone -q --filter=blob:none --no-checkout "$url" "$dest"
      git -C "$dest" sparse-checkout set --no-cone '/*' "!/$excludes"
    else
      git clone -q --filter=blob:none --no-checkout "$url" "$dest"
    fi
  fi
  git -C "$dest" fetch -q --depth 1 origin "$commit"
  git -C "$dest" checkout -q --detach "$commit"
  echo "ok  $dir @ ${commit:0:12}  ($license)"
done
