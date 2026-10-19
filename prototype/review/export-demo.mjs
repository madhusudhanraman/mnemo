// Export a single demo pose using the production geometry and behaviour curves.
import * as THREE from '../vendor/three.module.mjs';
import {createGhost} from '../ghost.mjs';
import {createBehaviours,whirlPoint} from '../behaviours.mjs';
const kind=process.argv[2],t=Number(process.argv[3]||0);
const ghost=createGhost({around:64,down:40}),behaviours=createBehaviours();
if(kind==='sleepy')behaviours.sleep();
if(kind==='curious')behaviours.curious();
if(kind==='flutter')behaviours.flutter();
let mood,clothTime=0;
for(let elapsed=0;elapsed<=t;elapsed+=1/60){mood=behaviours.step(1/60);clothTime+=mood.speed/60;}
ghost.update(clothTime);
for(const child of ghost.group.children)if(child.isGroup)child.scale.y*=mood.eyeOpen;
if(mood.flutter){
 const pos=ghost.geometry.attributes.position;
 for(let row=1;row<=ghost.down;row++)for(let col=0;col<=ghost.around;col++){
  const i=row*(ghost.around+1)+col,p=whirlPoint(pos.getX(i),pos.getY(i),pos.getZ(i),row/ghost.down,col/ghost.around*Math.PI*2,mood.flutter,mood.phase);
  pos.setXYZ(i,p.x,p.y,p.z);
 }
 ghost.geometry.computeVertexNormals();
}
ghost.group.rotation.set(Math.sin(t*.5)*.025,Math.sin(t*.35)*.12,Math.sin(t*.65)*.035+mood.tilt);
ghost.group.position.y=mood.bob+Math.sin(t*.8)*.06;
ghost.group.updateMatrixWorld(true);
const meshes=[];
ghost.group.traverse(mesh=>{
 if(!mesh.isMesh)return;
 const g=mesh.geometry,nm=new THREE.Matrix3().getNormalMatrix(mesh.matrixWorld),vertices=[],normals=[],colors=[];
 for(let i=0;i<g.attributes.position.count;i++){
  new THREE.Vector3().fromBufferAttribute(g.attributes.position,i).applyMatrix4(mesh.matrixWorld).toArray(vertices,i*3);
  new THREE.Vector3().fromBufferAttribute(g.attributes.normal,i).applyMatrix3(nm).normalize().toArray(normals,i*3);
  if(mesh.material.vertexColors)new THREE.Vector3().fromBufferAttribute(g.attributes.color,i).toArray(colors,i*3);
 }
 meshes.push({vertices,normals,colors,indices:Array.from(g.index.array),color:mesh.material.color.toArray(),roughness:mesh.material.roughness??1,unlit:mesh.material.isMeshBasicMaterial??false,sheet:mesh===ghost.sheet});
});
// Match the production exponential fade, with an eyes-only hold.
const visibility=kind!=='peekaboo'?1:t<.7?1:t<2.8?Math.exp(-3.8*(t-.7)):1-Math.exp(-3.8*(t-2.8));
console.log(JSON.stringify({meshes,visibility}));
