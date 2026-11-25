// data file -> SVG/PNG assets for both styles
const fs=require('fs');const path=require('path');const {Resvg}=require('@resvg/resvg-js');const sharp=require('sharp');
const f2=v=>+(+v).toFixed(2);
function happyArc(e){const cx=e.x+e.w/2,cy=e.y+e.h/2;const a=e.w*0.95,up=e.h*0.42,dn=e.h*0.12;return `M${f2(cx-a)} ${f2(cy+dn)}Q${f2(cx)} ${f2(cy-up-dn)} ${f2(cx+a)} ${f2(cy+dn)}`;}
function smoothSVG(nm,s,opts={}){const [w,h]=s.viewBox;const clip=s.layers.some(l=>l.clip);const body=s.layers[0];
  const eyeCy=s.eyes.rects.reduce((t,e)=>t+e.y+e.h/2,0)/s.eyes.rects.length;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" data-buddy="${nm}" data-style="smooth" data-eye-y="${f2(eyeCy)}">
  <title>${nm}</title>${clip?`\n  <defs><clipPath id="${nm}-clip"><path d="${body.d}"/></clipPath></defs>`:''}
  <g class="buddy-body">
${s.layers.map(l=>`    <path class="buddy-${l.part}" fill="${l.fill}"${l.clip?` clip-path="url(#${nm}-clip)"`:''} d="${l.d}"/>`).join('\n')}
  </g>
  <g class="buddy-eyes" fill="${s.eyes.fill}">
${s.eyes.rects.map(e=>`    <rect x="${e.x}" y="${e.y}" width="${e.w}" height="${e.h}" rx="${f2(e.w/2)}"/>`).join('\n')}
  </g>
  <g class="buddy-eyes-happy" fill="none" stroke="${s.eyes.fill}" stroke-width="${f2(s.eyes.rects[0].w*0.78)}" stroke-linecap="round" stroke-linejoin="round"${opts.showHappy?'':' display="none"'}>
${s.eyes.rects.map(e=>`    <path d="${happyArc(e)}"/>`).join('\n')}
  </g>
</svg>
`;}
function runs(cells,pal){const by={};const rows={};for(const [x,y,v] of cells){(rows[y]=rows[y]||[]).push([x,v]);}
  for(const y in rows){const r=rows[y].sort((a,b)=>a[0]-b[0]);let i=0;while(i<r.length){let j=i;while(j+1<r.length&&r[j+1][0]===r[j][0]+1&&r[j+1][1]===r[i][1])j++;const len=j-i+1;(by[r[i][1]]=by[r[i][1]]||[]).push(`M${r[i][0]} ${y}h${len}v1h-${len}z`);i=j+1;}}
  return Object.entries(by).map(([v,d])=>`    <path fill="${pal[v]}" d="${d.join('')}"/>`).join('\n');}
function pixelSVG(nm,p,opts={}){const [W,H]=p.size;const body=[];p.rows.forEach((row,y)=>row.forEach((v,x)=>{if(v>=0)body.push([x,y,v]);}));
  const g=(cls,cells,hidden)=>`  <g class="${cls}"${hidden?' display="none"':''}>\n${runs(cells,p.palette)}\n  </g>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W*8}" height="${H*8}" shape-rendering="crispEdges" data-buddy="${nm}" data-style="pixel">
  <title>${nm}</title>
${g('buddy-body',body)}
${p.mouth.length?g('buddy-mouth',p.mouth)+'\n':''}${g('buddy-eyes',p.eyes.open,opts.state&&opts.state!=='open')}
${g('buddy-eyes-closed',p.eyes.closed,opts.state!=='closed')}
${g('buddy-eyes-happy',p.eyes.happy,opts.state!=='happy')}
</svg>
`;}
async function pixelPNG(p,file,scale){const [W,H]=p.size;const buf=Buffer.alloc(W*H*4);const put=(x,y,v)=>{if(x<0||y<0||x>=W||y>=H)return;const h=p.palette[v];const k=(y*W+x)*4;buf[k]=parseInt(h.slice(1,3),16);buf[k+1]=parseInt(h.slice(3,5),16);buf[k+2]=parseInt(h.slice(5,7),16);buf[k+3]=255;};
  p.rows.forEach((row,y)=>row.forEach((v,x)=>{if(v>=0)put(x,y,v);}));p.eyes.open.forEach(([x,y,v])=>put(x,y,v));(p.mouth||[]).forEach(([x,y,v])=>put(x,y,v));
  let img=sharp(buf,{raw:{width:W,height:H,channels:4}});if(scale>1)img=img.resize(W*scale,H*scale,{kernel:'nearest'});await img.png({compressionLevel:9}).toFile(file);}
async function writeAll(data,dir){for(const sub of ['smooth','pixel'])fs.mkdirSync(path.join(dir,sub),{recursive:true});
  for(const [nm,b] of Object.entries(data.buddies)){fs.writeFileSync(path.join(dir,'smooth',nm+'.svg'),smoothSVG(nm,b.smooth));fs.writeFileSync(path.join(dir,'pixel',nm+'.svg'),pixelSVG(nm,b.pixel));
    await pixelPNG(b.pixel,path.join(dir,'pixel',nm+'.png'),1);await pixelPNG(b.pixel,path.join(dir,'pixel',nm+'@8x.png'),8);}}
module.exports={smoothSVG,pixelSVG,writeAll,happyArc};
if(require.main===module)(async()=>{const data=JSON.parse(fs.readFileSync('out/buddies-data.json'));await writeAll(data,process.argv[2]||'final');console.log('written');})();
