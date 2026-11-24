#!/bin/bash
# Build Belay with SwiftPM, wrap it in an .app bundle, sign it ad hoc and launch it.
#   scripts/run.sh            debug build, launch
#   CONFIG=release scripts/run.sh
#   scripts/run.sh --expand   launch with the notch already open (for screenshots/testing)
#   scripts/run.sh --build-only
# Bundle steps adapted from Perch (MIT), scripts/run.sh @ 47ce905f. See third_party/perch/ and refs/perch.
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG=${CONFIG:-debug}
swift build -c "$CONFIG"
APP=build/Belay.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# SwiftPM records the deployment target as the SDK version; record the real SDK so macOS 26 gives Belay the current look.
vtool -set-build-version macos "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' Resources/Info.plist)" "$(xcrun --show-sdk-version)" \
  -replace -output "$APP/Contents/MacOS/Belay" ".build/$CONFIG/Belay"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(git rev-list --count HEAD 2>/dev/null || echo 1)" "$APP/Contents/Info.plist"
# Ad hoc signature for local testing. It changes every build, so macOS may ask for the Automation permission again.
codesign --force --sign - "$APP" >/dev/null
[ "${1:-}" = "--build-only" ] && { echo "Built $(pwd)/$APP"; exit 0; }
pkill -x Belay 2>/dev/null || true
for _ in $(seq 50); do pgrep -x Belay >/dev/null || break; sleep 0.1; done
sleep 0.5   # LaunchServices still holds the old process briefly; opening too soon fails with error -600
ARGS=(); [ $# -gt 0 ] && ARGS=(--args "$@")
for attempt in 1 2 3; do open "$APP" ${ARGS[@]+"${ARGS[@]}"} 2>/dev/null && break; sleep 1; done
pgrep -x Belay >/dev/null || { echo "Belay did not start" >&2; exit 1; }
echo "Launched $(pwd)/$APP"
