#!/bin/bash
# Draw beepo into the app icon: builds, renders brand/export/app-icon-1024.png with the app itself, and makes AppIcon.icns.
#   scripts/make-icon.sh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build >/dev/null
OUT=../../brand/export
.build/debug/Belay --render-icon "$OUT/app-icon-1024.png"
SET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$SET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$OUT/app-icon-1024.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$OUT/app-icon-1024.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o "$OUT/AppIcon.icns"
echo "Wrote $OUT/AppIcon.icns"
