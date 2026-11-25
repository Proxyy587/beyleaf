// pixel-raw.json (+ optional cleanup.json edits) -> out/pixel/*.svg + out/pixel-meta.json
const fs=require('fs');const L=require('./lib');
(async()=>{const raw=JSON.parse(fs.readFileSync('out/pixel-raw.json'));const fix=require('./pixfix.js');const f0={};await fix.init();const meta={};
fs.mkdirSync('out/pixel',{recursive:true});
for(const nm of L.NAMES){const r=raw[nm];let grid=r.grid.map(row=>row.slice());let pal=r.pal.slice();
  // 1) merge palette entries that differ only by sampling noise
  {const h2=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));const cnt=pal.map(()=>0);grid.flat().forEach(v=>{if(v>=0)cnt[v]++;});const map=pal.map((_,i)=>i);
   const order=pal.map((_,i)=>i).sort((a,b)=>cnt[b]-cnt[a]);for(const i of order){if(map[i]!==i)continue;for(const j of order){if(j===i||map[j]!==j||cnt[j]>cnt[i])continue;if(L.dist(h2(pal[i]),h2(pal[j]))<20&&!(f0[nm]&&f0[nm].keep&&f0[nm].keep.includes(pal[j])))map[j]=i;}}
   grid=grid.map(row=>row.map(v=>v<0?v:map[v]));
  // 2) border cells that are just a blend of a sprite colour with the background
   const BG=[243,240,233];const H0=grid.length,W0=grid[0].length;const isBorder=(y,x)=>[[1,0],[-1,0],[0,1],[0,-1]].some(([dy,dx])=>{const Y=y+dy,X=x+dx;return Y<0||X<0||Y>=H0||X>=W0||grid[Y][X]<0;});
   const out=grid.map(r=>r.slice());for(let y=0;y<H0;y++)for(let x=0;x<W0;x++){const v=grid[y][x];if(v<0||!isBorder(y,x))continue;const c=h2(pal[v]);let best=null;
     pal.forEach((P,j)=>{if(j===v||!cnt[j])return;const Q=h2(P);const d=[Q[0]-BG[0],Q[1]-BG[1],Q[2]-BG[2]];const dd=d[0]**2+d[1]**2+d[2]**2;const t=((c[0]-BG[0])*d[0]+(c[1]-BG[1])*d[1]+(c[2]-BG[2])*d[2])/dd;if(t<0.15||t>0.85)return;const e=L.dist(c,[BG[0]+t*d[0],BG[1]+t*d[1],BG[2]+t*d[2]]);if(e<12&&(!best||e<best.e))best={e,t,j};});
     if(best&&!process.env.NOCLEAN)out[y][x]=best.t>=0.5?map[best.j]:-1;
     else if(L.dist(c,BG)<45)out[y][x]=-1;} // a near-background speck on the edge
   grid=out;}
  const f=fix.get(nm)||{};if(f.apply){({grid,pal}=f.apply(grid,pal));if(f.report)console.log(nm,JSON.stringify(f.report));}
  if(fix.post&&fix.post[nm])({grid,pal}=fix.post[nm](grid,pal));
  // trim
  let r0=1e9,r1=-1,c0=1e9,c1=-1;grid.forEach((row,y)=>row.forEach((v,x)=>{if(v>=0){r0=Math.min(r0,y);r1=Math.max(r1,y);c0=Math.min(c0,x);c1=Math.max(c1,x);}}));
  const G=grid.slice(r0,r1+1).map(row=>row.slice(c0,c1+1));const H=G.length,W=G[0].length;
  const eyes=new Set((f.eyes||[]).map(([y,x])=>(y-r0)*W+(x-c0)));const mouth=new Set((f.mouth||[]).map(([y,x])=>(y-r0)*W+(x-c0)));
  const under=f.under||{}; // eye cell -> colour index shown when the eye moves/closes
  const runs=(pred)=>{const byCol={};G.forEach((row,y)=>{let x=0;while(x<W){const v=row[x];if(v<0||!pred(y,x)){x++;continue;}let e=x;while(e+1<W&&row[e+1]===v&&pred(y,e+1))e++;(byCol[v]=byCol[v]||[]).push(`M${x} ${y}h${e-x+1}v1h-${e-x+1}z`);x=e+1;}});return byCol;};
  const bodyG=G.map((row,y)=>row.map((v,x)=>eyes.has(y*W+x)?(f.fill??v):v));
  const bodyRuns={};bodyG.forEach((row,y)=>{let x=0;while(x<W){const v=row[x];if(v<0){x++;continue;}let e=x;while(e+1<W&&row[e+1]===v)e++;(bodyRuns[v]=bodyRuns[v]||[]).push(`M${x} ${y}h${e-x+1}v1h-${e-x+1}z`);x=e+1;}});
  const eyeRuns=runs((y,x)=>eyes.has(y*W+x));
  const paths=(o,cls)=>Object.entries(o).map(([v,d])=>`    <path fill="${pal[v]}" d="${d.join('')}"/>`).join('\n');
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W*8}" height="${H*8}" shape-rendering="crispEdges" data-buddy="${nm}" data-style="pixel">\n  <title>${nm}</title>\n  <g class="buddy-body">\n${paths(bodyRuns)}\n  </g>\n  <g class="buddy-eyes">\n${paths(eyeRuns)}\n  </g>\n</svg>\n`;
  fs.writeFileSync(`out/pixel/${nm}.svg`,svg);
  meta[nm]={cell:r.cell,gx:r.gx,gy:r.gy,LX:r.LX,LY:r.LY,c0,r0,W,H,pal,grid:G,eyes:[...eyes].map(k=>[Math.floor(k/W),k%W]),fill:f.fill,mouth:[...mouth].map(k=>[Math.floor(k/W),k%W])};}
fs.writeFileSync('out/pixel-meta.json',JSON.stringify(meta));})();
