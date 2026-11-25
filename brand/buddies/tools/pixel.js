const fs=require('fs');const L=require('./lib');const {sprite}=require('./select');
const BG=[243,240,233];

function palette(im,s,limit=16){const pts=[];for(let y=0;y<s.H;y++)for(let x=0;x<s.W;x++)if(s.fg[y*s.W+x])pts.push(im.px(s.x0+x,s.y0+y));
  let rem=pts.slice();const cents=[];
  while(cents.length<limit&&rem.length>pts.length*0.004){const hh=new Map();for(const c of rem){const k=c.map(v=>v>>3).join(',');hh.set(k,(hh.get(k)||0)+1);}
    let bk=null,bn=0;for(const [k] of hh){const [r,g,b]=k.split(',').map(Number);let t=0;for(let dr=-1;dr<=1;dr++)for(let dg=-1;dg<=1;dg++)for(let db=-1;db<=1;db++)t+=hh.get([r+dr,g+dg,b+db].join(','))||0;if(t>bn){bn=t;bk=[r,g,b];}}
    const c=bk.map(v=>v*8+4);const near=rem.filter(q=>L.dist(q,c)<22);if(near.length<pts.length*0.003)break;cents.push(c);rem=rem.filter(q=>L.dist(q,c)>=22);}
  for(let it=0;it<6;it++){const acc=cents.map(()=>[0,0,0,0]);for(const c of pts){let bi=0,bd=1e9;cents.forEach((m,i)=>{const d=L.dist(c,m);if(d<bd){bd=d;bi=i;}});if(bd<26){acc[bi][0]+=c[0];acc[bi][1]+=c[1];acc[bi][2]+=c[2];acc[bi][3]++;}}acc.forEach((a,i)=>{if(a[3])cents[i]=[a[0]/a[3],a[1]/a[3],a[2]/a[3]];});}
  return cents.map(c=>c.map(Math.round));}
function alphaMap(im,s,pal){const N=s.W*s.H;const A=new Float32Array(N);const cls=new Int16Array(N).fill(-1);
  const reg=new Uint8Array(N);for(let y=0;y<s.H;y++)for(let x=0;x<s.W;x++)if(s.fg[y*s.W+x])for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){const X=x+dx,Y=y+dy;if(X>=0&&Y>=0&&X<s.W&&Y<s.H)reg[Y*s.W+X]=1;}
  for(let k=0;k<N;k++){if(!reg[k])continue;const c=im.px(s.x0+k%s.W,s.y0+((k/s.W)|0));let best={e:1e9,t:0,j:-1};
    pal.forEach((P,j)=>{const d=[P[0]-BG[0],P[1]-BG[1],P[2]-BG[2]];const dd=d[0]**2+d[1]**2+d[2]**2;let t=((c[0]-BG[0])*d[0]+(c[1]-BG[1])*d[1]+(c[2]-BG[2])*d[2])/dd;t=Math.max(0,Math.min(1,t));const e=L.dist(c,[BG[0]+t*d[0],BG[1]+t*d[1],BG[2]+t*d[2]]);if(e<best.e)best={e,t,j};});
    // if the pixel is in the flood-fill background, alpha 0 unless strongly coloured
    A[k]=s.fg[k]?Math.max(best.t, L.dist(c,BG)>60?1:0):best.t*(best.t>0.5?1:0);cls[k]=best.j;}
  return {A,cls};}
function sampleGrid(im,s,pal,gx,gy){const cols=Math.ceil((gx.end-gx.o)/gx.p),rows=Math.ceil((gy.end-gy.o)/gy.p);const grid=[];
  for(let r=0;r<rows;r++){const row=[];for(let c=0;c<cols;c++){const X0=gx.o+c*gx.p,X1=X0+gx.p,Y0=gy.o+r*gy.p,Y1=Y0+gy.p;const m=1.6;
      const cnt=new Array(pal.length+1).fill(0);
      for(let y=Math.ceil(Y0+m);y<Y1-m;y++)for(let x=Math.ceil(X0+m);x<X1-m;x++){if(x<0||y<0||x>=s.W||y>=s.H){cnt[pal.length]++;continue;}const k=y*s.W+x;if(!s.fg[k]){cnt[pal.length]++;continue;}const p=im.px(s.x0+x,s.y0+y);let bi=0,bd=1e9;pal.forEach((q,j)=>{const d=L.dist(p,q);if(d<bd){bd=d;bi=j;}});cnt[bi]++;}
      let bi=pal.length;cnt.forEach((v,j)=>{if(v>cnt[bi]||(bi===pal.length&&v>=cnt[bi]&&j<pal.length&&v>0&&v>=cnt[pal.length]))bi=j;});row.push(bi===pal.length?-1:bi);}grid.push(row);}
  return {grid,cols,rows};}
function warpLines(E,G,n){const mx=Math.max(...E);const L=[];for(let k=0;k<=n;k++){const base=G.o+k*G.p;let best=base,bs=0.04*mx;for(let b=Math.ceil(base-3);b<=Math.floor(base+3);b++){if(b<0||b>=E.length)continue;const sc=E[b]-0.03*mx*(b-base)**2;if(sc>bs){bs=sc;best=b;}}L.push(best);}
  for(let k=1;k<L.length;k++)if(L[k]<=L[k-1]+3)L[k]=L[k-1]+G.p;return L;}
function sampleWarp(im,s,pal,LX,LY){const grid=[];for(let r=0;r<LY.length-1;r++){const row=[];for(let c=0;c<LX.length-1;c++){const X0=LX[c],X1=LX[c+1],Y0=LY[r],Y1=LY[r+1];const m=1.5;const cnt=new Array(pal.length+1).fill(0);
    for(let y=Math.ceil(Y0+m);y<Y1-m;y++)for(let x=Math.ceil(X0+m);x<X1-m;x++){if(x<0||y<0||x>=s.W||y>=s.H){cnt[pal.length]++;continue;}const k=y*s.W+x;if(!s.fg[k]){cnt[pal.length]++;continue;}const p=im.px(s.x0+x,s.y0+y);let bi=0,bd=1e9;pal.forEach((q,j)=>{const d=L.dist(p,q);if(d<bd){bd=d;bi=j;}});cnt[bi]++;}
    let bi=pal.length;for(let j=0;j<pal.length;j++)if(cnt[j]>0&&cnt[j]>=cnt[bi]&&(bi===pal.length||cnt[j]>cnt[bi]))bi=j;row.push(bi===pal.length?-1:bi);}grid.push(row);}return {grid,cols:LX.length-1,rows:LY.length-1};}
function iouWarp(s,A,g,LX,LY){const cx=x=>{for(let c=0;c<LX.length-1;c++)if(x>=LX[c]&&x<LX[c+1])return c;return -1;},cy=y=>{for(let r=0;r<LY.length-1;r++)if(y>=LY[r]&&y<LY[r+1])return r;return -1;};
  let I=0,U=0;for(let y=0;y<s.H;y++){const r=cy(y+0.5);for(let x=0;x<s.W;x++){const a=A[y*s.W+x]>=0.5;const c=cx(x+0.5);const b=r>=0&&c>=0&&g.grid[r][c]>=0;if(a&&b)I++;if(a||b)U++;}}return I/U;}
function iou(s,A,g,gx,gy){let I=0,U=0;for(let y=0;y<s.H;y++)for(let x=0;x<s.W;x++){const a=A[y*s.W+x]>=0.5;const c=Math.floor((x+0.5-gx.o)/gx.p),r=Math.floor((y+0.5-gy.o)/gy.p);const b=r>=0&&c>=0&&r<g.rows&&c<g.cols&&g.grid[r][c]>=0;if(a&&b)I++;if(a||b)U++;}return I/U;}
function fitAxis(E,lo,hi,p0){let best={s:-1};for(let p=p0-0.35;p<=p0+0.35;p+=0.005)for(let ph=0;ph<p;ph+=0.05){let sc=0;for(let b=0;b<E.length;b++){if(!E[b])continue;let d=((b-ph)%p+p)%p;if(d>p/2)d=p-d;sc+=E[b]*Math.exp(-d*d/0.5);}if(sc>best.s)best={s:sc,p,ph};}
  // first grid line at or before lo
  let o=best.ph;while(o>lo+0.5)o-=best.p;while(o+best.p<=lo+0.5)o+=best.p;return {p:best.p,o,end:hi+1};}
function solve(im,i){const s=sprite(im,i,true);const W=s.W,H=s.H;const pal=palette(im,s);const {A}=alphaMap(im,s,pal);
  let x0=W,y0=H,x1=0,y1=0;for(let k=0;k<W*H;k++)if(A[k]>=0.5){const x=k%W,y=(k/W)|0;x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);}
  const Ex=new Float64Array(W+1),Ey=new Float64Array(H+1);
  for(let y=1;y<H;y++)for(let x=1;x<W;x++){const k=y*W+x;if(s.fg[k]||s.fg[k-1])Ex[x]+=L.dist(im.px(s.x0+x,s.y0+y),im.px(s.x0+x-1,s.y0+y));if(s.fg[k]||s.fg[k-W])Ey[y]+=L.dist(im.px(s.x0+x,s.y0+y),im.px(s.x0+x,s.y0+y-1));}
  let gx=fitAxis(Ex,x0,x1,7.5),gy=fitAxis(Ey,y0,y1,7.5);
  // square pixels: try shared pitch too, and local refinement maximizing IoU
  let best={v:-1};
  const cands=[];for(const p of [gx.p,gy.p,(gx.p+gy.p)/2])cands.push(p);
  const tryG=(px,ox,py,oy)=>{const GX={p:px,o:ox,end:x1+1},GY={p:py,o:oy,end:y1+1};const g=sampleGrid(im,s,pal,GX,GY);const v=iou(s,A,g,GX,GY);if(v>best.v)best={v,GX,GY,g};};
  for(const p of cands){const fx=fitAxis(Ex,x0,x1,p),fy=fitAxis(Ey,y0,y1,p);}
  // wide search for a square pitch, then refine each axis (the reference's pitch differs per sprite, 7.2-8.0 px)
  {let b={v:-1};const ev=(px,ox,py,oy)=>{tryG(px,ox,py,oy);};for(let p=7.0;p<=8.2;p+=0.05)for(let ox=x0-p;ox<=x0+0.01;ox+=p/6)for(let oy=y0-p;oy<=y0+0.01;oy+=p/6)tryG(p,ox,p,oy);
   for(let it=0;it<3;it++){const B=best;for(let px=B.GX.p-0.3;px<=B.GX.p+0.3;px+=0.02)for(let d=-1;d<=1;d+=0.25)tryG(px,B.GX.o+d,B.GY.p,B.GY.o);const C=best;for(let py=C.GY.p-0.3;py<=C.GY.p+0.3;py+=0.02)for(let d=-1;d<=1;d+=0.25)tryG(C.GX.p,C.GX.o,py,C.GY.o+d);}}
  // fine
  const b0=best;for(let dpx=-0.03;dpx<=0.031;dpx+=0.015)for(let dpy=-0.03;dpy<=0.031;dpy+=0.015)for(let dox=-0.3;dox<=0.31;dox+=0.15)for(let doy=-0.3;doy<=0.31;doy+=0.15)tryG(b0.GX.p+dpx,b0.GX.o+dox,b0.GY.p+dpy,b0.GY.o+doy);
  let LX=[],LY=[];for(let k=0;k<=best.g.cols;k++)LX.push(best.GX.o+k*best.GX.p);for(let k=0;k<=best.g.rows;k++)LY.push(best.GY.o+k*best.GY.p);
  // fast IoU on warped lines using precomputed per-pixel row/col lookup
  const evalW=(LX,LY)=>{const g=sampleWarp(im,s,pal,LX,LY);return [iouWarp(s,A,g,LX,LY),g];};
  let cur=evalW(LX,LY)[0];
  for(let pass=0;pass<3;pass++){for(const [Ls,n] of [[LX,0],[LY,1]]){for(let k=0;k<Ls.length;k++){const orig=Ls[k];const P=n?best.GY.p:best.GX.p;const base=(n?best.GY.o:best.GX.o)+k*P;let bv=cur,bp=orig;for(const d of [-1,-0.5,0.5,1]){const v=orig+d;if(Math.abs(v-base)>1.6)continue;if(k>0&&(v-Ls[k-1]<P-1.6||v-Ls[k-1]>P+1.6))continue;if(k<Ls.length-1&&(Ls[k+1]-v<P-1.6||Ls[k+1]-v>P+1.6))continue;Ls[k]=v;const sc=evalW(LX,LY)[0];if(sc>bv+1e-6){bv=sc;bp=v;}}Ls[k]=bp;cur=bv;}}}
  const gw=sampleWarp(im,s,pal,LX,LY);
  const vw=iouWarp(s,A,gw,LX,LY);const vu=iou(s,A,gw,best.GX,best.GY);
  return {s,pal,A,...best,LX,LY,gw,vw,vu};}
module.exports={solve,BG,sampleGrid,iou,palette,alphaMap};
if(require.main===module)(async()=>{const im=await L.load(L.R+'/ref-pixel-sheet.png');const only=process.argv[2];const out={};
 for(let i=0;i<15;i++){const nm=L.NAMES[i];if(only&&nm!==only)continue;const r=solve(im,i);
  console.log(nm.padEnd(8),r.g.cols+'x'+r.g.rows,'p',r.GX.p.toFixed(3),r.GY.p.toFixed(3),'IoU uniform',r.v.toFixed(4),'warp',r.vw.toFixed(4),'(warp-sampled on uniform',r.vu.toFixed(4)+')','pal',r.pal.length);
  out[nm]={cell:[r.s.x0,r.s.y0],gx:r.GX,gy:r.GY,LX:r.LX,LY:r.LY,pal:r.pal.map(L.hex),grid:r.gw.grid,gridU:r.g.grid};
  if(only){const ch='ABCDEFGHIJKLMNOPQ';console.log(r.pal.map((c,j)=>ch[j]+L.hex(c)).join(' '));for(const row of r.gw.grid)console.log(row.map(v=>v<0?'.':ch[v]).join(''));}}
 if(!only)fs.writeFileSync('out/pixel-raw.json',JSON.stringify(out));
})();
