const L=require('./lib');const {cellMask}=require('./comps');
// pick the sprite components of a cell
function sprite(im,i,isPix){const cx=i%5,cy=(i/5)|0;const m=cellMask(im,cx,cy,isPix?[243,240,233]:[246,247,241]);
 const ymax=cy==0?214:200;
 const keep=m.comps.filter(c=>c.n>=20 && c.y1<ymax && !(c.x0>=175&&c.y0>=160&&c.n<1200) && c.x1>0 && c.x0<m.W-1);
 const ids=new Set(keep.map(c=>c.id));
 const fg=new Uint8Array(m.W*m.H);for(let k=0;k<fg.length;k++) if(ids.has(m.lab[k])) fg[k]=1;
 return {...m,keep,fg};}
module.exports={sprite};
if(require.main===module)(async()=>{const f=process.argv[2];const isPix=f.includes('pixel');const im=await L.load(L.R+'/'+f);
 for(let i=0;i<15;i++){const s=sprite(im,i,isPix);const h={};
  for(let y=1;y<s.H-1;y++)for(let x=1;x<s.W-1;x++){const k=y*s.W+x;if(!s.fg[k])continue;
   // interior: all 8 neighbours similar colour
   const c=im.px(s.x0+x,s.y0+y);let ok=true;for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,-1],[1,-1],[-1,1]]){if(L.dist(c,im.px(s.x0+x+dx,s.y0+y+dy))>12){ok=false;break;}} if(!ok)continue;
   const q=L.hex(c.map(v=>Math.round(v/12)*12));h[q]=(h[q]||0)+1;}
  console.log(L.NAMES[i],s.keep.map(c=>c.n).join('+'),Object.entries(h).sort((a,b)=>b[1]-a[1]).slice(0,10).map(e=>e.join(':')).join(' '));}
})();
