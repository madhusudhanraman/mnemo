import assert from 'node:assert/strict';
import {createOctopus} from '../octopus.mjs';
const octopus=createOctopus();
assert.equal(octopus.armPoses.length,8);
const angles=octopus.armPoses.map(p=>Math.atan2(p[0][2],p[0][0]));
for(let i=0;i<8;i++)assert.ok(Math.abs((angles[(i+1)%8]-angles[i]+Math.PI*2)%(Math.PI*2)-Math.PI/4)<1e-8);
function components(field,n){
 const seen=new Uint8Array(field.length),queue=new Int32Array(field.length),counts=[];
 for(let seed=0;seed<field.length;seed++){
  if(seen[seed]||field[seed]<=0)continue;
  let head=0,tail=1;queue[0]=seed;seen[seed]=1;
  while(head<tail){const q=queue[head++];for(const next of [q-1,q+1,q-n,q+n,q-n*n,q+n*n])if(next>=0&&next<field.length&&!seen[next]&&field[next]>0){seen[next]=1;queue[tail++]=next}}
  counts.push(tail);
 }
 return counts;
}
let maxBuild=0;
for(const t of [0,1,2,3,4,5,6]){
 const start=performance.now();octopus.update(t);maxBuild=Math.max(maxBuild,performance.now()-start);
 const surface=octopus.surface,n=surface.resolution;
 assert.ok(surface.count>0&&surface.count<surface.geometry.attributes.position.count);
 const groups=components(surface.field,n);
 assert.equal(groups.length,1,`Skin disconnected at t=${t}: ${groups}`);
 for(const name of ['position','normal','color']){
  const attr=surface.geometry.attributes[name];
  for(let i=0;i<surface.count*3;i++)assert.ok(Number.isFinite(attr.array[i]),`${name} invalid at t=${t}`);
 }
 console.log(`PASS pose ${t}: one connected skin, ${surface.count/3} triangles, finite geometry and colors`);
}
console.log(`Eight radial roots confirmed. Maximum pose generation: ${maxBuild.toFixed(1)} ms.`);
