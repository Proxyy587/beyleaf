#!/usr/bin/env bash
# Rebuild every buddy asset from the two reference sheets and print the match scores.
#
# Needs Node 20+ and two npm packages that are NOT part of this repo (install them in a scratch folder):
#   mkdir -p /tmp/buddies-work && cd /tmp/buddies-work && npm init -y && npm i sharp @resvg/resvg-js
#   NODE_PATH=/tmp/buddies-work/node_modules brand/buddies/tools/run.sh /tmp/buddies-work
# sharp is Apache-2.0 (it loads libvips, LGPL, as a dynamic library); @resvg/resvg-js is MPL-2.0. Neither is vendored.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; work="${1:?work dir}"; dest="$here/.."
mkdir -p "$work/out" && cd "$work"
node "$here/smooth.js"                       # smooth: trace the vector sheet (out/smooth, out/smooth-meta.json)
node "$here/pixel.js"                        # pixel: recover each sprite's grid and sample its cells (out/pixel-raw.json)
node "$here/pixgen.js"                       # pixel: clean palette, grid-aligned faces (out/pixel-meta.json)
node "$here/export.js"                       # both: one data file (out/buddies-data.json)
node "$here/metrics.js"                      # IoU + colour difference against the reference crops (out/metrics.json)
node "$here/write.js" "$dest"                # SVG + PNG files into brand/buddies/{smooth,pixel}
node -e "const d=require('./out/buddies-data.json');d.metrics=require('./out/metrics.json');require('fs').writeFileSync('$dest/buddies.json',JSON.stringify(d))"
node "$here/sheetall.js" "$dest/comparison.png"
node "$here/../preview/build.mjs"
