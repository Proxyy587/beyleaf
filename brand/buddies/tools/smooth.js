// Trace the smooth reference sheet into layered SVGs with capsule eyes.
const fs=require('fs');const L=require('./lib');const {sprite}=require('./select');const G=require('./geom');
const BG=[246,247,241];
const h2=(h)=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));
const CFG={
 beepo:{pal:{body:'#9060CC',eye:'#302424'}},
 sprout:{pal:{body:'#3CC060',eye:'#302420'}},
 willo:{pal:{body:'#F08428',eye:'#3C2418'}},
 pip:{pal:{body:'#F04848',eye:'#3C2418'}},
 gloop:{pal:{body:'#48A8A8',eye:'#302424'}},
 barnaby:{pal:{body:'#3054B0',screen:'#18306C',eye:'#90E4F0'},layers:[['screen',['screen','eye']]]},
 fig:{pal:{body:'#702454',eye:'#342020'}},
 poko:{pal:{body:'#F0903C',eye:'#3C2418'}},
 crush:{pal:{body:'#F0789C',eye:'#3C2424'}},
 fizz:{pal:{body:'#90DCB4',eye:'#302418'}},
 otto:{pal:{body:'#EC4848',dark:'#C43030',eye:'#3C2418'},layers:[['dark',['dark']]]},
 bram:{pal:{body:'#A87848',cap:'#483018',eye:'#3C2418'},layers:[['cap',['cap']]]},
 breeze:{pal:{body:'#A8D8F0',eye:'#342424'}},
 ziggy:{pal:{body:'#FCCC3C',eye:'#3C2418'}},
 toby:{pal:{body:'#242454',eye:'#9CD8F0'},notch:[1079.5,751.5,1073.5,1086,764],notchFill:'#66648A'},
};
function classify(im,s,pal){ // returns per-pixel coverage per palette key + bg, and pure-pixel colour stats
  const keys=Object.keys(pal);const cols=keys.map(k=>pal[k]);const all=[...cols,BG];const K=all.length;
  const cov=keys.map(()=>new Float32Array(s.W*s.H));const err=new Float32Array(s.W*s.H);
  // allowed region: dilated fg
  const reg=new Uint8Array(s.W*s.H);for(let y=0;y<s.H;y++)for(let x=0;x<s.W;x++){if(!s.fg[y*s.W+x])continue;for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){const X=x+dx,Y=y+dy;if(X>=0&&Y>=0&&X<s.W&&Y<s.H)reg[Y*s.W+X]=1;}}
  const sums=keys.map(()=>[[],[],[]]);
  for(let y=0;y<s.H;y++)for(let x=0;x<s.W;x++){const k=y*s.W+x;if(!reg[k])continue;const c=im.px(s.x0+x,s.y0+y);
    let best={e:1e9};
    for(let i=0;i<K;i++){const e=L.dist(c,all[i]);if(e<best.e)best={e,i,j:i,t:1};}
    for(let i=0;i<K;i++)for(let j=i+1;j<K;j++){const A=all[i],B=all[j];const d=[A[0]-B[0],A[1]-B[1],A[2]-B[2]];const dd=d[0]*d[0]+d[1]*d[1]+d[2]*d[2];if(!dd)continue;
      let t=((c[0]-B[0])*d[0]+(c[1]-B[1])*d[1]+(c[2]-B[2])*d[2])/dd;t=Math.max(0,Math.min(1,t));const m=[B[0]+t*d[0],B[1]+t*d[1],B[2]+t*d[2]];const e=L.dist(c,m);if(e<best.e-0.5)best={e,i,j,t};}
    err[k]=best.e;
    if(best.i<keys.length)cov[best.i][k]+=best.t; if(best.j<keys.length&&best.j!==best.i)cov[best.j][k]+=1-best.t;
    if(best.i===best.j&&best.i<keys.length&&best.e<25){let core=true;for(let dy=-2;dy<=2&&core;dy++)for(let dx=-2;dx<=2;dx++){if(L.dist(im.px(s.x0+x+dx,s.y0+y+dy),c)>14){core=false;break;}}if(core)for(let q=0;q<3;q++)sums[best.i][q].push(c[q]);}
  }
  const med=a=>{if(!a.length)return null;return a.reduce((p,q)=>p+q,0)/a.length;};
  const refined={};keys.forEach((k,i)=>{const m=sums[i].map(med);refined[k]=m[0]==null?pal[k]:m;});
  return {keys,cov,err,refined,reg};
}
function morph(M,W,H,r,dil){const O=new Uint8Array(M.length);for(let y=0;y<H;y++)for(let x=0;x<W;x++){let v=dil?0:1;for(let dy=-r;dy<=r&&(dil?!v:v);dy++)for(let dx=-r;dx<=r;dx++){if(dx*dx+dy*dy>r*r+r)continue;const X=x+dx,Y=y+dy;const m=(X<0||Y<0||X>=W||Y>=H)?0:M[Y*W+X];if(dil&&m){v=1;break;}if(!dil&&!m){v=0;break;}}O[y*W+x]=v;}return O;}
function dropSmall(M,W,H,minA){const lab=new Int32Array(M.length).fill(-1);const O=new Uint8Array(M.length);for(let k=0;k<M.length;k++){if(!M[k]||lab[k]>=0)continue;const c=[k];lab[k]=1;for(let i=0;i<c.length;i++){const kk=c[i],x=kk%W,y=(kk/W)|0;for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){const X=x+dx,Y=y+dy;if(X<0||Y<0||X>=W||Y>=H)continue;const n=Y*W+X;if(M[n]&&lab[n]<0){lab[n]=1;c.push(n);}}}if(c.length>=minA)for(const kk of c)O[kk]=1;}return O;}
function capsule(F,W,H,comp){ // comp: list of pixel idx; returns capsule params in cell coords
  let sw=0,sx=0,sy=0;for(const k of comp){const w=F[k];sw+=w;sx+=w*((k%W)+0.5);sy+=w*(((k/W)|0)+0.5);}
  const cx=sx/sw,cy=sy/sw;
  const rowSum=(y)=>{let s=0;for(let x=0;x<W;x++)s+=Math.min(1,F[y*W+x]*(Math.abs(x+0.5-cx)<20?1:0));return s;};
  const colSum=(x)=>{let s=0;for(let y=0;y<H;y++)s+=Math.min(1,F[y*W+x]*(Math.abs(y+0.5-cy)<30?1:0));return s;};
  const yc=Math.floor(cy),xc=Math.floor(cx);
  // width: average over the middle rows (straight part of the capsule)
  let ws=[];for(let d=-2;d<=2;d++)ws.push(rowSum(yc+d));const w=ws.reduce((a,b)=>a+b)/ws.length;
  let hs=[];for(let d=-1;d<=1;d++)hs.push(colSum(xc+d));// column through centre gives full height near centre
  const h=Math.max(...hs);
  return {cx,cy,w,h,area:sw};
}
function traceLayer(F,W,H,opt={}){const loops=G.contours(F,W,H,0.5);const paths=[];
  for(const raw of loops){if(Math.abs(G.area(raw))<6)continue;let P=G.resample(raw,opt.step||1.0);
    const cs=G.corners(G.smooth(P,1.2),opt.cwin||4,opt.cth||+(process.env.CTH||75));const fixed=new Set();cs.forEach(i=>{for(let d=-1;d<=1;d++)fixed.add((i+d+P.length)%P.length);});
    P=G.smooth(P,opt.sigma??+(process.env.SIG||0.6),fixed);paths.push(G.fitClosed(P,opt.err||+(process.env.ERR||0.3),cs));}
  return paths;}
(async()=>{const im=await L.load(L.R+'/ref-vector-sheet.png');const out={};
 for(let i=0;i<15;i++){const name=L.NAMES[i];const cfg=CFG[name];const s=sprite(im,i,false);
  let pal=Object.fromEntries(Object.entries(cfg.pal).map(([k,v])=>[k,h2(v)]));
  let cl;for(let it=0;it<3;it++){cl=classify(im,s,pal);pal=cl.refined;}
  const W=s.W,H=s.H,N=W*H;const ki=k=>cl.keys.indexOf(k);
  const body=new Float32Array(N);for(let k=0;k<N;k++){let t=0;for(const c of cl.cov)t+=c[k];body[k]=Math.min(1,t);}
  const layers=[{name:'body',fill:pal.body,F:body}];
  const extra=[];const owner=new Int8Array(N).fill(-1);const q=[];
  for(const [nm,ks] of (cfg.layers||[])){const F=new Float32Array(N);for(let k=0;k<N;k++){let t=0;for(const kk of ks)t+=cl.cov[ki(kk)][k];F[k]=Math.min(1,t);}
    let M=new Uint8Array(N);for(let k=0;k<N;k++)M[k]=F[k]>=0.5?1:0;M=morph(morph(M,W,H,2,false),W,H,2,true);M=dropSmall(M,W,H,40);
    const near=morph(M,W,H,1,true);for(let k=0;k<N;k++){if(!near[k])F[k]=0;if(M[k]&&body[k]>0.9&&owner[k]<0){owner[k]=extra.length+1;q.push(k);}}
    extra.push({name:nm,fill:pal[ks[0]],F,M});}
  if(extra.length){for(let k=0;k<N;k++)if(owner[k]<0&&body[k]>0.9&&cl.cov[ki('body')][k]>0.8){owner[k]=0;q.push(k);}
    for(let i=0;i<q.length;i++){const k=q[i],x=k%W,y=(k/W)|0;for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){const X=x+dx,Y=y+dy;if(X<0||Y<0||X>=W||Y>=H)continue;const n=Y*W+X;if(owner[n]<0&&cl.reg[n]){owner[n]=owner[k];q.push(n);}}}
    // eroded silhouette (min over radius 2)
    const er=new Float32Array(N);for(let y=0;y<H;y++)for(let x=0;x<W;x++){let m=1;for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){const X=x+dx,Y=y+dy;const v=(X<0||Y<0||X>=W||Y>=H)?0:body[Y*W+X];if(v<m)m=v;}er[y*W+x]=m;}
    const B2=new Float32Array(N);for(let k=0;k<N;k++)B2[k]=owner[k]>0&&!cfg.keepBody?er[k]:body[k];
    // body under an overlay retreats 2px from the silhouette so the overlay alone draws that outer edge
    layers[0].F=B2;
    const O=new Uint8Array(N);for(let k=0;k<N;k++)O[k]=body[k]<0.5?1:0;const band=morph(O,W,H,3,true);
    extra.forEach((l,j)=>{for(let k=0;k<N;k++){if(owner[k]===j+1&&band[k])l.F[k]=body[k];}layers.push(l);});}
  // eyes: components of eye coverage >= .5
  const E=cl.cov[ki('eye')];const lab=new Int32Array(N).fill(-1);const comps=[];
  for(let k=0;k<N;k++){if(E[k]<0.5||lab[k]>=0)continue;const c=[];const q=[k];lab[k]=comps.length;while(q.length){const kk=q.pop();c.push(kk);const x=kk%W,y=(kk/W)|0;for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){const X=x+dx,Y=y+dy;if(X<0||Y<0||X>=W||Y>=H)continue;const nk=Y*W+X;if(E[nk]>=0.5&&lab[nk]<0){lab[nk]=comps.length;q.push(nk);}}}comps.push(c);}
  comps.sort((a,b)=>b.length-a.length);const eyeC=comps.slice(0,2).map(c=>{// grow by 1px ring to include AA edge
    const set=new Set(c);for(const k of c){const x=k%W,y=(k/W)|0;for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){const nk=(y+dy)*W+x+dx;if(E[nk]>0)set.add(nk);}}return capsule(E,W,H,[...set]);}).sort((a,b)=>a.cx-b.cx);
  const ew=(eyeC[0].w+eyeC[1].w)/2,eh=(eyeC[0].h+eyeC[1].h)/2,ey=(eyeC[0].cy+eyeC[1].cy)/2;
  // bbox
  let bx0=1e9,by0=1e9,bx1=-1,by1=-1;for(let k=0;k<N;k++)if(body[k]>=0.5){const x=k%W,y=(k/W)|0;bx0=Math.min(bx0,x);by0=Math.min(by0,y);bx1=Math.max(bx1,x+1);by1=Math.max(by1,y+1);}
  const vx=bx0-2,vy=by0-2,vw=bx1-bx0+4,vh=by1-by0+4;
  const f=v=>+v.toFixed(2);const T=(segs)=>G.pathD(segs.map(s=>s.map(p=>[p[0]-vx,p[1]-vy])),f);
  const parts=layers.map(l=>{const ps=traceLayer(l.F,W,H,cfg.opt);return `  <path class="buddy-${l.name}" fill="${L.hex(l.fill)}" fill-rule="evenodd"${l.clip?' clip-path="url(#'+name+'-clip)"':''} d="${ps.map(T).join('')}"/>`;});
  if(cfg.notch){const [ax,ay,bx0_,bx1_,by_]=cfg.notch.map((v,j)=>v-[s.x0,s.y0,s.x0,s.x0,s.y0][j]);parts.push(`  <path class="buddy-notch" fill="${cfg.notchFill}" clip-path="url(#${name}-clip)" d="M${f(ax-vx)} ${f(ay-vy)}L${f(bx1_-vx)} ${f(by_-vy)}L${f(bx0_-vx)} ${f(by_-vy)}Z"/>`);}
  const needClip=layers.some(l=>l.clip)||cfg.notch;
  if(needClip){const bodyD=parts[0].match(/ d="([^"]+)"/)[1];parts.unshift(`  <defs><clipPath id="${name}-clip"><path clip-rule="evenodd" d="${bodyD}"/></clipPath></defs>`);}
  const eyes=eyeC.map(e=>`    <rect x="${f(e.cx-ew/2-vx)}" y="${f(ey-eh/2-vy)}" width="${f(ew)}" height="${f(eh)}" rx="${f(ew/2)}"/>`);
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${vw} ${vh}" width="${vw}" height="${vh}" data-buddy="${name}" data-style="smooth">\n  <title>${name}</title>\n${parts.join('\n')}\n  <g class="buddy-eyes" fill="${L.hex(pal.eye)}">\n${eyes.join('\n')}\n  </g>\n</svg>\n`;
  fs.mkdirSync('out/smooth',{recursive:true});fs.writeFileSync(`out/smooth/${name}.svg`,svg);
  out[name]={cell:[s.x0,s.y0],view:[vx,vy,vw,vh],pal:Object.fromEntries(Object.entries(pal).map(([k,v])=>[k,L.hex(v)])),eye:{w:f(ew),h:f(eh),cy:f(ey-vy),cx:eyeC.map(e=>f(e.cx-vx))},nodes:svg.split('C').length};
  console.log(name,JSON.stringify(out[name]));
 }
 fs.writeFileSync('out/smooth-meta.json',JSON.stringify(out,null,1));
})();
