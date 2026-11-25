// Prove the match: render each final asset at the reference scale and compare with the reference crop.
const fs=require('fs');const L=require('./lib');const {sprite}=require('./select');const {Resvg}=require('@resvg/resvg-js');const {dE}=require('./cmp-smooth');
const data=JSON.parse(fs.readFileSync('out/buddies-data.json'));const pm=JSON.parse(fs.readFileSync('out/pixel-meta.json'));const {smoothSVG}=require('./write');
function refAlpha(im,s,pal,BG){const N=s.W*s.H;const A=new Float32Array(N);for(let y=0;y<s.H;y++)for(let x=0;x<s.W;x++){let near=false;for(let dy=-2;dy<=2&&!near;dy++)for(let dx=-2;dx<=2;dx++){const X=x+dx,Y=y+dy;if(X>=0&&Y>=0&&X<s.W&&Y<s.H&&s.fg[Y*s.W+X]){near=true;break;}}if(!near)continue;
  const c=im.px(s.x0+x,s.y0+y);let best=null;for(const P of pal){const d=[P[0]-BG[0],P[1]-BG[1],P[2]-BG[2]];const dd=d[0]**2+d[1]**2+d[2]**2;if(dd<400)continue;let t=((c[0]-BG[0])*d[0]+(c[1]-BG[1])*d[1]+(c[2]-BG[2])*d[2])/dd;t=Math.max(0,Math.min(1,t));const e=L.dist(c,[BG[0]+t*d[0],BG[1]+t*d[1],BG[2]+t*d[2]]);if(!best||e<best.e)best={e,t};}
  A[y*s.W+x]=s.fg[y*s.W+x]?Math.max(best.t,best.e>40?1:0):best.t;}return A;}
const h2=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));
(async()=>{const imS=await L.load(L.R+'/ref-vector-sheet.png'),imP=await L.load(L.R+'/ref-pixel-sheet.png');const rows=[];
 for(let i=0;i<15;i++){const nm=L.NAMES[i];const b=data.buddies[nm];
  // smooth
  let s=sprite(imS,i,false);const sv=b.smooth;const svg=smoothSVG(nm,sv);const r=new Resvg(svg,{fitTo:{mode:'original'}}).render();const px=r.pixels,rw=r.width,rh=r.height;
  const palS=[...new Set([...sv.layers.map(l=>l.fill),sv.eyes.fill])].map(h2);const AS=refAlpha(imS,s,palS,[246,247,241]);const [ox,oy]=sv.origin;
  let I=0,U=0,ds=0,dn=0;for(let y=0;y<s.H;y++)for(let x=0;x<s.W;x++){const rx=x-ox,ry=y-oy;let a=0,oc=null;if(rx>=0&&ry>=0&&rx<rw&&ry<rh){const k=(ry*rw+rx)*4;a=px[k+3]/255;if(a>0)oc=[px[k]/a,px[k+1]/a,px[k+2]/a];}
    const A=AS[y*s.W+x]>=0.5,B=a>=0.5;if(A&&B)I++;if(A||B)U++;if(AS[y*s.W+x]>0.98&&a>0.98){ds+=dE(imS.px(s.x0+x,s.y0+y),oc);dn++;}}
  const sm={iou:I/U,dE:ds/dn};
  // pixel: uniform grid (as the art really renders) and on the recovered grid lines
  s=sprite(imP,i,true);const p=b.pixel;const m=pm[nm];const [W,H]=p.size;const cells=p.rows.map(r=>r.slice());p.eyes.open.forEach(([x,y,v])=>cells[y][x]=v);(p.mouth||[]).forEach(([x,y,v])=>cells[y][x]=v);
  const raw=JSON.parse(fs.readFileSync('out/pixel-raw.json'))[nm];const AP=require('./pixel').alphaMap(imP,s,raw.pal.map(h2)).A;
  const LX=m.LX.slice(m.c0,m.c0+W+1),LY=m.LY.slice(m.r0,m.r0+H+1);
  const at=(Ls,v)=>{for(let c=0;c<Ls.length-1;c++)if(v>=Ls[c]&&v<Ls[c+1])return c;return -1;};
  let Iu=0,Uu=0,Iw=0,Uw=0,dp=0,dpn=0;
  for(let y=0;y<s.H;y++)for(let x=0;x<s.W;x++){const A=AP[y*s.W+x]>=0.5;const cx=Math.floor((x+0.5-p.grid.x.o)/p.grid.x.p),cy=Math.floor((y+0.5-p.grid.y.o)/p.grid.y.p);const v=cx>=0&&cy>=0&&cx<W&&cy<H?cells[cy][cx]:-1;const B=v>=0;if(A&&B)Iu++;if(A||B)Uu++;
    const wx=at(LX,x+0.5),wy=at(LY,y+0.5);const vw=wx>=0&&wy>=0?cells[wy][wx]:-1;if(A&&vw>=0)Iw++;if(A||vw>=0)Uw++;
    if(AP[y*s.W+x]>0.98&&vw>=0){dp+=dE(imP.px(s.x0+x,s.y0+y),h2(p.palette[vw]));dpn++;}}
  rows.push({name:nm,smooth:{iou:+sm.iou.toFixed(4),dE:+sm.dE.toFixed(2)},pixel:{iou:+(Iu/Uu).toFixed(4),iouRecoveredGrid:+(Iw/Uw).toFixed(4),dE:+(dp/dpn).toFixed(2),cells:[W,H],pitch:[+p.grid.x.p.toFixed(3),+p.grid.y.p.toFixed(3)]}});
  console.log(nm.padEnd(8),'smooth',sm.iou.toFixed(4),sm.dE.toFixed(2),' pixel',(Iu/Uu).toFixed(4),(Iw/Uw).toFixed(4),(dp/dpn).toFixed(2));}
 fs.writeFileSync('out/metrics.json',JSON.stringify(rows,null,1));})();
