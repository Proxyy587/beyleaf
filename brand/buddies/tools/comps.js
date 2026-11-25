const L=require('./lib');
// returns per-cell list of components: non-background regions not reachable from the cell border via background-like pixels
function cellMask(im,cx,cy,bg,isPix){
  const x0=cx*240,y0=[0,300,600][cy],W=240,H=(cy==2?296:300);
  const bgLike=(c)=>{ if(L.dist(c,bg)<28) return true; const mx=Math.max(...c),mn=Math.min(...c); if(mx-mn<14 && mn>150) return true; return false;};
  const seen=new Uint8Array(W*H); const st=[];
  for(let x=0;x<W;x++){st.push([x,0],[x,H-1]);} for(let y=0;y<H;y++){st.push([0,y],[W-1,y]);}
  while(st.length){const [x,y]=st.pop(); if(x<0||y<0||x>=W||y>=H) continue; const k=y*W+x; if(seen[k]) continue; if(!bgLike(im.px(x0+x,y0+y))) continue; seen[k]=1; st.push([x+1,y],[x-1,y],[x,y+1],[x,y-1]);}
  // components of unseen
  const lab=new Int32Array(W*H).fill(-1); const comps=[];
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){const k=y*W+x; if(seen[k]||lab[k]>=0) continue; const c={id:comps.length,n:0,x0:1e9,y0:1e9,x1:-1,y1:-1,s:[0,0,0]}; const q=[k]; lab[k]=c.id;
    while(q.length){const kk=q.pop(); const xx=kk%W,yy=(kk/W)|0; c.n++; c.x0=Math.min(c.x0,xx);c.x1=Math.max(c.x1,xx);c.y0=Math.min(c.y0,yy);c.y1=Math.max(c.y1,yy); const p=im.px(x0+xx,y0+yy); c.s[0]+=p[0];c.s[1]+=p[1];c.s[2]+=p[2];
      for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){const nx=xx+dx,ny=yy+dy; if(nx<0||ny<0||nx>=W||ny>=H) continue; const nk=ny*W+nx; if(seen[nk]||lab[nk]>=0) continue; lab[nk]=c.id; q.push(nk);} }
    c.mean=L.hex(c.s.map(v=>v/c.n)); delete c.s; comps.push(c);}
  return {x0,y0,W,H,seen,lab,comps};
}
module.exports={cellMask};
if(require.main===module)(async()=>{
  const f=process.argv[2]; const im=await L.load(L.R+'/'+f); const bg=f.includes('vector')?[246,247,241]:[243,240,233];
  for(let i=0;i<15;i++){const m=cellMask(im,i%5,(i/5)|0,bg); console.log(L.NAMES[i], m.comps.filter(c=>c.n>3).map(c=>`[${c.x0},${c.y0}-${c.x1},${c.y1} n${c.n} ${c.mean}]`).join(' '));}
})();
