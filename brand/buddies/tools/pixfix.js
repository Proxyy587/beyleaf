// Face features: the reference draws eyes, mouths and blush as smooth shapes that ignore its own grid.
// Measure each feature in the reference, then stamp a clean, grid-aligned version (eyes 2x3, mouth/blush 1 row).
const fs=require('fs');const L=require('./lib');
let IM=null;const raw=JSON.parse(fs.readFileSync(process.cwd()+'/out/pixel-raw.json'));
const h2=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));
// region: [r0,r1,c0,c1] in sampled-grid cells; eye/mouth/blush: approximate colours to measure in the reference
const CFG={
 beepo:{face:'#9A60DC',eye:'#5A2C8A',blush:'#E28ADF',region:[10,16,4,17]},
 sprout:{face:'#47BB63',eye:'#1E7038',mouth:true,blush:'#D4A2A0',region:[13,19,2,13]},
 willo:{face:'#FCD14B',eye:'#BA6A05',region:[12,18,4,13]},
 gloop:{face:'#45ADA8',eye:'#17605F',mouth:true,blush:'#D2A6BA',region:[11,17,3,13]},
 barnaby:{face:'#1C2D61',eye:'#90E6F7',mouth:true,region:[8,13,6,16]},
 fig:{face:'#77244D',eye:'#350A1E',mouth:true,region:[13,17,3,15]},
 poko:{face:'#F88C2E',eye:'#8A2F02',mouth:'#C85A12',region:[7,12,3,16]},
 crush:{face:'#F17A9F',eye:'#B13A5E',mouth:true,region:[6,10,3,15]},
 fizz:{face:'#90E6BA',eye:'#3A805C',region:[10,14,4,19]},
 bram:{face:'#A87346',eye:'#44250B',region:[12,16,3,14]},
 breeze:{face:'#A7DAF5',eye:'#4889B0',region:[8,12,5,17],eyeOnly:true},
 ziggy:{face:'#FDD42C',eye:'#8D6101',mouth:true,region:[9,13,5,17]},
 toby:{face:'#172762',eye:'#81DBEC',mouth:true,region:[7,12,4,17]},
};
function cellOf(Ls,v){for(let c=0;c<Ls.length-1;c++)if(v>=Ls[c]&&v<Ls[c+1])return c+(v-Ls[c])/(Ls[c+1]-Ls[c]);return -1;}
function comps(r,colour,region,tol){const [cx,cy]=r.cell;const [r0,r1,c0,c1]=region;const X0=Math.floor(r.LX[c0]),X1=Math.ceil(r.LX[c1+1]),Y0=Math.floor(r.LY[r0]),Y1=Math.ceil(r.LY[r1+1]);
  const W=X1-X0,H=Y1-Y0;const m=new Uint8Array(W*H);for(let y=0;y<H;y++)for(let x=0;x<W;x++)m[y*W+x]=L.dist(IM.px(cx+X0+x,cy+Y0+y),colour)<tol?1:0;
  const lab=new Int32Array(W*H).fill(-1);const out=[];for(let k=0;k<W*H;k++){if(!m[k]||lab[k]>=0)continue;const q=[k];lab[k]=out.length;const px=[];for(let i=0;i<q.length;i++){const kk=q[i],x=kk%W,y=(kk/W)|0;px.push([x+X0,y+Y0]);for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){const X=x+dx,Y=y+dy;if(X<0||Y<0||X>=W||Y>=H)continue;const n=Y*W+X;if(m[n]&&lab[n]<0){lab[n]=out.length;q.push(n);}}}
    if(px.length<12)continue;let sx=0,sy=0,xa=1e9,xb=-1,ya=1e9,yb=-1,cs=[0,0,0];for(const [x,y] of px){sx+=x;sy+=y;xa=Math.min(xa,x);xb=Math.max(xb,x);ya=Math.min(ya,y);yb=Math.max(yb,y);const c=IM.px(cx+x,cy+y);cs[0]+=c[0];cs[1]+=c[1];cs[2]+=c[2];}
    out.push({n:px.length,x:sx/px.length+0.5,y:sy/px.length+0.5,w:xb-xa+1,h:yb-ya+1,bb:[xa,ya,xb+1,yb+1],col:cs.map(v=>Math.round(v/px.length))});}
  return out.sort((a,b)=>b.n-a.n);}
function palIndex(pal,hex){const c=h2(hex);let bi=-1,bd=1e9;pal.forEach((p,i)=>{const d=L.dist(h2(p),c);if(d<bd){bd=d;bi=i;}});if(bd<12)return bi;pal.push(hex);return pal.length-1;}
function build(nm){const cfg=CFG[nm];const r=raw[nm];
  return {apply(grid,pal){pal=pal.slice();grid=grid.map(x=>x.slice());const face=palIndex(pal,cfg.face);const p=(r.LX[r.LX.length-1]-r.LX[0])/(r.LX.length-1),q=(r.LY[r.LY.length-1]-r.LY[0])/(r.LY.length-1);
      const feats=[];const eyeC=comps(r,h2(cfg.eye),cfg.region,40);const eyes=eyeC.slice(0,2).sort((a,b)=>a.x-b.x);
      if(eyes.length<2)throw new Error(nm+': eyes not found');
      const eyeCol=L.hex(eyes[0].col.map((v,i)=>(v+eyes[1].col[i])/2));const ei=palIndex(pal,eyeCol);
      const ew=Math.max(1,Math.min(2,Math.round((eyes[0].w+eyes[1].w)/2/p))),eh=Math.max(2,Math.min(3,Math.round((eyes[0].h+eyes[1].h)/2/q)));
      const ecy=(cellOf(r.LY,eyes[0].y)+cellOf(r.LY,eyes[1].y))/2;const top=Math.round(ecy-eh/2);
      const eyeCells=[];
      // clear every cell touched by a measured feature
      const clear=(f)=>{const ca=Math.floor(cellOf(r.LX,f.bb[0]+0.5)),cb=Math.floor(cellOf(r.LX,f.bb[2]-0.5)),ra=Math.floor(cellOf(r.LY,f.bb[1]+0.5)),rb=Math.floor(cellOf(r.LY,f.bb[3]-0.5));for(let y=ra;y<=rb;y++)for(let x=ca;x<=cb;x++)if(grid[y]&&grid[y][x]>=0)grid[y][x]=face;};
      eyes.forEach(clear);
      let mouth=null,blush=[];
      if(cfg.mouth){const mc=comps(r,cfg.mouth===true?h2(cfg.eye):h2(cfg.mouth),cfg.region,cfg.mouth===true?40:30).filter(c=>c.y>eyes[0].y&&c.x>eyes[0].x&&c.x<eyes[1].x);mouth=mc[0];if(mouth)clear(mouth);}
      if(cfg.blush){blush=comps(r,h2(cfg.blush),cfg.region,30).slice(0,2);blush.forEach(clear);}
      for(const e of eyes){const left=Math.round(cellOf(r.LX,e.x)-ew/2);for(let y=top;y<top+eh;y++)for(let x=left;x<left+ew;x++){grid[y][x]=ei;eyeCells.push([y,x]);}}
      if(mouth){const mrow=Math.round(cellOf(r.LY,mouth.y)-0.5);const mw0=Math.max(1,Math.round(mouth.w/p)),ml0=Math.round(cellOf(r.LX,mouth.x)-mw0/2);const near=eyeCells.some(([y,x])=>x>=ml0-1&&x<=ml0+mw0);if(mrow<=top+eh&&mrow>=top&&near){const sh=top+eh-mrow+1;for(const c of eyeCells){grid[c[0]][c[1]]=face;}for(const c of eyeCells){c[0]-=sh;}for(const c of eyeCells)grid[c[0]][c[1]]=ei;}}
      if(mouth){const mw=Math.max(1,Math.round(mouth.w/p));const mi=palIndex(pal,L.hex(mouth.col));const row=Math.round(cellOf(r.LY,mouth.y)-0.5);const left=Math.round(cellOf(r.LX,mouth.x)-mw/2);this.mouth=[];for(let x=left;x<left+mw;x++){grid[row][x]=mi;this.mouth.push([row,x]);}}
      for(const b of blush){const bw=Math.max(1,Math.round(b.w/p));const bi=palIndex(pal,L.hex(b.col));const row=Math.round(cellOf(r.LY,b.y)-0.5);const left=Math.round(cellOf(r.LX,b.x)-bw/2);for(let x=left;x<left+bw;x++)grid[row][x]=bi;}
      this.eyes=eyeCells;this.fill=face;this.report={ew,eh,eyes:eyes.map(e=>[e.w,e.h]),mouth:mouth&&[mouth.w,mouth.h],blush:blush.map(b=>[b.w,b.h])};
      return {grid,pal};}};}
module.exports={post:{
  // the two status LEDs are smaller than one cell in the reference; give each its own cell in its own colour
  barnaby(g,p){p=p.slice();g=g.map(r=>r.slice());const gi=p.push('#4CAF6A')-1,ri=p.push('#D9534F')-1;const J=p.indexOf('#70788A');
    for(let y=12;y<g.length;y++){const xs=g[y].map((v,x)=>v===J?x:-1).filter(x=>x>=0);if(xs.length>=2){g[y][xs[0]]=gi;g[y][xs[1]]=ri;break;}}return {grid:g,pal:p};},
  // willo's outline is one orange; the darker cells on it are sampling noise (the darker orange is the eye colour)
  willo(g,p){g=g.map(r=>r.slice());const E=p.indexOf('#BA6A05'),M=p.indexOf('#E08623');const H=g.length,W=g[0].length;const border=(y,x)=>[[1,0],[-1,0],[0,1],[0,-1]].some(([dy,dx])=>{const Y=y+dy,X=x+dx;return Y<0||X<0||Y>=H||X>=W||g[Y][X]<0;});
    const o=g.map(r=>r.slice());for(let y=0;y<H;y++)for(let x=0;x<W;x++)if(g[y][x]===E&&border(y,x))o[y][x]=M;return {grid:o,pal:p};},
},get(nm){return CFG[nm]?build(nm):MANUAL[nm];}};
const MANUAL={
 // pip has no eyes; its visor glint is the animated part
 pip:{apply(g,p){this.eyes=[];g.forEach((row,y)=>row.forEach((v,x)=>{if(p[v]&&L.dist(h2(p[v]),[241,251,253])<20)this.eyes.push([y,x]);}));this.fill=g.flat().find(v=>p[v]&&L.dist(h2(p[v]),[131,174,204])<20);return {grid:g,pal:p};}},
 // otto's porthole eyes already sit on the grid
 otto:{apply(g,p){g=g.map(r=>r.slice());const B=p.indexOf('#8F171E'),J=p.indexOf('#FBEAE8'),E=p.indexOf('#A62025'),A=p.indexOf('#E54B47');
   // clear the sampled porthole cells, then draw both portholes the same: ring, white glass, one dark cell below
   for(let y=11;y<=14;y++)for(let x=7;x<=14;x++)if(g[y][x]!==A&&x!==15)g[y][x]=A;this.eyes=[];
   for(const cx of [8,12]){const cells=[[11,cx,B],[12,cx-1,B],[12,cx,J],[12,cx+1,B],[13,cx-1,B],[13,cx,B],[13,cx+1,B],[14,cx,E]];for(const [y,x,v] of cells){g[y][x]=v;this.eyes.push([y,x]);}}
   this.fill=A;return {grid:g,pal:p};}},
};
module.exports.init=async()=>{IM=await L.load(L.R+'/ref-pixel-sheet.png');};
