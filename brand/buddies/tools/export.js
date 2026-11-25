// Collect traced art into one data file, then write SVGs and PNGs for both styles.
const fs=require('fs');const path=require('path');const L=require('./lib');const {Resvg}=require('@resvg/resvg-js');
const DEST=process.argv[2]||'final';
const pm=JSON.parse(fs.readFileSync('out/pixel-meta.json'));const sm=JSON.parse(fs.readFileSync('out/smooth-meta.json'));
const r2=v=>Math.round(v*100)/100;
const data={source:{smooth:'ref-vector-sheet.png',pixel:'ref-pixel-sheet.png'},buddies:{}};
for(const nm of L.NAMES){
  // ---- smooth
  const svg=fs.readFileSync(`out/smooth/${nm}.svg`,'utf8');const vb=svg.match(/viewBox="0 0 (\S+) (\S+)"/).slice(1).map(Number);
  const layers=[];for(const m of svg.matchAll(/<path class="buddy-(\w+)" fill="(#\w+)"[^>]*?(clip-path="[^"]+")?[^>]*? d="([^"]+)"\/>/g)){if(m[0].includes('clipPath'))continue;layers.push({part:m[1],fill:m[2],d:m[4],clip:!!m[3]});}
  const eyesFill=svg.match(/<g class="buddy-eyes" fill="(#\w+)"/)[1];const rects=[...svg.matchAll(/<rect x="([\d.-]+)" y="([\d.-]+)" width="([\d.]+)" height="([\d.]+)"/g)].map(m=>({x:+m[1],y:+m[2],w:+m[3],h:+m[4]}));
  const smooth={viewBox:vb,cell:sm[nm].cell,origin:sm[nm].view.slice(0,2),layers,eyes:{fill:eyesFill,rects}};
  // ---- pixel
  const p=pm[nm];const W=p.W,H=p.H;const eyeSet=new Set(p.eyes.map(([y,x])=>y*W+x));const mouthSet=new Set((p.mouth||[]).map(([y,x])=>y*W+x));
  const comps=[];const seen=new Set();for(const k of eyeSet){if(seen.has(k))continue;const c=[k];seen.add(k);for(let i=0;i<c.length;i++){const y=Math.floor(c[i]/W),x=c[i]%W;for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const n=(y+dy)*W+x+dx;if(eyeSet.has(n)&&!seen.has(n)){seen.add(n);c.push(n);}}}comps.push(c.map(k=>[Math.floor(k/W),k%W]));}
  comps.sort((a,b)=>Math.min(...a.map(c=>c[1]))-Math.min(...b.map(c=>c[1])));
  const open=[],closed=[],happy=[];
  for(const c of comps){const ys=c.map(q=>q[0]),xs=c.map(q=>q[1]);const t=Math.min(...ys),b=Math.max(...ys),l=Math.min(...xs),r=Math.max(...xs);
    const cnt={};c.forEach(([y,x])=>{const v=p.grid[y][x];cnt[v]=(cnt[v]||0)+1;});
    // the eye's own colour: the most common, ignoring near-white glints
    const main=+Object.entries(cnt).sort((a,b)=>b[1]-a[1]).map(e=>e[0]).find(v=>{const h=p.pal[v];const s=[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));return !(Math.min(...s)>225);})??+Object.keys(cnt)[0];
    c.forEach(([y,x])=>open.push([x,y,p.grid[y][x]]));
    const h=b-t+1;if(nm==='pip'){continue;} // pip's glint just hides when it "blinks"
    const row=t+Math.floor(h/2)-(h%2?0:0)+(h===2?0:0);const crow=h===2?b:t+Math.floor((h-1)/2);for(let x=l;x<=r;x++)closed.push([x,crow,main]);
    for(let x=l;x<=r;x++)happy.push([x,t,main]);happy.push([l-1,t+1,main],[r+1,t+1,main]);}
  const pixel={size:[W,H],cell:p.cell,grid:{x:{p:p.gx.p,o:p.gx.o+p.c0*p.gx.p},y:{p:p.gy.p,o:p.gy.o+p.r0*p.gy.p}},palette:p.pal,
    rows:p.grid.map((row,y)=>row.map((v,x)=>eyeSet.has(y*W+x)||mouthSet.has(y*W+x)?(p.fill??v):v)),eyes:{open,closed,happy},mouth:(p.mouth||[]).map(([y,x])=>[x,y,p.grid[y][x]])};
  data.buddies[nm]={smooth,pixel,pixelEyeUnder:null};
}
module.exports={data};
if(require.main===module){fs.writeFileSync('out/buddies-data.json',JSON.stringify(data));console.log('ok',Object.keys(data.buddies).length);}
