import {writeFileSync} from 'node:fs';
import * as THREE from '../vendor/three.module.mjs';
import {createGhost} from '../ghost.mjs';
const companion=createGhost();
companion.update(Number(process.argv[2]||0));
companion.group.updateMatrixWorld(true);
const meshes=[];
companion.group.traverse(mesh=>{
 if(!mesh.isMesh)return;
 const geo=mesh.geometry,count=Number.isFinite(geo.drawRange.count)?geo.drawRange.count:(geo.index?.count??geo.attributes.position.count);
 const pos=geo.attributes.position,normal=geo.attributes.normal;
 const vertices=[],normals=[],indices=[],colors=[],normalMatrix=new THREE.Matrix3().getNormalMatrix(mesh.matrixWorld);
 const limit=geo.index?pos.count:count;
 for(let i=0;i<limit;i++){
  const p=new THREE.Vector3().fromBufferAttribute(pos,i).applyMatrix4(mesh.matrixWorld);
  const n=new THREE.Vector3().fromBufferAttribute(normal,i).applyMatrix3(normalMatrix).normalize();
  vertices.push(p.x,p.y,p.z);normals.push(n.x,n.y,n.z);
  if(mesh.material.vertexColors&&geo.attributes.color){const c=geo.attributes.color;colors.push(c.getX(i),c.getY(i),c.getZ(i))}
 }
 for(let i=0;i<count;i++)indices.push(geo.index?geo.index.getX(i):i);
 const m=mesh.material;
 meshes.push({vertices,normals,indices,colors,color:m.color.toArray(),roughness:m.roughness??1,unlit:m.isMeshBasicMaterial??false});
});
writeFileSync(new URL('./mesh.json',import.meta.url),JSON.stringify(meshes));
console.log(`Exported ${meshes.length} meshes; ${meshes.reduce((s,m)=>s+m.indices.length/3,0)} triangles`);
