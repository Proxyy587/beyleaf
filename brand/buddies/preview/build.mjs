#!/usr/bin/env node
/**
 * Builds preview/index.html: every buddy in both styles with every animation. Self-contained (works under file://).
 * Source of truth is ../buddies.json, written by tools/run.sh. Run: node brand/buddies/preview/build.mjs
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const dir = path.dirname(fileURLToPath(import.meta.url));
const data = JSON.parse(fs.readFileSync(path.join(dir, "..", "buddies.json"), "utf8"));
const slim = { names: Object.keys(data.buddies), buddies: data.buddies, metrics: data.metrics };

const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Belay buddies</title>
<style>
  :root { --ground:#F5F5F3; --card:#FFFFFF; --ink:#131316; --ink2:#5F5F63; --fill:rgba(19,19,22,.06); --fill2:rgba(19,19,22,.1); color-scheme: light; }
  :root[data-ground="notch"] { --ground:#000000; --card:#0F0F10; --ink:#F5F5F3; --ink2:#A3A3A0; --fill:rgba(245,245,243,.08); --fill2:rgba(245,245,243,.14); color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin:0; font: 13px/1.4 -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif; background:var(--ground); color:var(--ink); }
  header { position:sticky; top:0; z-index:2; display:flex; flex-wrap:wrap; gap:8px 16px; align-items:center; padding:12px 16px; background:var(--ground); }
  h1 { font-size:15px; font-weight:600; margin:0 8px 0 0; }
  .group { display:flex; flex-wrap:wrap; gap:4px; align-items:center; }
  .label { color:var(--ink2); margin-right:4px; }
  button { appearance:none; border:0; font:inherit; padding:6px 12px; border-radius:999px; background:var(--fill); color:var(--ink); cursor:pointer; }
  button:hover { background:var(--fill2); }
  button[aria-pressed="true"] { background:var(--ink); color:var(--ground); }
  input[type=range] { width:120px; }
  main { display:grid; grid-template-columns:repeat(auto-fill,minmax(var(--cardw),1fr)); gap:12px; padding:4px 16px 24px; }
  .card { background:var(--card); border-radius:12px; padding:12px; display:flex; flex-direction:column; align-items:center; gap:8px; }
  .row { display:flex; gap:12px; align-items:flex-end; justify-content:center; }
  .stage { width:var(--size); height:var(--size); position:relative; cursor:pointer; }
  .stage svg { position:absolute; inset:0; width:100%; height:100%; overflow:visible; }
  .pixel svg { image-rendering: pixelated; }
  .name { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size:12px; }
  .score { color:var(--ink2); font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size:10px; text-align:center; }
  footer { color:var(--ink2); padding:0 16px 24px; max-width:760px; }
  /* smooth motion: eyes only scale Y (blink, sleep) or translate X (look); the body only translates (hover, hop) */
  .smooth .eyes { transform-box: fill-box; transform-origin: center; transition: transform 120ms cubic-bezier(.22,1,.36,1); }
  .smooth .lift { transition: transform 200ms cubic-bezier(.22,1,.36,1); }
  @media (prefers-reduced-motion: reduce) { .smooth .eyes, .smooth .lift { transition: none !important; } }
</style>
</head>
<body>
<header>
  <h1>Belay buddies</h1>
  <div class="group" id="styles"><span class="label">Style</span></div>
  <div class="group" id="moods"><span class="label">Animate all</span></div>
  <div class="group"><span class="label">Size</span><input id="size" type="range" min="16" max="256" value="96"><span id="sizev" class="label">96</span></div>
  <div class="group" id="grounds"><span class="label">Ground</span></div>
</header>
<main id="grid"></main>
<footer>Hover a buddy to lift it, click to blink, double-click for a happy hop. Blink and sleep scale the eyes vertically; look moves the eyes only (a pixel buddy's one-pixel mouth moves with them, so the face stays readable); hover and hop move the whole buddy. Pixel buddies move in whole pixels. Every motion is 300 ms or less, and nothing moves at rest. With Reduce Motion on, changes happen without movement. Scores: silhouette IoU and mean colour difference (CIE ΔE76) against the reference sheet (see ../comparison.png).</footer>
<script>
const DATA = ${JSON.stringify(slim)};
const NS = "http://www.w3.org/2000/svg";
const reduce = matchMedia("(prefers-reduced-motion: reduce)");
const el = (n, a = {}, kids = []) => { const e = document.createElementNS(NS, n); for (const k in a) e.setAttribute(k, a[k]); kids.forEach(c => e.appendChild(c)); return e; };
const metric = Object.fromEntries(DATA.metrics.map(m => [m.name, m]));

function happyArc(e) { const cx = e.x + e.w / 2, cy = e.y + e.h / 2, a = e.w * 0.95, up = e.h * 0.42, dn = e.h * 0.12;
  return "M" + (cx - a) + " " + (cy + dn) + "Q" + cx + " " + (cy - up - dn) + " " + (cx + a) + " " + (cy + dn); }

function smooth(name) {
  const s = DATA.buddies[name].smooth, [w, h] = s.viewBox;
  const svg = el("svg", { viewBox: "0 0 " + w + " " + h, role: "img", "aria-label": name });
  const lift = el("g", { class: "lift" });
  const body = s.layers[0];
  if (s.layers.some(l => l.clip)) svg.appendChild(el("defs", {}, [el("clipPath", { id: name + "-clip" }, [el("path", { d: body.d })])]));
  s.layers.forEach(l => lift.appendChild(el("path", Object.assign({ fill: l.fill, d: l.d }, l.clip ? { "clip-path": "url(#" + name + "-clip)" } : {}))));
  const eyes = el("g", { class: "eyes", fill: s.eyes.fill });
  s.eyes.rects.forEach(e => eyes.appendChild(el("rect", { x: e.x, y: e.y, width: e.w, height: e.h, rx: e.w / 2 })));
  const happy = el("g", { fill: "none", stroke: s.eyes.fill, "stroke-width": s.eyes.rects[0].w * 0.78, "stroke-linecap": "round", display: "none" });
  s.eyes.rects.forEach(e => happy.appendChild(el("path", { d: happyArc(e) })));
  lift.append(eyes, happy); svg.appendChild(lift);
  const look = s.eyes.rects[0].w * 0.75, hop = h * 0.1, rise = h * 0.04;
  return { svg, kind: "smooth", apply(st) {
    eyes.setAttribute("display", st.happy ? "none" : "inline"); happy.setAttribute("display", st.happy ? "inline" : "none");
    const dx = st.look * look, sy = st.closed ? 0.1 : 1;
    eyes.style.transform = "translateX(" + dx + "px) scaleY(" + sy + ")";
    lift.style.transform = "translateY(" + (-(st.hover ? rise : 0) - st.hop * hop) + "px)";
  } };
}

function pixel(name) {
  const p = DATA.buddies[name].pixel, [W, H] = p.size;
  const svg = el("svg", { viewBox: "0 -3 " + W + " " + (H + 3), "shape-rendering": "crispEdges", role: "img", "aria-label": name });
  const runs = (cells) => { const g = el("g"); const by = {}; cells.forEach(([x, y, v]) => { (by[v] = by[v] || []).push("M" + x + " " + y + "h1v1h-1z"); });
    for (const v in by) g.appendChild(el("path", { fill: p.palette[v], d: by[v].join("") })); return g; };
  const bodyCells = []; p.rows.forEach((r, y) => r.forEach((v, x) => { if (v >= 0) bodyCells.push([x, y, v]); }));
  const lift = el("g"); const open = runs(p.eyes.open), closed = runs(p.eyes.closed), happy = runs(p.eyes.happy), mouth = runs(p.mouth);
  lift.append(runs(bodyCells), mouth, open, closed, happy); svg.appendChild(lift);
  return { svg, kind: "pixel", apply(st) {
    open.style.display = !st.closed && !st.happy ? "" : "none"; closed.style.display = st.closed && !st.happy ? "" : "none"; happy.style.display = st.happy ? "" : "none";
    const dx = Math.round(st.look); open.setAttribute("transform", "translate(" + dx + " 0)"); closed.setAttribute("transform", "translate(" + dx + " 0)"); mouth.setAttribute("transform", "translate(" + dx + " 0)");
    lift.setAttribute("transform", "translate(0 " + -((st.hover ? 1 : 0) + Math.round(st.hop * 2)) + ")");
  } };
}

// One buddy's state machine. Timers run only while a motion plays, then stop.
function buddy(views) {
  const st = { look: 0, closed: false, hover: false, happy: false, hop: 0, sleeping: false };
  let t = [];
  const clear = () => { t.forEach(clearTimeout); t = []; };
  const at = (ms, f) => t.push(setTimeout(() => { f(); draw(); }, ms));
  const draw = () => views.forEach(v => v.apply(st));
  const api = {
    idle() { clear(); Object.assign(st, { look: 0, closed: false, happy: false, hop: 0, sleeping: false }); draw(); },
    blink() { if (st.sleeping) return; clear(); st.closed = true; draw(); at(120, () => { st.closed = false; }); },
    look(d) { if (st.sleeping) return; clear(); st.happy = false; st.look = d; draw(); },
    hover(on) { st.hover = on; draw(); },
    sleep() { clear(); Object.assign(st, { sleeping: true, closed: true, look: 0, happy: false }); draw(); },
    wake() { clear(); st.sleeping = false; st.closed = false; draw(); },
    happy() { clear(); Object.assign(st, { sleeping: false, closed: false, look: 0, happy: true }); draw();
      if (reduce.matches) { at(600, () => { st.happy = false; }); return; }
      // the hop: up and back down in 280 ms; pixel buddies step through whole pixels (0, 1, 2, 1, 0)
      const frames = [0.5, 1, 1, 0.5, 0]; frames.forEach((h, i) => at(56 * (i + 1), () => { st.hop = h; }));
      at(900, () => { st.happy = false; }); },
  };
  api.freeze = (patch) => { clear(); Object.assign(st, patch); draw(); };
  draw(); return api;
}

const state = { style: "both", size: 96 };
const all = [];
function render() {
  const grid = document.getElementById("grid"); grid.innerHTML = ""; all.length = 0;
  document.documentElement.style.setProperty("--size", state.size + "px");
  document.documentElement.style.setProperty("--cardw", Math.max(140, (state.style === "both" ? 2 : 1) * state.size + 48) + "px");
  for (const name of DATA.names) {
    const card = document.createElement("div"); card.className = "card";
    const row = document.createElement("div"); row.className = "row";
    const views = []; const scores = [];
    for (const kind of ["smooth", "pixel"]) {
      if (state.style !== "both" && state.style !== kind) continue;
      const v = kind === "smooth" ? smooth(name) : pixel(name); views.push(v);
      const stage = document.createElement("div"); stage.className = "stage " + kind; stage.appendChild(v.svg); row.appendChild(stage);
      const m = metric[name][kind]; scores.push(kind + " IoU " + m.iou.toFixed(3) + " ΔE " + m.dE.toFixed(1));
    }
    const b = buddy(views); all.push(b);
    row.addEventListener("mouseenter", () => b.hover(true)); row.addEventListener("mouseleave", () => b.hover(false));
    row.addEventListener("click", () => b.blink()); row.addEventListener("dblclick", () => b.happy());
    const n = document.createElement("div"); n.className = "name"; n.textContent = name;
    const sc = document.createElement("div"); sc.className = "score"; sc.innerHTML = scores.join("<br>");
    card.append(row, n, sc); grid.appendChild(card);
  }
}
function buttons(id, items, onPick, pressed) {
  const g = document.getElementById(id);
  items.forEach(([label, val]) => { const b = document.createElement("button"); b.textContent = label; b.dataset.val = val;
    if (pressed !== undefined) b.setAttribute("aria-pressed", String(val === pressed));
    b.onclick = () => { if (pressed !== undefined) g.querySelectorAll("button").forEach(x => x.setAttribute("aria-pressed", String(x === b))); onPick(val); }; g.appendChild(b); });
}
buttons("styles", [["Both", "both"], ["Smooth", "smooth"], ["Pixel", "pixel"]], v => { state.style = v; render(); }, "both");
buttons("moods", [["Idle", "idle"], ["Blink", "blink"], ["Look left", "left"], ["Look right", "right"], ["Hover", "hover"], ["Sleep", "sleep"], ["Wake", "wake"], ["Happy hop", "happy"]], v => {
  all.forEach(b => { if (v === "left") b.look(-1); else if (v === "right") b.look(1); else if (v === "hover") { b.hover(true); setTimeout(() => b.hover(false), 900); } else b[v](); }); });
buttons("grounds", [["Light", "light"], ["Notch black", "notch"]], v => { document.documentElement.dataset.ground = v; }, "light");
const size = document.getElementById("size");
size.oninput = () => { state.size = +size.value; document.getElementById("sizev").textContent = size.value; render(); };
render();
// Review aid: index.html?freeze=closed|happy|left|right|hover|hop holds one state on every buddy.
const freeze = new URLSearchParams(location.search).get("freeze");
const frozen = { closed: { closed: true }, happy: { happy: true }, left: { look: -1 }, right: { look: 1 }, hover: { hover: true }, hop: { happy: true, hop: 1 } }[freeze];
if (frozen) all.forEach(b => b.freeze(frozen));
</script>
</body>
</html>
`;
fs.writeFileSync(path.join(dir, "index.html"), html);
console.log("wrote", path.join(dir, "index.html"), (html.length / 1024).toFixed(0) + " KB");
