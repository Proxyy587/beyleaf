#!/bin/bash
# Build and run the widget packing self-test (ADR 0019): pure logic, no UI.
set -euo pipefail
cd "$(dirname "$0")/.."
out="$(mktemp -d)/widgets-selftest"
swiftc -O -swift-version 6 Sources/Belay/Notch/WidgetLayout.swift Sources/Belay/Notch/ClockLogic.swift Sources/Belay/Notch/StopwatchLogic.swift Tests/WidgetsSelfTest/main.swift -o "$out"
"$out"
