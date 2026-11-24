#!/bin/bash
# Build and run the BeatAnalyzer self-test on synthetic signals (silence, sine, kick drum). No audio device is used.
set -euo pipefail
cd "$(dirname "$0")/.."
out="$(mktemp -d)/beat-selftest"
swiftc -O -swift-version 6 Sources/Belay/Audio/BeatAnalyzer.swift Tests/BeatSelfTest/main.swift -o "$out"
"$out"
