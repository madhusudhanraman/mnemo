import assert from 'node:assert/strict';
import {createGhost} from '../ghost.mjs';
const ghost=createGhost(),{geometry,around,down}=ghost;
const initial=geometry.attributes.position.array.slice();
let totalMs=0,maxHemMotion=0;
for(let frame=1;frame<=120;frame++){
 const t=frame/20,start=performance.now();ghost.update(t,frame>80);totalMs+=performance.now()-start;
 const p=geometry.attributes.position,n=geometry.attributes.normal;
 for(let i=0;i<p.array.length;i++){assert.ok(Number.isFinite(p.array[i]));assert.ok(Number.isFinite(n.array[i]));}
 for(let row=0;row<=down;row++){
  const a=row*(around+1),b=a+around;
  assert.ok(Math.hypot(p.getX(a)-p.getX(b),p.getY(a)-p.getY(b),p.getZ(a)-p.getZ(b))<1e-5,'Cloth seam must remain closed');
 }
 // The crown stays supported while the hem can sway freely.
 assert.ok(Math.abs(p.getY(0)-1.6)<1e-6);
 for(let col=0;col<around;col++){
  const i=(down*(around+1)+col)*3;
  maxHemMotion=Math.max(maxHemMotion,Math.hypot(p.array[i]-initial[i],p.array[i+1]-initial[i+1],p.array[i+2]-initial[i+2]));
 }
}
assert.ok(maxHemMotion>.30,'Hem must visibly ripple and sway');
assert.ok(geometry.index.count>50000,'Sheet must have a smooth detailed surface');
console.log(`PASS: 120 poses, closed circular seam, supported crown, finite normals, visible hem motion (${maxHemMotion.toFixed(2)} units).`);
console.log(`Average mesh update: ${(totalMs/120).toFixed(2)} ms; ${geometry.index.count/3} cloth triangles.`);

ghost.setVanished(true);for(let i=1;i<=180;i++)ghost.update(6+i/60);
assert.equal(ghost.sheet.visible,false);assert.equal(ghost.visibility,0);
assert.ok(ghost.group.children.slice(1).every(eye=>eye.visible),'Eyes remain visible');
ghost.setVanished(false);for(let i=181;i<=360;i++)ghost.update(6+i/60);
assert.equal(ghost.sheet.visible,true);assert.equal(ghost.visibility,1);
console.log('PASS: Peekaboo leaves only the eyes, then restores the cloth.');

assert.equal(ghost.sheet.material.transparent,false,'Cloth must stay opaque in its depth-tested render');
assert.equal(ghost.sheet.material.depthWrite,true,'Depth writing must not change at fade endpoints');
console.log('PASS: fade does not toggle transparent sorting or depth writing.');
