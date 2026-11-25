const sharp=require('sharp');
const R=require('path').resolve(__dirname,'..');
async function load(f){const {data,info}=await sharp(f).removeAlpha().raw().toBuffer({resolveWithObject:true});return {data,w:info.width,h:info.height,ch:info.channels,
 px(x,y){const i=(y*this.w+x)*this.ch;return [data[i],data[i+1],data[i+2]];}};}
const NAMES=['beepo','sprout','willo','pip','gloop','barnaby','fig','poko','crush','fizz','otto','bram','breeze','ziggy','toby'];
function hex(c){return '#'+c.map(v=>Math.round(Math.max(0,Math.min(255,v))).toString(16).padStart(2,'0')).join('').toUpperCase();}
function dist(a,b){return Math.hypot(a[0]-b[0],a[1]-b[1],a[2]-b[2]);}
module.exports={sharp,R,load,NAMES,hex,dist};
