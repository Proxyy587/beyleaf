const fs=require('fs');const L=require('./lib');const {sprite}=require('./select');const {Resvg}=require('@resvg/resvg-js');
const BG=[246,247,241];
function lab(c){let [r,g,b]=c.map(v=>{v/=255;return v<=0.04045?v/12.92:Math.pow((v+0.055)/1.055,2.4);});
 let X=(r*0.4124+g*0.3576+b*0.1805)/0.95047,Y=r*0.2126+g*0.7152+b*0.0722,Z=(r*0.0193+g*0.1192+b*0.9505)/1.08883;const f=t=>t>0.008856?Math.cbrt(t):7.787*t+16/116;return [116*f(Y)-16,500*(f(X)-f(Y)),200*(f(Y)-f(Z))];}
function dE(a,b){const A=lab(a),B=lab(b);return Math.hypot(A[0]-B[0],A[1]-B[1],A[2]-B[2]);}
module.exports={lab,dE};
if(require.main===module)(async()=>{const im=await L.load(L.R+'/ref-vector-sheet.png');const meta=JSON.parse(fs.readFileSync('out/smooth-meta.json'));const rows=[];
 for(let i=0;i<15;i++){const name=L.NAMES[i];const m=meta[name];const s=sprite(im,i,false);
  const svg=fs.readFileSync(`out/smooth/${name}.svg`,'utf8');const r=new Resvg(svg,{fitTo:{mode:'original'}}).render();const px=r.pixels;const rw=r.width,rh=r.height;
  const [vx,vy]=m.view;
  // reference alpha: 1 - bg coverage, from un-mixing against the nearest sprite colour along the bg line
  let inter=0,uni=0,dsum=0,dn=0,ref1=0;
  for(let y=0;y<s.H;y++)for(let x=0;x<s.W;x++){const c=im.px(s.x0+x,s.y0+y);
    const rx=x-vx,ry=y-vy;let a=0,oc=null;if(rx>=0&&ry>=0&&rx<rw&&ry<rh){const k=(ry*rw+rx)*4;a=px[k+3]/255;oc=[px[k],px[k+1],px[k+2]].map(v=>a?v/a:0);} // resvg premultiplied? check
    // ref alpha: in fg region with distance to bg
    const reg=s.fg[y*s.W+x]||(x>0&&s.fg[y*s.W+x-1])||(x<s.W-1&&s.fg[y*s.W+x+1])||(y>0&&s.fg[(y-1)*s.W+x])||(y<s.H-1&&s.fg[(y+1)*s.W+x]);
    let ra=0; if(reg){ // alpha relative to the colour our render predicts here (or nearest palette colour)
      const pal=Object.values(m.pal).map(h=>[1,3,5].map(j=>parseInt(h.slice(j,j+2),16)));let best=0;for(const P of pal){const d=[P[0]-BG[0],P[1]-BG[1],P[2]-BG[2]];const dd=d[0]**2+d[1]**2+d[2]**2;let t=((c[0]-BG[0])*d[0]+(c[1]-BG[1])*d[1]+(c[2]-BG[2])*d[2])/dd;t=Math.max(0,Math.min(1,t));const e=L.dist(c,[BG[0]+t*d[0],BG[1]+t*d[1],BG[2]+t*d[2]]);if(best===0||e<best.e)best={e,t};}ra=best.t;}
    const A=ra>=0.5,B=a>=0.5;if(A&&B)inter++;if(A||B)uni++;
    if(ra>0.98&&a>0.98){dsum+=dE(c,oc);dn++;}
  }
  rows.push({name,iou:inter/uni,dE:dsum/dn});console.log(name.padEnd(8),(inter/uni).toFixed(4),(dsum/dn).toFixed(2));}
 fs.writeFileSync('out/smooth-scores.json',JSON.stringify(rows));
})();
