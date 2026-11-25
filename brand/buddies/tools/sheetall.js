// reference | ours for all 30, with names and scores, as one PNG
const fs=require('fs');const L=require('./lib');const sharp=require('sharp');const {Resvg}=require('@resvg/resvg-js');const {smoothSVG,pixelSVG}=require('./write');
(async()=>{const data=JSON.parse(fs.readFileSync('out/buddies-data.json'));const met=Object.fromEntries(JSON.parse(fs.readFileSync('out/metrics.json')).map(r=>[r.name,r]));
 const TW=176,TH=176,GAP=8,CW=TW*2+GAP*3,CH=TH+44;const cols=5;const parts=[];const comp=[];
 const sections=[['smooth','ref-vector-sheet.png','#F6F7F1'],['pixel','ref-pixel-sheet.png','#F3F0E9']];let y0=50;let texts=[];
 texts.push(`<text x="20" y="34" font-family="Helvetica" font-size="24" font-weight="bold">Belay buddies: reference (left) vs ours (right), rendered at the reference size</text>`);
 for(const [style,sheet,bg] of sections){texts.push(`<text x="20" y="${y0+26}" font-family="Helvetica" font-size="20" font-weight="bold">${style}</text>`);y0+=40;
  for(let i=0;i<15;i++){const nm=L.NAMES[i];const b=data.buddies[nm];const X=(i%cols)*CW+GAP,Y=y0+Math.floor(i/cols)*CH;
   let left,top,w,h,svg;if(style==='smooth'){const s=b.smooth;[w,h]=s.viewBox;left=s.cell[0]+s.origin[0];top=s.cell[1]+s.origin[1];svg=smoothSVG(nm,s);}
   else{const p=b.pixel;w=Math.round(p.size[0]*p.grid.x.p);h=Math.round(p.size[1]*p.grid.y.p);left=Math.round(p.cell[0]+p.grid.x.o);top=Math.round(p.cell[1]+p.grid.y.o);svg=pixelSVG(nm,p).replace(/width="\d+" height="\d+"/,`width="${p.size[0]}" height="${p.size[1]}"`);}
   const ox=Math.round((TW-w)/2),oy=Math.round((TH-h)/2);
   const ref=await sharp(L.R+'/'+sheet).extract({left:left-ox,top:top-oy,width:TW,height:TH}).removeAlpha().png().toBuffer();
   let ours;if(style==='smooth'){ours=new Resvg(svg,{fitTo:{mode:'original'},background:bg}).render().asPng();}
   else{const small=new Resvg(svg,{fitTo:{mode:'width',value:b.pixel.size[0]*16},shapeRendering:0}).render().asPng();ours=await sharp(small).resize(w,h,{kernel:'nearest',fit:'fill'}).flatten({background:bg}).png().toBuffer();}
   ours=await sharp(ours).extend({top:oy,left:ox,bottom:TH-h-oy,right:TW-w-ox,background:bg}).png().toBuffer();
   comp.push({input:ref,left:X,top:Y},{input:ours,left:X+TW+GAP,top:Y});
   const m=met[nm][style];texts.push(`<text x="${X}" y="${Y+TH+18}" font-family="Menlo" font-size="14">${nm}</text><text x="${X+TW+GAP}" y="${Y+TH+18}" font-family="Menlo" font-size="12" fill="#444">IoU ${m.iou.toFixed(3)} · ΔE ${m.dE.toFixed(1)}</text>`);}
  y0+=3*CH+10;}
 const W=cols*CW+GAP,H=y0+10;const overlay=new Resvg(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">${texts.join('')}</svg>`,{font:{loadSystemFonts:true}}).render().asPng();
 await sharp({create:{width:W,height:H,channels:3,background:'#E4E4E4'}}).composite([...comp,{input:overlay,left:0,top:0}]).png({compressionLevel:9}).toFile(process.argv[2]||'out/comparison.png');console.log(W,H);})();
