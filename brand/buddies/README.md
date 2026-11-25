# Belay buddies

Fifteen buddies in two styles, traced from the owner's two reference sheets. Each buddy's eyes are separate, so they can blink, look, sleep and go happy.

**Roster:** beepo · sprout · willo · pip · gloop · barnaby · fig · poko · crush · fizz · otto · bram · breeze · ziggy · toby. beepo (smooth) is the temporary Belay logo.

| Path | What it is |
|---|---|
| `ref-vector-sheet.png`, `ref-pixel-sheet.png` | The owner's art: the source of truth |
| `current-attempt-rejected.png` | The earlier attempt the owner rejected (wrong shapes). Kept as a record. |
| `buddies.json` | All art as data: smooth paths and eye capsules, pixel grids and eye cells, plus the match scores. The Mac app's `BuddyArtwork.swift` and the preview are generated from it. |
| `smooth/<name>.svg` | Smooth buddies. Parts: `buddy-body` (and `buddy-screen`, `buddy-cap`, `buddy-dark`, `buddy-notch` where the art has them), `buddy-eyes`, `buddy-eyes-happy` (hidden). |
| `pixel/<name>.svg` | Pixel buddies as cells (`shape-rendering="crispEdges"`): `buddy-body`, `buddy-mouth`, `buddy-eyes`, `buddy-eyes-closed` and `buddy-eyes-happy` (both hidden). |
| `pixel/<name>.png`, `pixel/<name>@8x.png` | Lossless PNGs: one pixel per cell, and 8× nearest-neighbour |
| `comparison.png` | Reference beside ours for all 30, with scores |
| `preview/index.html` | Every buddy, both styles, every animation (self-contained; works from `file://`) |
| `tools/` | The tracing pipeline (`tools/run.sh` rebuilds everything above) |

## How the art was made

**Smooth.**
1. Each cell of the vector sheet is separated from the background, the name, the "+ buddy" pill and the small thumbnail.
2. Each pixel is unmixed into the buddy's palette (sampled from the sheet) to get sub-pixel coverage per colour.
3. The coverage is contoured at 50% and fitted with cubic Béziers (0.3 px tolerance; corners kept where the outline turns sharply).
4. Overlays (barnaby's screen, bram's cap, otto's tower and periscope) own their part of the outer edge, so no body-coloured fringe shows.
5. Eyes are fitted as capsules from each eye's own measurements, then both eyes take the same size.
6. toby's small notch is the lighter triangle at the bottom of the sheet, drawn as a separate `buddy-notch` part. It is probably the image generator's watermark sparkle, so it is easy to drop.

**Pixel.** The sheet is not drawn on one exact grid: each sprite has its own pitch (7.1–8.1 px), and its cell edges wander by a pixel or two. So, for each sprite:
1. Fit the uniform grid that best matches the silhouette (a wide search over pitch and phase, then refinement).
2. Let each grid line move up to 1.5 px toward the sprite's real cell edges.
3. Sample every cell by majority vote over its centre. Merge colours that differ only by sampling noise, and drop edge cells that are only a blend with the background.
4. The reference draws eyes, mouths and blush as smooth shapes that ignore its own grid. These are measured and redrawn on the grid:
   - eyes are 2 × 3 cells (2 × 2 where the reference eye is shorter);
   - mouths and blush are one row.
5. A few hand fixes, each commented in `tools/pixfix.js`:
   - otto's portholes are drawn the same on both sides;
   - barnaby's two status LEDs each get their own green or red cell;
   - willo's outline uses one orange.

pip has no eyes in the pixel sheet. Its visor glint is its "eye": it hides for a blink and moves for a look.

## Match against the reference

Every asset is rendered at the reference cell's size and compared with the reference crop. The reference's alpha comes from unmixing it against the sheet background.
- **IoU** is the silhouette intersection over union, at 50% alpha.
- **ΔE** is the mean CIE76 colour difference over pixels that are fully inside both.
- For pixel art, **IoU** is the honest render on a uniform grid, which is what the asset really is. **Recovered grid** is the same cells drawn on the sheet's own wandering grid lines, which checks the cell contents alone.

| buddy | smooth IoU | smooth ΔE | pixel IoU | pixel IoU, recovered grid | pixel ΔE | pixel cells | pitch (px) |
|---|---|---|---|---|---|---|---|
| beepo | 0.996 | 1.9 | 0.981 | 0.991 | 5.3 | 20×21 | 7.51 × 7.19 |
| sprout | 0.997 | 1.6 | 0.979 | 0.993 | 5.7 | 15×21 | 7.57 × 7.73 |
| willo | 0.995 | 1.9 | 0.977 | 0.980 | 6.9 | 16×21 | 7.725 × 7.46 |
| pip | 0.997 | 1.6 | 0.982 | 0.990 | 5.9 | 18×21 | 7.64 × 7.34 |
| gloop | 0.997 | 1.3 | 0.975 | 0.985 | 5.0 | 15×19 | 7.76 × 7.85 |
| barnaby | 0.995 | 1.7 | 0.988 | 0.992 | 6.5 | 21×20 | 7.55 × 7.87 |
| fig | 0.995 | 1.3 | 0.965 | 0.979 | 4.5 | 17×23 | 7.3 × 7.42 |
| poko | 0.996 | 1.1 | 0.966 | 0.976 | 4.8 | 20×20 | 7.13 × 7.29 |
| crush | 0.996 | 1.7 | 0.970 | 0.981 | 3.9 | 18×17 | 7.72 × 7.68 |
| fizz | 0.994 | 1.2 | 0.957 | 0.966 | 5.1 | 22×20 | 7.6 × 7.76 |
| otto | 0.996 | 1.9 | 0.953 | 0.964 | 9.9 | 20×18 | 8.14 × 8.04 |
| bram | 0.997 | 1.7 | 0.971 | 0.981 | 4.9 | 17×22 | 7.56 × 7.545 |
| breeze | 0.993 | 1.0 | 0.980 | 0.984 | 5.7 | 20×22 | 7.67 × 7.67 |
| ziggy | 0.997 | 1.0 | 0.958 | 0.971 | 7.0 | 21×20 | 7.2 × 7.22 |
| toby | 0.996 | 1.7 | 0.993 | 0.994 | 5.4 | 20×16 | 7.65 × 7.65 |
| **mean** | 0.996 | 1.5 | 0.973 | 0.982 | 5.8 | | |

- **Smooth:** all 15 clear the 0.97 target.
- **Pixel:** only toby clears 0.99 on a uniform grid.
  - The rest lose 1–5% to the reference's own drift. Its cell edges are up to 2 px off any single grid, which a real pixel sprite can't follow.
  - On the sheet's recovered grid, 4 of 15 reach 0.99 (beepo, sprout, barnaby, toby).
  - Pixel ΔE is higher than smooth ΔE because the reference's soft eyes, blush and edges become solid cells.
- See `comparison.png` and judge by eye too.

## Animations

| Mood | Smooth | Pixel |
|---|---|---|
| idle | still | still |
| blink | eyes scale Y to 10% and back, 120 ms closed | eyes swap to the closed row for 120 ms |
| look left / right | eye group moves ¾ of an eye width | eyes (and a one-pixel mouth) move one cell |
| hover | whole buddy lifts 4% of its height, 200 ms ease-out | lifts one cell |
| sleep | eyes held at 10% | closed row held |
| wake | eyes open, 120 ms | open eyes return |
| happy | eyes become arcs (^ ^); one hop of 10% height, 280 ms up and down | arc eyes; hop steps 1, 2, 2, 1, 0 cells, 56 ms each |

- Nothing distorts the body. Pixel buddies move in whole cells.
- Every motion is ≤ 300 ms. Timers run only while a motion plays.
- Reduced motion: changes happen without movement.

## Rebuild

```bash
mkdir -p /tmp/buddies-work && (cd /tmp/buddies-work && npm init -y >/dev/null && npm i sharp @resvg/resvg-js)
NODE_PATH=/tmp/buddies-work/node_modules brand/buddies/tools/run.sh /tmp/buddies-work
swift apps/mac/scripts/gen-buddies.swift   # regenerate apps/mac/Sources/Belay/Design/Buddies/BuddyArtwork.swift
```

The npm packages stay out of the repo. Their licences:
- `sharp` is Apache-2.0 and loads libvips, which is LGPL, as a dynamic library;
- `@resvg/resvg-js` is MPL-2.0.

## In the Mac app

`apps/mac/Sources/Belay/Design/Buddies/`:
- `BuddyView(id:style:mood:size:)` draws any buddy, in either style, at any size;
- `BuddyArtwork.swift` is generated from `buddies.json`.

`BrandSlot` (the notch) and Settings → About draw beepo.
