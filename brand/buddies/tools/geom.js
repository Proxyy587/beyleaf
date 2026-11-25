// Marching squares (iso contour) + Schneider cubic Bezier fitting with corner detection.
function contours(F,W,H,iso=0.5){
  // F sampled at pixel centres (x+0.5,y+0.5). Pad with zeros conceptually.
  const v=(x,y)=>(x<0||y<0||x>=W||y>=H)?0:F[y*W+x];
  // edge ids: horizontal edge between (x,y)-(x+1,y): 'h'+x+','+y ; vertical edge (x,y)-(x,y+1): 'v'
  const pts=new Map(); const adj=new Map();
  const pt=(id,x0,y0,x1,y1)=>{ if(!pts.has(id)){const a=v(x0,y0),b=v(x1,y1);const t=(iso-a)/(b-a);pts.set(id,[x0+(x1-x0)*t+0.5,y0+(y1-y0)*t+0.5]);} return id;};
  const link=(a,b)=>{(adj.get(a)||adj.set(a,[]).get(a)).push(b);(adj.get(b)||adj.set(b,[]).get(b)).push(a);};
  for(let y=-1;y<H;y++)for(let x=-1;x<W;x++){
    const a=v(x,y)>=iso,b=v(x+1,y)>=iso,c=v(x+1,y+1)>=iso,d=v(x,y+1)>=iso;
    const idx=(a?8:0)|(b?4:0)|(c?2:0)|(d?1:0); if(idx==0||idx==15) continue;
    const T=()=>pt(`h${x},${y}`,x,y,x+1,y), R=()=>pt(`v${x+1},${y}`,x+1,y,x+1,y+1), B=()=>pt(`h${x},${y+1}`,x,y+1,x+1,y+1), Lf=()=>pt(`v${x},${y}`,x,y,x,y+1);
    switch(idx){
      case 1: case 14: link(Lf(),B());break;
      case 2: case 13: link(B(),R());break;
      case 3: case 12: link(Lf(),R());break;
      case 4: case 11: link(T(),R());break;
      case 6: case 9: link(T(),B());break;
      case 7: case 8: link(Lf(),T());break;
      case 5: case 10: {const ctr=(v(x,y)+v(x+1,y)+v(x+1,y+1)+v(x,y+1))/4>=iso; // a,c inside (10) or b,d inside (5)
        if((idx==10)==ctr){ link(Lf(),B()); link(T(),R()); } else { link(Lf(),T()); link(B(),R()); } break;}
    }
  }
  const used=new Set(); const loops=[];
  for(const start of adj.keys()){ if(used.has(start)) continue; const loop=[]; let prev=null,cur=start;
    while(cur!==undefined && !used.has(cur)){used.add(cur);loop.push(pts.get(cur));const n=adj.get(cur);const nx=n[0]!==prev&&!used.has(n[0])?n[0]:(n[1]!==prev&&!used.has(n[1])?n[1]:undefined);prev=cur;cur=nx;}
    if(loop.length>=4) loops.push(loop);}
  return loops;
}
function area(P){let s=0;for(let i=0;i<P.length;i++){const a=P[i],b=P[(i+1)%P.length];s+=a[0]*b[1]-b[0]*a[1];}return s/2;}
// resample closed polyline to ~uniform spacing
function resample(P,step){const out=[];let L=0;const segs=[];for(let i=0;i<P.length;i++){const a=P[i],b=P[(i+1)%P.length];const l=Math.hypot(b[0]-a[0],b[1]-a[1]);segs.push(l);L+=l;}
  const n=Math.max(8,Math.round(L/step));const ds=L/n;let i=0,acc=0;for(let k=0;k<n;k++){const t=k*ds;while(acc+segs[i]<t){acc+=segs[i];i=(i+1)%P.length;}const a=P[i],b=P[(i+1)%P.length];const f=segs[i]?(t-acc)/segs[i]:0;out.push([a[0]+(b[0]-a[0])*f,a[1]+(b[1]-a[1])*f]);}return out;}
function smooth(P,sigma,fixed){if(sigma<=0)return P;const n=P.length;const r=Math.ceil(sigma*3);const w=[];for(let k=-r;k<=r;k++)w.push(Math.exp(-k*k/(2*sigma*sigma)));
  return P.map((p,i)=>{if(fixed&&fixed.has(i))return p;let sx=0,sy=0,sw=0;for(let k=-r;k<=r;k++){const q=P[((i+k)%n+n)%n];sx+=q[0]*w[k+r];sy+=q[1]*w[k+r];sw+=w[k+r];}return [sx/sw,sy/sw];});}
// turning angle corners
function corners(P,win,thDeg){const n=P.length;const ang=[];for(let i=0;i<n;i++){const a=P[((i-win)%n+n)%n],b=P[i],c=P[(i+win)%n];const v1=[b[0]-a[0],b[1]-a[1]],v2=[c[0]-b[0],c[1]-b[1]];let t=Math.atan2(v1[0]*v2[1]-v1[1]*v2[0],v1[0]*v2[0]+v1[1]*v2[1]);ang.push(Math.abs(t)*180/Math.PI);}
  const out=[];for(let i=0;i<n;i++){if(ang[i]<thDeg)continue;let isMax=true;for(let k=-win;k<=win;k++){if(k&&ang[((i+k)%n+n)%n]>ang[i]){isMax=false;break;}}if(isMax&&!out.some(j=>Math.min(Math.abs(j-i),n-Math.abs(j-i))<win))out.push(i);}return out.sort((a,b)=>a-b);}
// ---- Schneider
const sub=(a,b)=>[a[0]-b[0],a[1]-b[1]],add=(a,b)=>[a[0]+b[0],a[1]+b[1]],mul=(a,s)=>[a[0]*s,a[1]*s],dot=(a,b)=>a[0]*b[0]+a[1]*b[1],len=a=>Math.hypot(a[0],a[1]),norm=a=>{const l=len(a)||1;return [a[0]/l,a[1]/l];};
function bez(b,t){const mt=1-t;return add(add(mul(b[0],mt*mt*mt),mul(b[1],3*mt*mt*t)),add(mul(b[2],3*mt*t*t),mul(b[3],t*t*t)));}
function bezD(b,t){const mt=1-t;return add(add(mul(sub(b[1],b[0]),3*mt*mt),mul(sub(b[2],b[1]),6*mt*t)),mul(sub(b[3],b[2]),3*t*t));}
function bezDD(b,t){return add(mul(add(sub(b[2],mul(b[1],2)),b[0]),6*(1-t)),mul(add(sub(b[3],mul(b[2],2)),b[1]),6*t));}
function chordParam(P){const u=[0];for(let i=1;i<P.length;i++)u.push(u[i-1]+len(sub(P[i],P[i-1])));const L=u[u.length-1]||1;return u.map(x=>x/L);}
function generate(P,u,t1,t2){const p0=P[0],p3=P[P.length-1];let C00=0,C01=0,C11=0,X0=0,X1=0;
  for(let i=0;i<P.length;i++){const t=u[i],mt=1-t;const A1=mul(t1,3*mt*mt*t),A2=mul(t2,3*mt*t*t);C00+=dot(A1,A1);C01+=dot(A1,A2);C11+=dot(A2,A2);
    const tmp=sub(P[i],bez([p0,p0,p3,p3],t));X0+=dot(A1,tmp);X1+=dot(A2,tmp);}
  const det=C00*C11-C01*C01;let a1=det?(X0*C11-X1*C01)/det:0,a2=det?(C00*X1-C01*X0)/det:0;const segL=len(sub(p3,p0));
  if(a1<1e-6*segL||a2<1e-6*segL||!isFinite(a1)||!isFinite(a2)){a1=a2=segL/3;}
  return [p0,add(p0,mul(t1,a1)),add(p3,mul(t2,a2)),p3];}
function maxErr(P,b,u){let m=0,mi=0;for(let i=1;i<P.length-1;i++){const d=len(sub(bez(b,u[i]),P[i]));if(d>m){m=d;mi=i;}}return [m,mi];}
function reparam(b,P,u){return u.map((t,i)=>{const d=sub(bez(b,t),P[i]),d1=bezD(b,t),d2=bezDD(b,t);const num=dot(d,d1),den=dot(d1,d1)+dot(d,d2);if(!den)return t;const nt=t-num/den;return Math.min(1,Math.max(0,nt));});}
function fitCubic(P,t1,t2,err,out,depth=0){
  if(P.length==2){const d=len(sub(P[1],P[0]))/3;out.push([P[0],add(P[0],mul(t1,d)),add(P[1],mul(t2,d)),P[1]]);return;}
  let u=chordParam(P);let b=generate(P,u,t1,t2);let [e,split]=maxErr(P,b,u);
  if(e<err){out.push(b);return;}
  if(e<err*4){for(let k=0;k<20;k++){u=reparam(b,P,u);b=generate(P,u,t1,t2);[e,split]=maxErr(P,b,u);if(e<err){out.push(b);return;}}}
  if(depth>30){out.push(b);return;}
  split=Math.max(1,Math.min(P.length-2,split));
  const tc=norm(sub(P[split-1],P[split+1]));
  fitCubic(P.slice(0,split+1),t1,tc,err,out,depth+1);fitCubic(P.slice(split),mul(tc,-1),t2,err,out,depth+1);
}
// fit a closed loop; corner indices give sharp joins, else smooth everywhere
function fitClosed(P,err,cornerIdx){const n=P.length;const tan=i=>norm(sub(P[(i+1)%n],P[(i-1+n)%n]));
  let cuts=cornerIdx.length?cornerIdx.slice():[0,Math.floor(n/2)];
  if(cuts.length==1) cuts.push((cuts[0]+Math.floor(n/2))%n);
  const isCorner=new Set(cornerIdx);const segs=[];
  for(let k=0;k<cuts.length;k++){const a=cuts[k],b=cuts[(k+1)%cuts.length];const pts=[];for(let i=a;;i=(i+1)%n){pts.push(P[i]);if(i==b)break;}
    const t1=isCorner.has(a)?norm(sub(pts[Math.min(2,pts.length-1)],pts[0])):tan(a);
    const t2=isCorner.has(b)?norm(sub(pts[Math.max(0,pts.length-3)],pts[pts.length-1])):mul(tan(b),-1);
    fitCubic(pts,t1,t2,err,segs);}
  return segs;}
function pathD(segs,f=v=>+v.toFixed(2)){if(!segs.length)return'';let d=`M${f(segs[0][0][0])} ${f(segs[0][0][1])}`;for(const s of segs)d+=`C${f(s[1][0])} ${f(s[1][1])} ${f(s[2][0])} ${f(s[2][1])} ${f(s[3][0])} ${f(s[3][1])}`;return d+'Z';}
module.exports={contours,area,resample,smooth,corners,fitClosed,pathD};
